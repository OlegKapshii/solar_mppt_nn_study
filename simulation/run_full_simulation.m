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

fprintf('=== Симуляція MPPT системи ===\n\n');

data_file = fullfile(project_dir, 'data_generation', 'training_data.mat');
model_file = fullfile(project_dir, 'neural_network', 'trained_network.mat');

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

% КРОК 2: Ініціалізація та тренування нейромережи
fprintf('Ініціалізація нейронної мережи...\n');
network = nn_init();

% Перевіряємо чи існує натренована мережа
if ~exist(model_file, 'file')
    fprintf('Натренованої мережі не знайдено.\n');
    fprintf('Розпочинаємо тренування...\n\n');
    
    [network, training_info] = nn_train(network, training_data, validation_data);
    
    % Зберігаємо натреновану мережу
    save(model_file, 'network', 'training_info');
    fprintf('\n✓ Мережа натренована і збережена\n\n');
else
    fprintf('Завантажуємо натреновану мережу...\n');
    loaded_model = load(model_file);
    network = loaded_model.network;
    fprintf('✓ Мережа завантажена\n\n');
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

% NN MPPT
V_nn = zeros(1, num_steps);
I_nn = zeros(1, num_steps);
P_nn = zeros(1, num_steps);

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
    
    % === NN MPPT ===
    % Пряме прогнозування оптимальної напруги
    inputs = [G; T];
    V_nn(i) = nn_forward(network, inputs);
    
    % Розраховуємо вихід при NN напрузі
    [~, P_at_V_nn, I_nn(i)] = calculate_panel_output(G, T, V_nn(i));
    P_nn(i) = P_at_V_nn;
    
    % Вивід прогресу
    if mod(i, max(1, floor(num_steps / 10))) == 0
        fprintf('%d%% ', round(100 * i / num_steps));
    end
end

fprintf('\n✓ Симуляція завершена\n\n');

% КРОК 9: Розрахунок метрик
fprintf('Розрахунок метрик...\n');

% Енергія за період
energy_po = sum(P_po) * dt / 3600;      % [Wh]
energy_nn = sum(P_nn) * dt / 3600;      % [Wh]
energy_optimal = sum(P_optimal) * dt / 3600;  % [Wh]

% Ефективність
efficiency_po = energy_po / max(energy_optimal, eps) * 100;
efficiency_nn = energy_nn / max(energy_optimal, eps) * 100;

% Осциляції напруги
oscill_po = std(diff(V_po));
oscill_nn = std(diff(V_nn));

% Похибка напруги від оптимальної
error_po = mean(abs(V_po - V_optimal));
error_nn = mean(abs(V_nn - V_optimal));

fprintf('✓ Метрики розраховані\n\n');

% КРОК 10: Виведення результатів
fprintf('=== РЕЗУЛЬТАТИ СИМУЛЯЦІЇ ===\n\n');
fprintf('Вироблена енергія за період:\n');
fprintf('  P&O MPPT:      %.2f Wh\n', energy_po);
fprintf('  NN MPPT:       %.2f Wh\n', energy_nn);
fprintf('  Оптимальна:    %.2f Wh\n', energy_optimal);

fprintf('\nЕфективність відслідковування:\n');
fprintf('  P&O MPPT:      %.2f%%\n', efficiency_po);
fprintf('  NN MPPT:       %.2f%%\n', efficiency_nn);

fprintf('\nПохибка напруги від оптимальної (MAE):\n');
fprintf('  P&O MPPT:      %.2f V\n', error_po);
fprintf('  NN MPPT:       %.2f V\n', error_nn);

fprintf('\nОсциляції напруги (std):\n');
fprintf('  P&O MPPT:      %.4f V\n', oscill_po);
fprintf('  NN MPPT:       %.4f V\n', oscill_nn);

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

results.metrics.energy_po = energy_po;
results.metrics.energy_nn = energy_nn;
results.metrics.energy_optimal = energy_optimal;
results.metrics.efficiency_po = efficiency_po;
results.metrics.efficiency_nn = efficiency_nn;
results.metrics.error_po = error_po;
results.metrics.error_nn = error_nn;

save(fullfile(sim_dir, 'simulation_results.mat'), 'results', 'network');
fprintf('✓ Результати збережені в simulation/simulation_results.mat\n\n');

% КРОК 12: Візуалізація результатів
fprintf('Відображення графіків...\n');
plot_simulation_results(results);

fprintf('\n=== Симуляція завершена успішно ===\n');
