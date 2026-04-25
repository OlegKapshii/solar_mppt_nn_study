% Розрахунок вихідних параметрів масиву PV панелей за однодіодною моделлю.
%
% Замінює попередню штучну апроксимацію I = Isc*(1 - (V/Voc)^1.35), яка
% давала Vmp/Voc ≈ 0.52 і Pmax ≈ 1716 Вт замість паспортних 0.80 і 4000 Вт.
%
% Реалізація: Villalva, Gazoli, Filho (2009), "Comprehensive Approach to
% Modeling and Simulation of Photovoltaic Arrays", IEEE TPE.
%
% Інтерфейс зворотньо сумісний:
%   [V_opt, P_opt, I_at] = calculate_panel_output(G, T)            -> MPP
%   [V, P, I]            = calculate_panel_output(G, T, V_setting) -> точка V

function [V_optimal, P_optimal, I_at_V_optimal] = calculate_panel_output(irradiance, temperature, V_setting)

    panel = get_panel_characteristics();

    if nargin < 3
        V_setting = [];
    end

    % Поріг "ніч" — нижче 1 Вт/м² панель не генерує
    if irradiance <= 1
        V_optimal = 0;
        P_optimal = 0;
        I_at_V_optimal = 0;
        return;
    end

    % --- Параметри однодіодної моделі (з паспорта, кешуються) ---
    persistent fit_cache fit_hash;
    cur_hash = panel.V_oc_stc + 1000*panel.I_sc_stc + 1e4*panel.V_mp_stc + 1e6*panel.I_mp_stc;
    if isempty(fit_cache) || fit_hash ~= cur_hash
        fit_cache = fit_one_diode(panel);
        fit_hash = cur_hash;
    end
    Rs = fit_cache.Rs;
    Rsh = fit_cache.Rsh;
    I0_stc = fit_cache.I0;
    Iph_stc = fit_cache.Iph;
    a_diode = fit_cache.a;

    % --- Фізичні константи ---
    k_B = 1.380649e-23;
    q_e = 1.602176634e-19;
    T_K = temperature + 273.15;
    Vt_mod = a_diode * panel.Ns * k_B * T_K / q_e;       % модуляційний потенціал діода (на модуль)

    % --- Масштабування Iph, I0 на поточні G, T ---
    dT = temperature - 25;
    Iph = (Iph_stc + panel.alpha_I * dT) * irradiance / 1000;
    if Iph < 0, Iph = 0; end
    I0 = (panel.I_sc_stc + panel.alpha_I * dT) / (exp((panel.V_oc_stc + panel.beta_V * dT) / Vt_mod) - 1);

    % --- Геометрія масиву: Ns послідовно (множить V), Np паралельно (множить I) ---
    Ns_arr = panel.series;
    Np_arr = panel.parallel;

    % --- Побудова I-V кривої масиву на сітці V ---
    Voc_array = panel.V_oc_stc * Ns_arr + panel.beta_V * Ns_arr * dT;
    Voc_array = max(10, Voc_array);

    if isempty(V_setting)
        % Знаходимо MPP сіткою + параболічним уточненням
        N_grid = 400;
        V_grid_arr = linspace(0, Voc_array * 1.02, N_grid);
        V_grid_mod = V_grid_arr / Ns_arr;
        I_mod_grid = solve_diode_vec(V_grid_mod, Iph, I0, Rs, Rsh, Vt_mod);
        I_grid_arr = I_mod_grid * Np_arr;
        P_grid = V_grid_arr .* I_grid_arr;
        P_grid(P_grid < 0) = 0;

        [P_max, idx] = max(P_grid);
        if idx > 1 && idx < N_grid
            x = V_grid_arr(idx-1:idx+1);
            y = P_grid(idx-1:idx+1);
            denom = (y(1) - 2*y(2) + y(3));
            if abs(denom) > 1e-9
                dx = 0.5*(y(1) - y(3)) / denom * (x(2) - x(1));
                V_optimal = x(2) + dx;
            else
                V_optimal = x(2);
            end
        else
            V_optimal = V_grid_arr(idx);
        end

        I_mod = solve_diode_vec(V_optimal / Ns_arr, Iph, I0, Rs, Rsh, Vt_mod);
        I_at_V_optimal = I_mod * Np_arr;
        P_optimal = V_optimal * I_at_V_optimal;
        if P_optimal < 0, P_optimal = 0; I_at_V_optimal = 0; end
    else
        V_eval = min(max(V_setting, 0), Voc_array);
        I_mod = solve_diode_vec(V_eval / Ns_arr, Iph, I0, Rs, Rsh, Vt_mod);
        I_eval = I_mod * Np_arr;
        I_eval = max(0, I_eval);

        V_optimal = V_eval;
        I_at_V_optimal = I_eval;
        P_optimal = V_eval * I_eval;
    end
