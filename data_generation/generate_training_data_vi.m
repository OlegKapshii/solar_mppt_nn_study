% Генерація синтетичних даних для тренування динамічної VI нейронної мережи MPPT (v5)
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
        num_conditions = 350;  % Збільшена кількість умов для більшої мережі (v5)
    end

    this_dir    = fileparts(mfilename('fullpath'));
    project_dir = fileparts(this_dir);
    addpath(fullfile(project_dir, 'solar_model'));
    addpath(fullfile(project_dir, 'neural_network'));

    dataset_version = 5;

    % Кількість локальних переходів для кожної умови (G, T)
    N_per_condition = 48;  % Більше різноманітних станів на одну умову
    % action_limit має узгоджуватись з nn_init_vi.m::action_limit, інакше
    % тренувальні дані будуть обрізані до іншого діапазону, ніж очікує
    % мережа на інференсі.
    tmp_net = nn_init_vi();
    action_limit = tmp_net.action_limit;

    total = num_conditions * N_per_condition;

    fprintf('Генерація VI тренувальних даних (v5)...\n');
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

    idx = 1;
    for k = 1:num_conditions
        G = G_pts(k);
        T = T_pts(k);

        % Оптимальна напруга для цієї умови
        [V_opt, ~, ~] = calculate_panel_output(G, T);

        for j = 1:N_per_condition
            [V_prev, V_current] = sample_vi_state(V_opt);
            [~, P_prev, ~] = calculate_panel_output(G, T, V_prev);
            [~, P_current, I_current] = calculate_panel_output(G, T, V_current);

            dV = V_current - V_prev;
            dP = P_current - P_prev;

            target_dV = teacher_delta_v(V_current, V_opt, dV, dP, action_limit);

            V_in_all(idx)      = V_current;
            V_prev_all(idx)    = V_prev;      % НОВЕ: зберігаємо попередню напругу
            I_in_all(idx)      = max(0, I_current);
            P_in_all(idx)      = max(0, P_current);
            dV_all(idx)        = dV;
            dP_all(idx)        = dP;
            target_dV_all(idx) = target_dV;
            idx = idx + 1;
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
    save_path = fullfile(this_dir, 'training_data_vi_v5.mat');
    save(save_path, 'training_data', 'validation_data', 'G_pts', 'T_pts', 'dataset_version');
    fprintf('✓ Збережено в %s\n\n', save_path);

end

function [V_prev, V_current] = sample_vi_state(V_opt)
    % Покриваємо три режими: далеко від MPP, зрив/відновлення, локальна область.
    region = rand();

    if region < 0.40
        % Далеко від MPP: pure мережа має вміти швидко повертатися.
        if rand() < 0.5
            V_current = max(30, V_opt - (35 + 85 * rand()));
        else
            V_current = min(320, V_opt + (35 + 85 * rand()));
        end
        V_prev = V_current - (2 * rand() - 1) * (2 + 6 * rand());
    elseif region < 0.75
        % Recovery після неправильного локального кроку.
        V_current = min(320, max(30, V_opt + 18 * randn()));
        wrong_dir = sign(rand() - 0.5);
        if wrong_dir == 0
            wrong_dir = 1;
        end
        V_prev = V_current - wrong_dir * (2 + 6 * rand());
    else
        % Біля MPP: мережа має вміти демпфувати та точно доводити.
        V_current = min(320, max(30, V_opt + 8 * randn()));
        V_prev = V_current - (2 * rand() - 1) * (0.2 + 2.0 * rand());
    end

    V_prev = min(320, max(30, V_prev));
    V_current = min(320, max(30, V_current));
end

function target_dV = teacher_delta_v(V_current, V_opt, dV, dP, action_limit)
    V_err = V_opt - V_current;
    abs_err = abs(V_err);

    if abs_err > 70
        target_dV = sign(V_err) * action_limit;
    elseif abs_err > 30
        target_dV = sign(V_err) * 0.85 * action_limit;
    elseif abs_err > 10
        target_dV = 0.55 * V_err;
    else
        target_dV = 0.30 * V_err;
    end

    % Якщо попередній рух знижував потужність, робимо корекцію агресивнішою.
    if dP < -10 && abs(dV) > 0.25 && sign(dV) ~= sign(V_err)
        target_dV = target_dV + 0.35 * sign(V_err) * action_limit;
    end

    target_dV = max(-action_limit, min(action_limit, target_dV));
end
