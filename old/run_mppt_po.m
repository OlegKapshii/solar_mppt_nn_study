function [P_track, V_ref_hist, out] = run_mppt_po(t_hours, P_mpp, V_mpp_true, cfg)
% RUN_MPPT_PO  Класичний MPPT Perturb & Observe (P&O) для часової симуляції.
%
% Призначення:
%   Функція реалізує саме класичний P&O: рішення приймається за знаками
%   dP = P(k)-P(k-1) та dV = V(k)-V(k-1), без AI/нейромереж і без
%   додаткових евристик типу incremental conductance.
%
% Вхід:
%   t_hours     - часовий вектор [1xN] у годинах
%   P_mpp       - теоретично доступна потужність на MPP [1xN], Вт
%   V_mpp_true  - істинна Vmpp у кожен момент [1xN], В
%   cfg         - структура налаштувань (усі поля optional):
%       .V_step           крок збурення, В (default 0.5)
%       .V_init           початкова робоча напруга, В (default V_mpp_true(1))
%       .V_min            мінімальна робоча напруга, В (default 0.5*min(V_mpp_true))
%       .V_max            максимальна робоча напруга, В (default 1.5*max(V_mpp_true))
%       .curve_k          крутизна P(V) навколо Vmpp (default 18)
%       .sleep_power_w    поріг "сон" контролера, Вт (default 5)
%       .dP_deadband_w    мертва зона для dP, Вт (default 0.05)
%       .updates_per_step кількість оновлень P&O у межах одного відліку часу (default 1)
%
% Вихід:
%   P_track     - потужність, знята алгоритмом [1xN], Вт
%   V_ref_hist  - робоча напруга після P&O [1xN], В
%   out         - службова структура:
%       .P_ideal        копія P_mpp
%       .eff_inst_pct   миттєва ефективність трекінгу, %
%       .E_ideal_kWh    енергія ідеального MPPT, кВт*год
%       .E_track_kWh    енергія P&O, кВт*год
%       .eff_energy_pct енергетична ефективність, %
%
% Модель виміряної потужності:
%   P_meas = P_mpp * max(0, 1 - curve_k * ((V - Vmpp)/Vmpp)^2 )
% Це проста гладка апроксимація одновершинної P-V кривої.
%
% Приклад:
%   cfg = struct('V_step', 0.4, 'updates_per_step', 2);
%   [P_po, V_po, po] = run_mppt_po(t_hours, P_ideal, V_mpp_dyn, cfg);

    if nargin < 4
        cfg = struct();
    end

    N = numel(t_hours);
    if numel(P_mpp) ~= N || numel(V_mpp_true) ~= N
        error('run_mppt_po:SizeMismatch', 't_hours, P_mpp, V_mpp_true must have same length');
    end

    % Гарантуємо рядковий формат для однакової індексації.
    t_hours = reshape(t_hours, 1, []);
    P_mpp = reshape(P_mpp, 1, []);
    V_mpp_true = reshape(V_mpp_true, 1, []);

    % Значення за замовчуванням.
    if ~isfield(cfg, 'V_step'), cfg.V_step = 0.5; end
    if ~isfield(cfg, 'V_init'), cfg.V_init = V_mpp_true(find(V_mpp_true > 0, 1, 'first')); end
    if isempty(cfg.V_init), cfg.V_init = 30; end
    if ~isfield(cfg, 'V_min'), cfg.V_min = 0.5 * max(1, min(V_mpp_true(V_mpp_true > 0))); end
    if ~isfield(cfg, 'V_max'), cfg.V_max = 1.5 * max(1, max(V_mpp_true)); end
    if ~isfield(cfg, 'curve_k'), cfg.curve_k = 18; end
    if ~isfield(cfg, 'sleep_power_w'), cfg.sleep_power_w = 5; end
    if ~isfield(cfg, 'dP_deadband_w'), cfg.dP_deadband_w = 0.05; end
    if ~isfield(cfg, 'updates_per_step'), cfg.updates_per_step = 1; end

    P_track = zeros(1, N);
    V_ref_hist = zeros(1, N);

    V_curr = min(max(cfg.V_init, cfg.V_min), cfg.V_max);
    V_prev = max(cfg.V_min, V_curr - cfg.V_step);
    P_prev = 0;

    for k = 1:N
        if P_mpp(k) < cfg.sleep_power_w || V_mpp_true(k) <= 0
            P_track(k) = 0;
            V_ref_hist(k) = V_curr;
            P_prev = 0;
            continue;
        end

        P_meas = 0;
        for s = 1:cfg.updates_per_step
            % Оцінка потужності на поточній робочій напрузі.
            mismatch = (V_curr - V_mpp_true(k)) / max(V_mpp_true(k), eps);
            P_meas = P_mpp(k) * max(0, 1 - cfg.curve_k * mismatch^2);

            dP = P_meas - P_prev;
            dV = V_curr - V_prev;

            if abs(dP) <= cfg.dP_deadband_w
                V_next = V_curr;
            else
                if dP > 0
                    if dV > 0
                        V_next = V_curr + cfg.V_step;
                    else
                        V_next = V_curr - cfg.V_step;
                    end
                else
                    if dV > 0
                        V_next = V_curr - cfg.V_step;
                    else
                        V_next = V_curr + cfg.V_step;
                    end
                end
            end

            V_next = min(max(V_next, cfg.V_min), cfg.V_max);

            V_prev = V_curr;
            V_curr = V_next;
            P_prev = P_meas;
        end

        P_track(k) = P_meas;
        V_ref_hist(k) = V_curr;
    end

    dt_h = median(diff(t_hours));
    if isempty(dt_h) || ~isfinite(dt_h) || dt_h <= 0
        dt_h = 0;
    end

    E_ideal_kWh = sum(P_mpp) * dt_h / 1000;
    E_track_kWh = sum(P_track) * dt_h / 1000;

    eff_inst_pct = zeros(1, N);
    idx = P_mpp > 0;
    eff_inst_pct(idx) = 100 * P_track(idx) ./ P_mpp(idx);

    if E_ideal_kWh > 0
        eff_energy_pct = 100 * E_track_kWh / E_ideal_kWh;
    else
        eff_energy_pct = 0;
    end

    out.P_ideal = P_mpp;
    out.eff_inst_pct = eff_inst_pct;
    out.E_ideal_kWh = E_ideal_kWh;
    out.E_track_kWh = E_track_kWh;
    out.eff_energy_pct = eff_energy_pct;
end
