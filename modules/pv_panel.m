function [I_arr, P_arr, I_mod] = pv_panel(V_arr, G, T_cell, cfg)
%PV_PANEL  Однодіодна модель PV-масиву (Villalva 2009).
%
%   [I, P, I_mod] = pv_panel(V_array, G, T_cell, cfg)
%
%   Вхід:
%     V_array — напруга на масиві [В] (скаляр або вектор)
%     G       — освітленість [Вт/м²] (скаляр)
%     T_cell  — температура клітин [°C] (скаляр)
%     cfg     — конфіг
%
%   Вихід:
%     I_arr   — струм масиву [А]
%     P_arr   — потужність [Вт] = V_array * I_arr
%     I_mod   — струм одного модуля (довідково)
%
%   Модель одного модуля:
%       I = Iph - I0 * (exp((V + I*Rs)/(a*Vt*Ns)) - 1) - (V + I*Rs)/Rsh
%   Рівняння неявне → розв'язується Ньютоном (5-10 ітерацій).
%
%   Масив:
%     Ns_panels послідовно → множимо напругу модуля на Ns
%     Np_panels паралельно → множимо струм модуля на Np
%
%   Джерело параметризації:
%     Villalva, Gazoli, Filho (2009), "Comprehensive Approach to
%     Modeling and Simulation of Photovoltaic Arrays", IEEE TPE.

    if nargin < 4, cfg = config(); end

    % ------ Константи ------
    k = 1.380649e-23;   % Дж/К
    q = 1.602176634e-19;% Кл
    T_K = T_cell + 273.15;
    T_stc_K = cfg.panel.T_stc + 273.15;

    % ------ Паспортні параметри модуля ------
    Voc   = cfg.panel.Voc_stc;
    Isc   = cfg.panel.Isc_stc;
    Vmpp  = cfg.panel.Vmpp_stc;
    Impp  = cfg.panel.Impp_stc;
    Ns    = cfg.panel.Ns;
    a     = cfg.panel.a_diode;
    alpha = cfg.panel.alpha_isc;
    beta  = cfg.panel.beta_voc;
    G_stc = cfg.panel.G_stc;

    % ------ Обчислюємо Rs, Rsh, I0 (одноразово) ------
    persistent model_params;
    if isempty(model_params) || model_params.cfg_hash ~= local_hash(cfg)
        model_params = fit_one_diode(cfg);
        model_params.cfg_hash = local_hash(cfg);
    end
    Rs  = model_params.Rs;
    Rsh = model_params.Rsh;
    I0_stc = model_params.I0;
    Iph_stc = model_params.Iph;

    % ------ Масштабування на поточні G, T ------
    Vt  = a * Ns * k * T_K / q;            % модуляційний потенціал з фактором a

    dT  = T_cell - cfg.panel.T_stc;
    Iph = (Iph_stc + alpha * dT) * G / G_stc;

    % I0(T) через паспортне рівняння Villalva — лінеаризоване з β:
    %   I0(T) = (Isc_stc + α·dT) / (exp((Voc_stc + β·dT)/(a·Ns·Vt)) - 1)
    I0 = (Isc + alpha*dT) / (exp((Voc + beta*dT) / Vt) - 1);

    % Якщо G дуже мале, Iph → 0; уникаємо nan
    if Iph < 0
        Iph = 0;
    end

    % ------ Масив: напруга одного модуля = V_arr / Ns_panels ------
    Ns_arr = cfg.array.Ns_panels;
    Np_arr = cfg.array.Np_panels;

    V_mod = V_arr(:)' / Ns_arr;

    % ------ Векторизований Ньютон одразу по всьому V_mod ------
    I_mod = solve_diode_vec(V_mod, Iph, I0, Rs, Rsh, Vt);

    I_arr = I_mod * Np_arr;
    P_arr = V_arr(:)' .* I_arr;

    % Обрізання на фізичних межах — не від'ємна потужність
    I_arr(P_arr < 0) = 0;
    P_arr(P_arr < 0) = 0;

    % Повертаємо таку ж форму, як V_arr
    if iscolumn(V_arr)
        I_arr = I_arr(:);
        P_arr = P_arr(:);
        I_mod = I_mod(:);
    end
end

% =========================================================================
function I = solve_diode_vec(V, Iph, I0, Rs, Rsh, Vt)
% Векторизований розв'язок однодіодної моделі для вектора V.
% Метод Ньютона, 15 ітерацій достатньо для збіжності до 1e-8.
    I = Iph * ones(size(V));
    for iter = 1:15
        arg = (V + I*Rs) / Vt;
        arg = min(arg, 700);                 % захист від overflow exp()
        expo = exp(arg);
        f  = Iph - I0*(expo - 1) - (V + I*Rs)/Rsh - I;
        df = -I0 * expo * Rs/Vt - Rs/Rsh - 1;
        dI = f ./ df;
        I = I - dI;
    end
    % Замінюємо NaN / Inf нулями (області за V > Voc зазвичай дають
    % від'ємний струм — це обробляється далі обрізанням P < 0)
    bad = ~isfinite(I);
    I(bad) = 0;
end

function I = solve_diode(V, Iph, I0, Rs, Rsh, Vt)
% Скалярна обгортка — для сумісності (використовується у fit_one_diode).
    I = solve_diode_vec(V, Iph, I0, Rs, Rsh, Vt);
end

% =========================================================================
function params = fit_one_diode(cfg)
% Обчислення Rs, Rsh, I0, Iph з паспортних (Villalva 2009).
%
%   Rs ітеративно збільшують, поки обчислений Pmpp не зрівняється з паспортним.
%   Rsh виводиться з Rs з умови, що P(Vmpp, Impp) = Pmpp.

    k = 1.380649e-23; q = 1.602176634e-19;
    Voc   = cfg.panel.Voc_stc;
    Isc   = cfg.panel.Isc_stc;
    Vmpp  = cfg.panel.Vmpp_stc;
    Impp  = cfg.panel.Impp_stc;
    Pmpp  = Vmpp * Impp;
    Ns    = cfg.panel.Ns;
    a     = cfg.panel.a_diode;
    T_stc = cfg.panel.T_stc + 273.15;

    Vt = a * Ns * k * T_stc / q;

    Rs = 0;
    Rsh = 1000;
    dRs = 0.001;
    best_err = Inf; best_Rs = 0; best_Rsh = Rsh;

    for n_it = 1:200
        I0 = (Isc) / (exp(Voc / Vt) - 1);
        Iph = (Rs + Rsh)/Rsh * Isc;

        % Rsh з умови Vmpp:
        num = Vmpp*(Vmpp + Impp*Rs);
        den = Vmpp*Iph - Vmpp*I0*(exp((Vmpp + Impp*Rs)/Vt) - 1) - Pmpp;
        if den ~= 0
            Rsh_new = num / den;
            if Rsh_new > 0 && isfinite(Rsh_new)
                Rsh = Rsh_new;
            end
        end

        % Перевіряємо Pmpp по моделі
        V_test = Vmpp;
        I_test = solve_diode(V_test, Iph, I0, Rs, Rsh, Vt);
        P_test = V_test * I_test;
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
end

% =========================================================================
function h = local_hash(cfg)
% Простий хеш від паспорту, щоб кешувати fit_one_diode.
    h = cfg.panel.Voc_stc + 1000*cfg.panel.Isc_stc + ...
        1e4*cfg.panel.Vmpp_stc + 1e6*cfg.panel.Impp_stc + ...
        1e8*cfg.panel.a_diode;
end
