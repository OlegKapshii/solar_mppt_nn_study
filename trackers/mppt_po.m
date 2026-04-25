function [V_cmd, state] = mppt_po(G, T_cell, V_prev, P_prev, state, cfg)
%MPPT_PO  Класичний алгоритм Perturb & Observe.
%
%   [V_cmd, state] = mppt_po(G, T_cell, V_prev, P_prev, state, cfg)
%
%   Логіка алгоритму:
%     При кожному кроці порівнюємо поточну потужність P з попередньою:
%       dP = P_current - P_last
%       dV = V_current - V_last
%
%     Таблиця прийняття рішення:
%       dP > 0, dV > 0  →  продовжуємо збільшувати V  (V_next = V + step)
%       dP > 0, dV < 0  →  продовжуємо зменшувати V   (V_next = V - step)
%       dP < 0, dV > 0  →  розвертаємось, зменшуємо V (V_next = V - step)
%       dP < 0, dV < 0  →  розвертаємось, збільшуємо V (V_next = V + step)
%
%   Відома проблема P&O — «drift» при швидкій зміні G: dP може бути
%   викликане зміною освітленості, а не нашим збуренням V, через що
%   алгоритм робить невірний висновок.
%
%   Вхід:
%     G, T_cell — не використовуються напряму (алгоритм працює лише за P і V),
%                 але залишені в інтерфейсі для уніфікації.
%     V_prev    — напруга, яка встановлена на масиві ЗАРАЗ (останньо видана).
%     P_prev    — потужність, виміряна при цій V.
%     state     — stateful контекст. На першому виклику — порожній struct.
%     cfg       — конфіг, читається V_step, V_init_frac.
%
%   Вихід:
%     V_cmd — нова рекомендована напруга
%     state — оновлений стан (зберігає V_last, P_last і лічильник кроків)

    if nargin < 6, cfg = config(); end

    Voc_arr = cfg.panel.Voc_stc * cfg.array.Ns_panels;
    V_min = 0.1 * Voc_arr;
    V_max = 0.98 * Voc_arr;

    if isempty(state) || ~isfield(state, 'initialized')
        % Перший виклик — ініціалізація
        state.initialized = true;
        state.V_last = cfg.po.V_init_frac * Voc_arr;
        state.P_last = 0;
        state.step_count = 0;
        state.direction = +1;
        state.name = 'P&O';
        V_cmd = state.V_last;
        return;
    end

    step = cfg.po.V_step;

    dP = P_prev - state.P_last;
    dV = V_prev - state.V_last;

    % Класична логіка — 4 квадранти
    if dP > 0
        if dV >= 0
            V_cmd = V_prev + step;
        else
            V_cmd = V_prev - step;
        end
    else
        if dV >= 0
            V_cmd = V_prev - step;
        else
            V_cmd = V_prev + step;
        end
    end

    % Обмеження на діапазон
    V_cmd = max(V_min, min(V_max, V_cmd));

    % Оновлюємо стан — зберігаємо для наступного порівняння те,
    % що було на ВХОДІ в цю ітерацію.
    state.V_last = V_prev;
    state.P_last = P_prev;
    state.step_count = state.step_count + 1;
end
