function [V_cmd, state] = mppt_nn(G, T_cell, V_prev, P_prev, state, cfg)
%MPPT_NN  Нейромережевий трекер — повна заміна P&O.
%
%   Використовує навчену FC-мережу для прямої пропозиції V_target
%   на основі поточних (G, T, V_prev).
%
%   Перший виклик завантажує ваги з cfg.nn.weights_file.
%
%   Вхід:
%     G, T_cell, V_prev, P_prev — поточний стан (вимірювання)
%     state.weights — struct з полями W, b (масиви клітинок), завантажується
%                     автоматично при першому виклику
%     cfg       — конфіг

    if nargin < 6, cfg = config(); end

    if isempty(state) || ~isfield(state, 'initialized')
        % Ініціалізація — завантажуємо ваги
        state = struct();
        state.initialized = true;
        state.name = 'NN';

        if exist(cfg.nn.weights_file, 'file')
            loaded = load(cfg.nn.weights_file);
            state.weights = loaded.weights;
        else
            error('mppt_nn:no_weights', ...
                  'Weights not found: %s\nTrain the NN first by running nn/nn_train.m', ...
                  cfg.nn.weights_file);
        end

        Voc_arr = cfg.panel.Voc_stc * cfg.array.Ns_panels;
        state.V_init = cfg.po.V_init_frac * Voc_arr;

        V_cmd = state.V_init;
        return;
    end

    % Нормалізація входів (має відповідати nn_generate_dataset)
    Voc_arr = cfg.panel.Voc_stc * cfg.array.Ns_panels;
    x = [G / cfg.nn.G_norm; ...
         (T_cell - cfg.nn.T_shift) / cfg.nn.T_norm];

    % Інференс
    y = nn_forward(x, state.weights, cfg);

    % Вихід — частка Voc_arr (мережа вчиться виводити V_mpp/Voc_arr)
    V_cmd = y(1) * Voc_arr;

    % Фізичні межі
    V_cmd = max(0.1*Voc_arr, min(0.98*Voc_arr, V_cmd));
end
