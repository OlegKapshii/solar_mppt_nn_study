% Генерація синтетичних даних для тренування динамічної VI нейронної мережи MPPT (v4)
%
% На відміну від generate_training_data (використовує G та T як входи),
% тут генеруються вектори ознак (V, V_prev, I, P, dV, dP) -> target_dV.
%
% Ідея: замість прямого прогнозу абсолютної оптимальної напруги мережа
% вчиться робити корекцію напруги з поточного стану системи та його історії.

function [training_data, validation_data] = generate_training_data_vi(num_conditions)
    % Входи:
    %   num_conditions - кількість умов (G, T) для сэмплування (за замовчуванням 350)
    %
    % Виходи:
    %   training_data   - структура з полями .V_in, .V_prev, .I_in, .P_in, .dV, .dP, .target_dV (80%)
    %   validation_data - структура з полями .V_in, .V_prev, .I_in, .P_in, .dV, .dP, .target_dV (20%)

    if nargin < 1
        num_conditions = 350;  % Збільшена кількість умов для більшої мережі (v4)
    end

    this_dir    = fileparts(mfilename('fullpath'));
    project_dir = fileparts(this_dir);
    addpath(fullfile(project_dir, 'solar_model'));
    addpath(fullfile(project_dir, 'neural_network'));

    % Кількість локальних переходів для кожної умови (G, T)
    N_per_condition = 32;  % Збільшена кількість точок на умову
    % action_limit має узгоджуватись з nn_init_vi.m::action_limit, інакше
    % тренувальні дані будуть обрізані до іншого діапазону, ніж очікує
    % мережа на інференсі.
    tmp_net = nn_init_vi();
    action_limit = tmp_net.action_limit;

    total = num_conditions * N_per_condition;

    fprintf('Генерація VI тренувальних даних (v4)...\n');
    fprintf('Умов (G,T): %d, Точок на умову: %d, Всього: %d\n', ...
        num_conditions, N_per_condition, total);

    % Генерація умов (G, T) на сітці + шум — узгоджено з nn_init.m
    G_min = 50;   G_max = 1100;
    T_min = 5;    T_max = 65;

    G_vals = linspace(G_min, G_max, ceil(sqrt(num_conditions)));
    T_vals = linspace(T_min, T_max, ceil(sqrt(num_conditions)));

    [G_grid, T_grid] = meshgrid(G_vals, T_vals);
    G_pts = G_grid(:);
    T_pts = T_grid(:);
    G_pts = G_pts(1:num_conditions);
    T_pts = T_pts(1:num_conditions);

    rng(123);  % Детермінований seed для відтворюваності
    G_pts = max(G_min, min(G_max, G_pts + 20 * randn(num_conditions, 1)));
    T_pts = max(T_min, min(T_max, T_pts + 5  * randn(num_conditions, 1)));

    % Масиви для зберігання
    V_in_all      = zeros(total, 1);
    V_prev_all    = zeros(total, 1);  % НОВЕ: попередня напруга
    I_in_all      = zeros(total, 1);
    P_in_all      = zeros(total, 1);
    dV_all        = zeros(total, 1);
    dP_all        = zeros(total, 1);
    target_dV_all = zeros(total, 1);

    fprintf('Розрахунок точок I-V кривої...\n');
    fprintf('Прогрес: ');

    panel = get_panel_characteristics();

    idx = 1;
    for k = 1:num_conditions
        G = G_pts(k);
        T = T_pts(k);

        % Оптимальна напруга для цієї умови
        [V_opt, ~, ~] = calculate_panel_output(G, T);

        % Розрахунок Voc для цієї умови (щоб знати діапазон кривої I-V)
        dT      = T - 25;
        G_ratio = G / 1000;
        V_oc    = panel.V_oc_stc * panel.series + panel.beta_V * panel.series * dT ...
                  + 2.0 * log(max(G_ratio, 0.05));
        V_oc = max(10, V_oc);

        % Формуємо локальну траєкторію, щоб dV/dP були схожі на реальний контур
        V_prev = 0.05 * V_oc + 0.92 * V_oc * rand();
        V_prev = max(0.5, min(0.97 * V_oc, V_prev));
        [~, P_prev, ~] = calculate_panel_output(G, T, V_prev);

        V_current = V_prev + 1.5 * randn();
        V_current = max(0.5, min(0.97 * V_oc, V_current));

        for j = 1:N_per_condition
            [~, P_current, I_current] = calculate_panel_output(G, T, V_current);

            dV = V_current - V_prev;
            dP = P_current - P_prev;

            target_dV = V_opt - V_current;
            target_dV = max(-action_limit, min(action_limit, target_dV));

            V_in_all(idx)      = V_current;
            V_prev_all(idx)    = V_prev;      % НОВЕ: зберігаємо попередню напругу
            I_in_all(idx)      = max(0, I_current);
            P_in_all(idx)      = max(0, P_current);
            dV_all(idx)        = dV;
            dP_all(idx)        = dP;
            target_dV_all(idx) = target_dV;
            idx = idx + 1;

            % Псевдоконтур: рух до MPP з шумом для різноманітності
            u = 0.7 * target_dV + 0.25 * randn();
            u = max(-action_limit, min(action_limit, u));

            V_prev = V_current;
            P_prev = P_current;
            V_current = V_current + u;
            V_current = max(0.5, min(0.97 * V_oc, V_current));
        end

        if mod(k, max(1, floor(num_conditions / 10))) == 0
            fprintf('%d%% ', round(100 * k / num_conditions));
        end
    end
    fprintf('\n');

    % Перемішування та розбиття 80/20
    shuffle_idx = randperm(total);
    num_train   = round(0.8 * total);
    train_idx   = shuffle_idx(1:num_train);
    val_idx     = shuffle_idx((num_train + 1):end);

    training_data.V_in      = V_in_all(train_idx)';
    training_data.V_prev    = V_prev_all(train_idx)';  % НОВЕ: V_prev в тренувальні дані
    training_data.I_in      = I_in_all(train_idx)';
    training_data.P_in      = P_in_all(train_idx)';
    training_data.dV        = dV_all(train_idx)';
    training_data.dP        = dP_all(train_idx)';
    training_data.target_dV = target_dV_all(train_idx)';

    validation_data.V_in      = V_in_all(val_idx)';
    validation_data.V_prev    = V_prev_all(val_idx)';  % НОВЕ: V_prev в валідаційні дані
    validation_data.I_in      = I_in_all(val_idx)';
    validation_data.P_in      = P_in_all(val_idx)';
    validation_data.dV        = dV_all(val_idx)';
    validation_data.dP        = dP_all(val_idx)';
    validation_data.target_dV = target_dV_all(val_idx)';

    fprintf('✓ Дані згенеровано: %d тренувальних, %d валідаційних\n', ...
        num_train, total - num_train);

    % Збереження (v4 версія)
    save_path = fullfile(this_dir, 'training_data_vi_v4.mat');
    save(save_path, 'training_data', 'validation_data', 'G_pts', 'T_pts');
    fprintf('✓ Збережено в %s\n\n', save_path);

end
