function [V_mpp, I_mpp, P_mpp] = pv_mpp(G, T_cell, cfg)
%PV_MPP  Знаходить справжню точку максимальної потужності (MPP).
%
%   [V_mpp, I_mpp, P_mpp] = pv_mpp(G, T_cell, cfg)
%
%   Метод:
%     - будуємо сітку V ∈ [0, Voc_array] з N точок (N=500 за замовч.);
%     - обчислюємо P(V) за однодіодною моделлю;
%     - знаходимо argmax.
%
%   Цей результат вважаємо «істиною» для:
%     - теоретичного максимуму (ідеальний трекер),
%     - генерації навчального датасету для нейромережі,
%     - обчислення ефективності трекінгу.
%
%   Для G нижче порогу (10 Вт/м²) повертає нулі.

    if nargin < 3, cfg = config(); end

    if G < 10
        V_mpp = 0; I_mpp = 0; P_mpp = 0;
        return;
    end

    Voc_arr = cfg.panel.Voc_stc * cfg.array.Ns_panels;

    N = 500;
    V_grid = linspace(0, Voc_arr * 1.05, N);

    [~, P] = pv_panel(V_grid, G, T_cell, cfg);

    [P_mpp, idx] = max(P);

    % Точкове уточнення — параболічна інтерполяція навколо максимуму
    if idx > 1 && idx < N
        x = V_grid(idx-1:idx+1);
        y = P(idx-1:idx+1);
        denom = (y(1) - 2*y(2) + y(3));
        if abs(denom) > 1e-9
            dx = 0.5*(y(1) - y(3)) / denom * (x(2) - x(1));
            V_mpp = x(2) + dx;
        else
            V_mpp = x(2);
        end
    else
        V_mpp = V_grid(idx);
    end

    [I_mpp, P_mpp] = pv_panel(V_mpp, G, T_cell, cfg);
end
