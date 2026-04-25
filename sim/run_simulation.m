function result = run_simulation(scenario, tracker_fn, cfg, varargin)
%RUN_SIMULATION  Головний симулятор — інтегратор усіх блоків.
%
%   result = run_simulation(scenario, tracker_fn, cfg, [...options])
%
%   Параметри:
%     scenario   — 'full_day' (0..24 год) або 'transient' (короткий інтервал)
%     tracker_fn — handle на трекер: @mppt_po | @mppt_nn | @mppt_ideal
%     cfg        — конфіг (з config())
%     options    — пари Name/Value:
%                  't_range'  — [t0, t1] у годинах (перевизначає scenario)
%                  'clouds'   — пре-згенерований вектор хмар (інакше генерується)
%                  'T_cell_const' — якщо задано, використовує константу
%                                    замість моделі NOCT
%
%   Повертає result — struct з таймсеріями:
%     result.t          — час [год]
%     result.G          — POA освітленість [Вт/м²]
%     result.T_cell     — температура клітин [°C]
%     result.V          — напруга, встановлена трекером [В]
%     result.I          — струм [А]
%     result.P          — потужність, реально вироблена [Вт]
%     result.V_mpp      — справжня Vmpp (оракул) [В]
%     result.P_mpp      — справжня Pmpp (оракул) [Вт]
%     result.efficiency — миттєва ефективність трекінгу (P/P_mpp)
%     result.tracker_name
%     result.exec_time_s — час виконання циклу (для exp5)

    if nargin < 3, cfg = config(); end

    % --- Розпаковка опцій ---
    opts = parse_opts(varargin);

    % --- Часова сітка ---
    switch lower(scenario)
        case 'full_day'
            t_range = [0, 24];
        case 'transient'
            t_range = [11.5, 12.5];
        case 'custom'
            if ~isfield(opts, 't_range')
                error('custom scenario requires t_range option');
            end
            t_range = opts.t_range;
        otherwise
            error('Unknown scenario: %s', scenario);
    end
    if isfield(opts, 't_range')
        t_range = opts.t_range;
    end

    dt_s = cfg.time.dt_s;
    t_s = (t_range(1)*3600) : dt_s : (t_range(2)*3600);
    t_hours = t_s / 3600;
    N = numel(t_hours);

    % --- Освітленість ---
    G_clear = irradiance_clearsky(t_hours, cfg);
    if isfield(opts, 'clouds')
        cf = opts.clouds;
        if numel(cf) ~= N
            error('clouds vector length mismatch (got %d, need %d)', numel(cf), N);
        end
    else
        cf = clouds_markov(t_hours, cfg);
    end
    G = G_clear .* cf;

    % --- Температура клітин (модель NOCT) ---
    T_amb = ambient(t_hours, cfg);
    if isfield(opts, 'T_cell_const')
        T_cell_arr = opts.T_cell_const * ones(size(t_hours));
    else
        T_cell_arr = T_amb + (cfg.panel.NOCT_C - 20)/800 * G;
    end

    % --- Підготовка масивів ---
    V = zeros(1, N);
    I = zeros(1, N);
    P = zeros(1, N);
    V_mpp_arr = zeros(1, N);
    P_mpp_arr = zeros(1, N);

    % --- Ініціалізація трекера ---
    state = struct();
    [V_init, state] = tracker_fn(G(1), T_cell_arr(1), 0, 0, state, cfg);
    V(1) = V_init;

    % --- Перед-обчислення «істинної» MPP на згрубленій сітці (G, T) ---
    % G і T змінюються повільно; точне значення MPP від них залежить слабко.
    % Будуємо lookup таблицю і інтерполюємо — швидше, ніж N викликів pv_mpp.
    [V_mpp_arr, P_mpp_arr] = precompute_mpp_grid(G, T_cell_arr, cfg);

    % --- Виконання з таймером ---
    tic;
    for k = 1:N
        G_k = G(k);
        T_k = T_cell_arr(k);

        % Фізика панелі — струм і потужність при команді V(k)
        if G_k < 5
            I(k) = 0; P(k) = 0;
        else
            [I(k), P(k)] = pv_panel(V(k), G_k, T_k, cfg);
        end

        % Наступна команда трекеру
        if k < N
            [V(k+1), state] = tracker_fn(G_k, T_k, V(k), P(k), state, cfg);
        end
    end
    exec_time_s = toc;

    % --- Ефективність ---
    eff = zeros(1, N);
    mask = P_mpp_arr > 1;
    eff(mask) = P(mask) ./ P_mpp_arr(mask);
    eff = max(0, min(1.05, eff));

    % --- Пакування ---
    result = struct();
    result.t = t_hours;
    result.G = G;
    result.G_clear = G_clear;
    result.cloud_factor = cf;
    result.T_amb = T_amb;
    result.T_cell = T_cell_arr;
    result.V = V;
    result.I = I;
    result.P = P;
    result.V_mpp = V_mpp_arr;
    result.P_mpp = P_mpp_arr;
    result.efficiency = eff;
    if isfield(state, 'name')
        result.tracker_name = state.name;
    else
        result.tracker_name = func2str(tracker_fn);
    end
    result.exec_time_s = exec_time_s;
    result.dt_s = dt_s;
    result.N = N;
end

% =========================================================================
function opts = parse_opts(argcell)
    opts = struct();
    for i = 1:2:length(argcell)
        opts.(argcell{i}) = argcell{i+1};
    end
end

% =========================================================================
function [V_mpp, P_mpp] = precompute_mpp_grid(G_vec, T_vec, cfg)
% Для прискорення: будуємо lookup-таблицю MPP по (G, T) і інтерполюємо.
%
% Шаг сітки: 25 Вт/м² по G, 2 °C по T. Точність ~1% для Pmpp,
% що достатньо для оцінки ефективності трекінгу.

    G_grid = 0:25:1250;
    T_grid = -10:2:80;

    N_G = numel(G_grid);
    N_T = numel(T_grid);

    Vmpp_tab = zeros(N_G, N_T);
    Pmpp_tab = zeros(N_G, N_T);

    for ig = 1:N_G
        for it = 1:N_T
            [Vmpp_tab(ig, it), ~, Pmpp_tab(ig, it)] = ...
                pv_mpp(G_grid(ig), T_grid(it), cfg);
        end
    end

    % Інтерполяція на фактичні (G, T)
    G_cl = max(G_grid(1), min(G_grid(end), G_vec));
    T_cl = max(T_grid(1), min(T_grid(end), T_vec));

    V_mpp = interp2(T_grid, G_grid, Vmpp_tab, T_cl, G_cl, 'linear', 0);
    P_mpp = interp2(T_grid, G_grid, Pmpp_tab, T_cl, G_cl, 'linear', 0);
end
