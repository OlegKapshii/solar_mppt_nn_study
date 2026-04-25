% Основна симуляція системи MPPT
% Порівняння класичного P&O та простої нейромережі

clear; close all; clc;

sim_dir = fileparts(mfilename('fullpath'));
project_dir = fileparts(sim_dir);

addpath(fullfile(project_dir, 'solar_model'));
addpath(fullfile(project_dir, 'cloud_model'));
addpath(fullfile(project_dir, 'mppt_classical'));
addpath(fullfile(project_dir, 'neural_network'));
addpath(fullfile(project_dir, 'data_generation'));
addpath(sim_dir);

fprintf('=== Симуляція MPPT системи ===\n');
fprintf('Алгоритми: P&O | NN-GT (G,T входи) | NN-VI Hybrid (V,I,P,dV,dP входи)\n\n');

data_file    = fullfile(project_dir, 'data_generation', 'training_data.mat');
model_file   = fullfile(project_dir, 'neural_network', 'trained_network.mat');
data_vi_file  = fullfile(project_dir, 'data_generation', 'training_data_vi_v3.mat');
model_vi_file = fullfile(project_dir, 'neural_network', 'trained_network_vi_v3.mat');

% КРОК 1: Генерація даних (якщо ще не існує)
if ~exist(data_file, 'file')
    fprintf('Файл тренувальних даних не знайдений.\n');
    fprintf('Генеруємо нові дані...\n\n');
    [training_data, validation_data] = generate_training_data(220);
else
    fprintf('Завантажуємо існуючі тренувальні дані...\n');
    loaded = load(data_file);
    training_data = loaded.training_data;
    validation_data = loaded.validation_data;
    fprintf('✓ Дані завантажені\n\n');
end

% КРОК 2: Ініціалізація та тренування NN-GT (G, T → V_opt)
fprintf('--- NN-GT (входи: освітленість G, температура T) ---\n');
network = nn_init();

if ~exist(model_file, 'file')
    fprintf('Натренованої мережі NN-GT не знайдено. Розпочинаємо тренування...\n\n');
    [network, training_info] = nn_train(network, training_data, validation_data);
    save(model_file, 'network', 'training_info');
    fprintf('\n✓ NN-GT натренована і збережена\n\n');
else
    fprintf('Завантажуємо натреновану мережу NN-GT...\n');
    loaded_model = load(model_file);
    network = loaded_model.network;
    fprintf('✓ NN-GT завантажена\n\n');
end

% КРОК 2б: Ініціалізація та тренування NN-VI (V, I, P, dV, dP → deltaV)
fprintf('--- NN-VI (входи: V, I, P, dV, dP; вихід: deltaV) ---\n');
network_vi = nn_init_vi();

if ~exist(data_vi_file, 'file')
    fprintf('VI тренувальних даних не знайдено. Генеруємо...\n\n');
    [training_data_vi, validation_data_vi] = generate_training_data_vi(260);
else
    fprintf('Завантажуємо VI тренувальні дані...\n');
    loaded_vi = load(data_vi_file);
    training_data_vi   = loaded_vi.training_data;
    validation_data_vi = loaded_vi.validation_data;
    fprintf('✓ VI дані завантажені\n\n');
end

if ~exist(model_vi_file, 'file')
    fprintf('Натренованої мережі NN-VI не знайдено. Розпочинаємо тренування...\n\n');
    [network_vi, training_info_vi] = nn_train_vi(network_vi, training_data_vi, validation_data_vi);
    save(model_vi_file, 'network_vi', 'training_info_vi');
    fprintf('\n✓ NN-VI натренована і збережена\n\n');
else
    fprintf('Завантажуємо натреновану мережу NN-VI...\n');
    loaded_vi_model = load(model_vi_file);
    network_vi = loaded_vi_model.network_vi;
    if ~isfield(network_vi, 'version') || network_vi.version < 3
        fprintf('Знайдена застаріла NN-VI модель. Перетреновуємо...\n\n');
        [network_vi, training_info_vi] = nn_train_vi(network_vi, training_data_vi, validation_data_vi);
        save(model_vi_file, 'network_vi', 'training_info_vi');
    end
    fprintf('✓ NN-VI завантажена\n\n');
end

% КРОК 3: Налаштування сценарію симуляції
fprintf('Налаштування сценарію симуляції...\n');

% День року (1-365). Виберемо літній день в середині червня
day_of_year = 170;  % Приблизно 19 червня

