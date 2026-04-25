% Розрахунок вихідних параметрів масиву панелей залежно від G та T
% Використовуємо спрощену I-V модель з одним горбом P-V

function [V_optimal, P_optimal, I_at_V_optimal] = calculate_panel_output(irradiance, temperature, V_setting)
    % Входи:
    %   irradiance - сонячна радіація [W/m²]
    %   temperature - температура панелі [°C]
    %   V_setting - встановлена напруга панелі [V] (опціонально)
    %
    % Виходи:
    %   V_optimal - оптимальна напруга в точці максимальної потужності [V]
    %   P_optimal - максимальна потужність [W]
    %   I_at_V_optimal - струм при оптимальній напрузі [A]
    
    panel = get_panel_characteristics();

    if nargin < 3
        V_setting = [];
    end

    if irradiance <= 1
        V_optimal = 0;
        P_optimal = 0;
        I_at_V_optimal = 0;
        return;
    end

    dT = temperature - 25;
    G_ratio = irradiance / 1000;

    I_sc = panel.I_sc_stc * panel.parallel * G_ratio * (1 + 0.0005 * dT);
    V_oc = panel.V_oc_stc * panel.series + panel.beta_V * panel.series * dT + 2.0 * log(max(G_ratio, 0.05));
    V_oc = max(10, V_oc);

    V_axis = linspace(0, V_oc, 350);
    shape_k = 1.35;
    I_axis = I_sc .* max(0, 1 - (V_axis ./ V_oc) .^ shape_k);

    % Корекція потужності за паспортним коефіцієнтом
    temp_factor = 1 + panel.gamma_P * dT;
    if temp_factor < 0.2
        temp_factor = 0.2;
    end
    I_axis = I_axis * temp_factor;

    P_axis = V_axis .* I_axis;

    if isempty(V_setting)
        [P_optimal, idx] = max(P_axis);
        V_optimal = V_axis(idx);
        I_at_V_optimal = I_axis(idx);
    else
        V_eval = min(max(V_setting, 0), V_oc);
        I_eval = interp1(V_axis, I_axis, V_eval, 'linear', 'extrap');
        I_eval = max(0, I_eval);

        V_optimal = V_eval;
        P_optimal = V_eval * I_eval;
        I_at_V_optimal = I_eval;
    end
end