end

% =========================================================================
function I = solve_diode_vec(V, Iph, I0, Rs, Rsh, Vt)
% Векторизований метод Ньютона для рівняння Шоклі однодіодної моделі:
%   I = Iph - I0*(exp((V + I*Rs)/Vt) - 1) - (V + I*Rs)/Rsh
    I = Iph * ones(size(V));
    for iter = 1:15
        arg = (V + I*Rs) / Vt;
        arg = min(arg, 700);                  % захист від overflow
        expo = exp(arg);
        f  = Iph - I0 .* (expo - 1) - (V + I*Rs) ./ Rsh - I;
        df = -I0 .* expo .* Rs ./ Vt - Rs ./ Rsh - 1;
        I  = I - f ./ df;
    end
    I(~isfinite(I)) = 0;
end

% =========================================================================
function params = fit_one_diode(panel)
% Підбір Rs, Rsh, I0, Iph за паспортом так, щоб модель давала точно Pmpp,
% Vmpp, Impp, Voc, Isc при STC. Алгоритм Villalva.
    k_B = 1.380649e-23; q_e = 1.602176634e-19;
    T_stc_K = 25 + 273.15;
    a = 1.3;                                  % фактор ідеальності діода
    Vt = a * panel.Ns * k_B * T_stc_K / q_e;

    Voc  = panel.V_oc_stc;
    Isc  = panel.I_sc_stc;
    Vmpp = panel.V_mp_stc;
    Impp = panel.I_mp_stc;
    Pmpp = Vmpp * Impp;

    Rs = 0;
    Rsh = 1000;
    dRs = 0.0005;
    best_err = Inf;
    best_Rs = 0; best_Rsh = Rsh;

    for n_it = 1:300
        I0 = Isc / (exp(Voc / Vt) - 1);
        Iph = (Rs + Rsh)/Rsh * Isc;

        num = Vmpp * (Vmpp + Impp*Rs);
        den = Vmpp*Iph - Vmpp*I0*(exp((Vmpp + Impp*Rs)/Vt) - 1) - Pmpp;
        if abs(den) > 1e-12
            Rsh_new = num / den;
            if Rsh_new > 0 && isfinite(Rsh_new)
                Rsh = Rsh_new;
            end
        end

        I_test = solve_diode_vec(Vmpp, Iph, I0, Rs, Rsh, Vt);
        P_test = Vmpp * I_test;
        err = abs(P_test - Pmpp);

        if err < best_err
            best_err = err;
            best_Rs = Rs;
            best_Rsh = Rsh;
        end
        if err < 1e-3
            break;
        end
        Rs = Rs + dRs;
    end

    Rs = best_Rs; Rsh = best_Rsh;
    I0 = Isc / (exp(Voc / Vt) - 1);
    Iph = (Rs + Rsh)/Rsh * Isc;

    params.Rs = Rs;
    params.Rsh = Rsh;
    params.I0 = I0;
    params.Iph = Iph;
    params.a = a;
end