% Короткий відрізок із проблемними моментами для P&O
start_hour = 10;
end_hour = 14;
dt = 1;  % Крок часу = 1 секунда

% Сценарій хмар
cloud_scenario = 'mixed';  % Варіанти: 'clear', 'gradual', 'sudden', 'frequent', 'mixed'

fprintf('Параметри симуляції:\n');
fprintf('  День року: %d\n', day_of_year);
fprintf('  Часовий інтервал: %02d:00 - %02d:00\n', start_hour, end_hour);
fprintf('  Сценарій хмар: %s\n', cloud_scenario);
fprintf('  Крок часу: %d сек\n\n', dt);

% КРОК 4: Розрахунок сонячної радіації без хмар
fprintf('Розрахунок сонячної радіації...\n');

num_steps = (end_hour - start_hour) * 3600 / dt;
time_array = (0:num_steps-1) * dt;
irradiance_clear = zeros(1, num_steps);

for i = 1:num_steps
    t_sec = time_array(i);
    hour_decimal = start_hour + t_sec / 3600;
    hour = floor(hour_decimal);
    minute = floor((hour_decimal - hour) * 60);
    
    if hour <= end_hour
        irradiance_clear(i) = get_solar_irradiance(day_of_year, hour, minute);
    else
        irradiance_clear(i) = 0;
    end
end

fprintf('✓ Радіація розрахована (max: %.1f W/m²)\n\n', max(irradiance_clear));

% КРОК 5: Застосування варіацій хмар
fprintf('Генерація варіацій хмар (%s)...\n', cloud_scenario);
irradiance_cloudy = apply_cloud_variation(irradiance_clear, cloud_scenario, time_array);
fprintf('✓ Хмари застосовані (ефективно max: %.1f W/m²)\n\n', max(irradiance_cloudy));

% КРОК 6: Модель температури панелі
fprintf('Розрахунок температури панелі...\n');
% Спрощена модель: температура залежить від освітленості та часу
T_ambient_min = 15;  % °C (ночі)
T_ambient_max = 35;  % °C (день)
T_ambient = T_ambient_min + (T_ambient_max - T_ambient_min) * 0.5 * ...
            (1 + cos(2*pi*(time_array/(12*3600)-0.5)));

% Температура панелі = зовнішня + підвищення через нагрів
T_panel = T_ambient + 20 * (irradiance_cloudy / 1000).^1.2;
T_panel = max(15, min(60, T_panel));  % Обмеження [15, 60]

fprintf('✓ Температура розрахована (діапазон: %.1f-%.1f °C)\n\n', ...
    min(T_panel), max(T_panel));

% КРОК 7: Ініціалізація MPPT алгоритмів
fprintf('Ініціалізація MPPT контролерів...\n');

% P&O параметри
V_po = zeros(1, num_steps);
I_po = zeros(1, num_steps);
P_po = zeros(1, num_steps);
V_po(1) = 40;  % Стартова напруга [V]
V_po_prev = V_po(1);
P_po_prev = 0;

% NN-GT MPPT (використовує G та T — нереалістично)
V_nn = zeros(1, num_steps);
I_nn = zeros(1, num_steps);
P_nn = zeros(1, num_steps);

% NN-VI Hybrid MPPT (використовує лише доступні вимірювання)
V_nn_vi = zeros(1, num_steps);
I_nn_vi = zeros(1, num_steps);
P_nn_vi = zeros(1, num_steps);
V_nn_vi(1) = 40;  % Стартова напруга [V] (така сама як P&O)
deltaV_nn_vi = zeros(1, num_steps);
V_nn_vi_prev = V_nn_vi(1);
P_nn_vi_prev = 0;

% Оптимальні значення (теоретичні)
V_optimal = zeros(1, num_steps);
P_optimal = zeros(1, num_steps);

fprintf('✓ Контролери ініціалізовані\n\n');

% КРОК 8: Основний цикл симуляції
fprintf('Запуск основного циклу симуляції...\n');
fprintf('Прогрес: ');

% Період оновлення P&O = 1 секунда, але розраховуємо кожен крок
update_period = 3;  % 3 кроки (щоб проявити інерційність класичного P&O)
dV_po = 0.8;
update_counter = 0;

for i = 1:num_steps
    % Поточні умови
    G = irradiance_cloudy(i);
    T = T_panel(i);
    
    % Розрахунок оптимальної напруги та потужності
    [V_opt, P_opt, ~] = calculate_panel_output(G, T);
    V_optimal(i) = V_opt;
    P_optimal(i) = P_opt;
    
    % === P&O MPPT ===
    % Розраховуємо вихід на поточній напрузі
    [~, P_at_V_po, I_po(i)] = calculate_panel_output(G, T, V_po(i));
    P_po(i) = P_at_V_po;
    
    % Оновлення напруги кожен період
    if update_counter == 0
        V_po_new = mppt_po(V_po_prev, P_po_prev, V_po(i), P_po(i), dV_po);
        if i < num_steps
            V_po(i+1) = V_po_new;
        end
        P_po_prev = P_po(i);
        V_po_prev = V_po(i);
    else
        if i < num_steps
            V_po(i+1) = V_po(i);
        end
    end
    
    update_counter = mod(update_counter + 1, update_period);
    
    % === NN-GT MPPT (нереалістичний: знає G та T) ===
    % Пряме прогнозування оптимальної напруги за освітленістю та температурою
    inputs = [G; T];
    V_nn(i) = nn_forward(network, inputs);

    % Розраховуємо вихід при NN-GT напрузі
    [~, P_at_V_nn, I_nn(i)] = calculate_panel_output(G, T, V_nn(i));
    P_nn(i) = P_at_V_nn;

    % === NN-VI Hybrid MPPT ===
    % Мережа дає рекомендацію deltaV, але локальна P&O-перевірка не дозволяє
    % систематично йти в гірший бік при помилковому прогнозі.
    [~, P_at_V_nn_vi, I_nn_vi(i)] = calculate_panel_output(G, T, V_nn_vi(i));
    P_nn_vi(i) = P_at_V_nn_vi;

    if i == 1
        dV_nn_vi_curr = 0;
        dP_nn_vi_curr = 0;
    else
        dV_nn_vi_curr = V_nn_vi(i) - V_nn_vi(i - 1);
        dP_nn_vi_curr = P_nn_vi(i) - P_nn_vi(i - 1);
    end

    % Рекомендація від мережі
    deltaV_nn = nn_forward_vi(network_vi, [V_nn_vi(i); I_nn_vi(i); P_nn_vi(i); dV_nn_vi_curr; dP_nn_vi_curr]);

    % Локальна корекція у стилі P&O для страхування від хибних кроків NN
    V_po_like = mppt_po(V_nn_vi_prev, P_nn_vi_prev, V_nn_vi(i), P_nn_vi(i), 0.6);
    deltaV_po_like = V_po_like - V_nn_vi(i);

    if i == 1
        deltaV_cmd = 0.6 * deltaV_nn;
    elseif dP_nn_vi_curr < -1.0
        % Якщо останній крок зменшив потужність, довіряємо локальній корекції.
        deltaV_cmd = deltaV_po_like;
    elseif sign(deltaV_nn) ~= sign(deltaV_po_like) && abs(dP_nn_vi_curr) > 2.0
        % При сильному конфлікті напрямків і помітній зміні потужності
        % обираємо більш надійний локальний напрямок.
        deltaV_cmd = 0.75 * deltaV_po_like + 0.25 * deltaV_nn;
    else
        % У нормальному режимі змішуємо швидку реакцію NN і локальну стабільність.
        deltaV_cmd = 0.55 * deltaV_nn + 0.45 * deltaV_po_like;
    end

    if abs(dP_nn_vi_curr) < 0.5
        % Поблизу MPP зменшуємо агресивність кроку.
        deltaV_cmd = 0.5 * deltaV_cmd;
    end

    deltaV_cmd = max(-1.2, min(1.2, deltaV_cmd));
    deltaV_nn_vi(i) = deltaV_cmd;

    if i < num_steps
        V_nn_vi(i + 1) = V_nn_vi(i) + deltaV_cmd;
        V_nn_vi(i + 1) = max(15, min(65, V_nn_vi(i + 1)));
    end

    P_nn_vi_prev = P_nn_vi(i);
    V_nn_vi_prev = V_nn_vi(i);
    
    % Вивід прогресу
    if mod(i, max(1, floor(num_steps / 10))) == 0
        fprintf('%d%% ', round(100 * i / num_steps));
    end
end

fprintf('\n✓ Симуляція завершена\n\n');

% КРОК 9: Розрахунок метрик
fprintf('Розрахунок метрик...\n');

% Енергія за період
energy_po    = sum(P_po)    * dt / 3600;  % [Wh]
energy_nn    = sum(P_nn)    * dt / 3600;  % [Wh]
energy_nn_vi = sum(P_nn_vi) * dt / 3600;  % [Wh]
energy_optimal = sum(P_optimal) * dt / 3600;

% Ефективність
efficiency_po    = energy_po    / max(energy_optimal, eps) * 100;
efficiency_nn    = energy_nn    / max(energy_optimal, eps) * 100;
efficiency_nn_vi = energy_nn_vi / max(energy_optimal, eps) * 100;

% Осциляції напруги
oscill_po    = std(diff(V_po));
oscill_nn    = std(diff(V_nn));
oscill_nn_vi = std(diff(V_nn_vi));

% Похибка напруги від оптимальної
error_po    = mean(abs(V_po    - V_optimal));
error_nn    = mean(abs(V_nn    - V_optimal));
error_nn_vi = mean(abs(V_nn_vi - V_optimal));

fprintf('✓ Метрики розраховані\n\n');

% КРОК 10: Виведення результатів
fprintf('=== РЕЗУЛЬТАТИ СИМУЛЯЦІЇ ===\n\n');
fprintf('Вироблена енергія за період:\n');
fprintf('  P&O MPPT:      %.2f Wh\n', energy_po);
fprintf('  NN-GT MPPT:    %.2f Wh  (входи: G, T — нереалістично)\n', energy_nn);
fprintf('  NN-VI Hybrid:  %.2f Wh  (NN + локальна P&O корекція)\n', energy_nn_vi);
fprintf('  Оптимальна:    %.2f Wh\n', energy_optimal);

fprintf('\nЕфективність відслідковування:\n');
fprintf('  P&O MPPT:      %.2f%%\n', efficiency_po);
fprintf('  NN-GT MPPT:    %.2f%%\n', efficiency_nn);
fprintf('  NN-VI Hybrid:  %.2f%%\n', efficiency_nn_vi);

fprintf('\nПохибка напруги від оптимальної (MAE):\n');
fprintf('  P&O MPPT:      %.2f V\n', error_po);
fprintf('  NN-GT MPPT:    %.2f V\n', error_nn);
fprintf('  NN-VI Hybrid:  %.2f V\n', error_nn_vi);

fprintf('\nОсциляції напруги (std):\n');
fprintf('  P&O MPPT:      %.4f V\n', oscill_po);
fprintf('  NN-GT MPPT:    %.4f V\n', oscill_nn);
fprintf('  NN-VI Hybrid:  %.4f V\n', oscill_nn_vi);
fprintf('  Середній |deltaV| NN-VI: %.4f V\n', mean(abs(deltaV_nn_vi)));

% КРОК 11: Збереження результатів
fprintf('\nЗбереження результатів...\n');

results.time = time_array;
results.day_of_year = day_of_year;
results.cloud_scenario = cloud_scenario;
results.irradiance_clear = irradiance_clear;
results.irradiance_cloudy = irradiance_cloudy;
results.temperature = T_panel;
results.V_optimal = V_optimal;
results.P_optimal = P_optimal;
results.V_po = V_po;
results.I_po = I_po;
results.P_po = P_po;
results.V_nn = V_nn;
results.I_nn = I_nn;
results.P_nn = P_nn;
results.V_nn_vi = V_nn_vi;
results.I_nn_vi = I_nn_vi;
results.P_nn_vi = P_nn_vi;
results.deltaV_nn_vi = deltaV_nn_vi;

results.metrics.energy_po      = energy_po;
results.metrics.energy_nn      = energy_nn;
results.metrics.energy_nn_vi   = energy_nn_vi;
results.metrics.energy_optimal = energy_optimal;
results.metrics.efficiency_po    = efficiency_po;
results.metrics.efficiency_nn    = efficiency_nn;
results.metrics.efficiency_nn_vi = efficiency_nn_vi;
results.metrics.error_po    = error_po;
results.metrics.error_nn    = error_nn;
results.metrics.error_nn_vi = error_nn_vi;

save(fullfile(sim_dir, 'simulation_results.mat'), 'results', 'network');
fprintf('✓ Результати збережені в simulation/simulation_results.mat\n\n');

% КРОК 12: Візуалізація результатів
fprintf('Відображення графіків...\n');
plot_simulation_results(results);

fprintf('\n=== Симуляція завершена успішно ===\n');
