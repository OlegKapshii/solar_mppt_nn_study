% Порівняння P&O та NN MPPT алгоритмів на різних сценаріях

clear; close all; clc;

sim_dir = fileparts(mfilename('fullpath'));
project_dir = fileparts(sim_dir);

addpath(fullfile(project_dir, 'solar_model'));
addpath(fullfile(project_dir, 'cloud_model'));
addpath(fullfile(project_dir, 'mppt_classical'));
addpath(fullfile(project_dir, 'neural_network'));
addpath(fullfile(project_dir, 'data_generation'));
addpath(sim_dir);

fprintf('=== ПОРІВНЮВАЛЬНЕ ДОСЛІДЖЕННЯ MPPT АЛГОРИТМІВ ===\n');
fprintf('Алгоритми: P&O | NN-GT (G,T входи) | NN-VI (V,I,P,dV,dP входи)\n\n');

% Завантажуємо натреновану NN-GT мережу
model_file = fullfile(project_dir, 'neural_network', 'trained_network.mat');
if ~exist(model_file, 'file')
    error('Натренована мережа NN-GT не знайдена! Спочатку запустіть run_full_simulation.m');
end

loaded_model = load(model_file);
network = loaded_model.network;
fprintf('✓ Натренована мережа NN-GT завантажена\n');

% Завантажуємо натреновану NN-VI мережу
model_vi_file = fullfile(project_dir, 'neural_network', 'trained_network_vi_v2.mat');
if ~exist(model_vi_file, 'file')
    error('Натренована мережа NN-VI не знайдена! Спочатку запустіть run_full_simulation.m');
end

loaded_vi = load(model_vi_file);
network_vi = loaded_vi.network_vi;
fprintf('✓ Натренована мережа NN-VI завантажена\n\n');

% Налаштування експериментів
scenarios = {
    struct('name', 'Ясний день', 'cloud', 'clear', 'day', 170),
    struct('name', 'Хмарний день (раптові зміни)', 'cloud', 'sudden', 'day', 170),
    struct('name', 'Хмарний день (частіші хмари)', 'cloud', 'frequent', 'day', 170),
    struct('name', 'Змішаний сценарій', 'cloud', 'mixed', 'day', 170),
    struct('name', 'Зимовий день', 'cloud', 'mixed', 'day', 20),
    struct('name', 'Весняний день', 'cloud', 'gradual', 'day', 100)
};

% Зберігання результатів
all_results = {};
comparison_table = [];

fprintf('Запуск %d сценаріїв...\n\n', length(scenarios));

for scenario_idx = 1:length(scenarios)
    scenario = scenarios{scenario_idx};
    
    fprintf('[%d/%d] %s (%s)...\n', scenario_idx, length(scenarios), ...
            scenario.name, scenario.cloud);
    
    % Генерація даних
    day_of_year = scenario.day;
    start_hour = 10;
    end_hour = 14;
    dt = 1;
    
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
        end
    end
    
    % Застосування хмар
    irradiance_cloudy = apply_cloud_variation(irradiance_clear, scenario.cloud, time_array);
    
    % Температура
    T_ambient_min = 15;
    T_ambient_max = 35;
    T_ambient = T_ambient_min + (T_ambient_max - T_ambient_min) * 0.5 * ...
                (1 + cos(2*pi*(time_array/(12*3600)-0.5)));
    T_panel = T_ambient + 20 * (irradiance_cloudy / 1000).^1.2;
    T_panel = max(15, min(60, T_panel));
    
    % Ініціалізація масивів результатів
    V_po = zeros(1, num_steps);
    P_po = zeros(1, num_steps);
    V_nn = zeros(1, num_steps);
    P_nn = zeros(1, num_steps);
    V_nn_vi = zeros(1, num_steps);
    P_nn_vi = zeros(1, num_steps);
    V_optimal = zeros(1, num_steps);
    P_optimal = zeros(1, num_steps);

    V_po(1)    = 40;
    V_nn_vi(1) = 40;
    deltaV_nn_vi = zeros(1, num_steps);
    P_po_prev  = 0;
    V_po_prev  = 40;
    
    % Основний цикл
    update_counter = 0;
    update_period = 3;
    dV_po = 0.8;
    
    for i = 1:num_steps
        G = irradiance_cloudy(i);
        T = T_panel(i);
        
        % Оптимум
        [V_opt, P_opt, ~] = calculate_panel_output(G, T);
        V_optimal(i) = V_opt;
        P_optimal(i) = P_opt;
        
        % P&O
        [~, P_at_V_po, ~] = calculate_panel_output(G, T, V_po(i));
        P_po(i) = P_at_V_po;
        
        if update_counter == 0
            v_new = mppt_po(V_po_prev, P_po_prev, V_po(i), P_po(i), dV_po);
            if i < num_steps
                V_po(i+1) = v_new;
            end
            P_po_prev = P_po(i);
            V_po_prev = V_po(i);
        else
            if i < num_steps
                V_po(i+1) = V_po(i);
            end
        end
        
        update_counter = mod(update_counter + 1, update_period);
        
        % NN-GT MPPT (нереалістичний: знає G та T)
        inputs = [G; T];
        V_nn(i) = nn_forward(network, inputs);
        [~, P_at_V_nn, ~] = calculate_panel_output(G, T, V_nn(i));
        P_nn(i) = P_at_V_nn;

        % NN-VI MPPT (реалістичний: використовує поточні V, I, P, dV, dP)
        [~, P_at_V_nn_vi, I_nn_vi_curr] = calculate_panel_output(G, T, V_nn_vi(i));
        P_nn_vi(i) = P_at_V_nn_vi;
        if i == 1
            dV_nn_vi_curr = 0;
            dP_nn_vi_curr = 0;
        else
            dV_nn_vi_curr = V_nn_vi(i) - V_nn_vi(i - 1);
            dP_nn_vi_curr = P_nn_vi(i) - P_nn_vi(i - 1);
        end
        deltaV_cmd = nn_forward_vi(network_vi, [V_nn_vi(i); I_nn_vi_curr; P_nn_vi(i); dV_nn_vi_curr; dP_nn_vi_curr]);
        deltaV_cmd = max(-2, min(2, deltaV_cmd));
        deltaV_nn_vi(i) = deltaV_cmd;
        if i < num_steps
            V_nn_vi(i + 1) = V_nn_vi(i) + deltaV_cmd;
            V_nn_vi(i + 1) = max(15, min(65, V_nn_vi(i + 1)));
        end
    end
    
    % Розрахунок метрик
    energy_po     = sum(P_po)     * dt / 3600;
    energy_nn     = sum(P_nn)     * dt / 3600;
    energy_nn_vi  = sum(P_nn_vi)  * dt / 3600;
    energy_optimal = sum(P_optimal) * dt / 3600;

    efficiency_po    = energy_po    / max(energy_optimal, eps) * 100;
    efficiency_nn    = energy_nn    / max(energy_optimal, eps) * 100;
    efficiency_nn_vi = energy_nn_vi / max(energy_optimal, eps) * 100;

    error_po    = mean(abs(V_po    - V_optimal));
    error_nn    = mean(abs(V_nn    - V_optimal));
    error_nn_vi = mean(abs(V_nn_vi - V_optimal));

    oscill_po    = std(diff(V_po));
    oscill_nn    = std(diff(V_nn));
    oscill_nn_vi = std(diff(V_nn_vi));
    
    % Зберігання результатів
    result.scenario_name = scenario.name;
    result.cloud_type = scenario.cloud;
    result.day_of_year = day_of_year;
    result.time = time_array;
    result.irradiance_clear = irradiance_clear;
    result.irradiance_cloudy = irradiance_cloudy;
    result.temperature = T_panel;
    result.V_optimal = V_optimal;
    result.P_optimal = P_optimal;
    result.V_po = V_po;
    result.P_po = P_po;
    result.V_nn = V_nn;
    result.P_nn = P_nn;
    result.V_nn_vi = V_nn_vi;
    result.P_nn_vi = P_nn_vi;
    result.deltaV_nn_vi = deltaV_nn_vi;

    result.metrics.energy_po      = energy_po;
    result.metrics.energy_nn      = energy_nn;
    result.metrics.energy_nn_vi   = energy_nn_vi;
    result.metrics.energy_optimal = energy_optimal;
    result.metrics.efficiency_po    = efficiency_po;
    result.metrics.efficiency_nn    = efficiency_nn;
    result.metrics.efficiency_nn_vi = efficiency_nn_vi;
    result.metrics.error_po    = error_po;
    result.metrics.error_nn    = error_nn;
    result.metrics.error_nn_vi = error_nn_vi;
    result.metrics.oscill_po    = oscill_po;
    result.metrics.oscill_nn    = oscill_nn;
    result.metrics.oscill_nn_vi = oscill_nn_vi;

    all_results{scenario_idx} = result;

    % Додаємо в таблицю порівняння
    comparison_table = [comparison_table; ...
        {scenario.name, energy_po, energy_nn, energy_nn_vi, energy_optimal, ...
         efficiency_po, efficiency_nn, efficiency_nn_vi, error_po, error_nn, error_nn_vi}]; %#ok<AGROW>

    fprintf('  ✓ Енергія P&O: %.1f Wh | NN-GT: %.1f Wh | NN-VI: %.1f Wh | Оптим: %.1f Wh\n', ...
            energy_po, energy_nn, energy_nn_vi, energy_optimal);
    fprintf('    Ефективність P&O: %.1f%% | NN-GT: %.1f%% | NN-VI: %.1f%%\n\n', ...
            efficiency_po, efficiency_nn, efficiency_nn_vi);
end

% Виведення таблиці порівняння
fprintf('=== ТАБЛИЦЯ ПОРІВНЯННЯ ===\n\n');
fprintf('%30s | %9s | %9s | %9s | %9s | %7s | %7s | %7s\n', ...
        'Сценарій', 'P&O (Wh)', 'NN-GT(Wh)', 'NN-VI(Wh)', 'Опт (Wh)', 'P&O %', 'NN-GT%', 'NN-VI%');
fprintf(repmat('-', 1, 110));
fprintf('\n');

for i = 1:size(comparison_table, 1)
    fprintf('%30s | %9.1f | %9.1f | %9.1f | %9.1f | %6.1f%% | %6.1f%% | %6.1f%%\n', ...
            comparison_table{i, 1}, comparison_table{i, 2}, comparison_table{i, 3}, ...
            comparison_table{i, 4}, comparison_table{i, 5}, comparison_table{i, 6}, ...
            comparison_table{i, 7}, comparison_table{i, 8});
end

% Збереження результатів
save(fullfile(sim_dir, 'comparison_results.mat'), 'all_results', 'comparison_table');
fprintf('\n✓ Результати збережені в comparison_results.mat\n\n');

% Візуалізація результатів для вибраного сценарію
fprintf('Відображення графіків для: %s\n', scenarios{2}.name);

figure('Name', 'Порівняння MPPT на хмарному дні', 'NumberTitle', 'off', 'Position', [100 100 1400 900]);

result_selected = all_results{2};
time_hours = result_selected.time / 3600;

% Графік 1: Радіація
subplot(3, 3, 1);
plot(time_hours, result_selected.irradiance_cloudy, 'LineWidth', 1.5);
xlabel('Час [год]');
ylabel('Радіація [W/m²]');
title('Сонячна радіація (раптові зміни)');
grid on;

% Графік 2: Напруга
subplot(3, 3, 2);
plot(time_hours, result_selected.V_optimal, 'g-', 'LineWidth', 2);
hold on;
plot(time_hours, result_selected.V_po, 'b--', 'LineWidth', 1.5);
plot(time_hours, result_selected.V_nn, 'r-.', 'LineWidth', 1.5);
plot(time_hours, result_selected.V_nn_vi, 'm:', 'LineWidth', 2);
xlabel('Час [год]');
ylabel('Напруга [V]');
title('Напруга: Оптимальна vs P&O vs NN-GT vs NN-VI');
legend('Оптимум', 'P&O', 'NN-GT', 'NN-VI', 'Location', 'best');
grid on;

% Графік 3: Потужність
subplot(3, 3, 3);
plot(time_hours, result_selected.P_optimal, 'g-', 'LineWidth', 2);
hold on;
plot(time_hours, result_selected.P_po, 'b--', 'LineWidth', 1.5);
plot(time_hours, result_selected.P_nn, 'r-.', 'LineWidth', 1.5);
plot(time_hours, result_selected.P_nn_vi, 'm:', 'LineWidth', 2);
xlabel('Час [год]');
ylabel('Потужність [W]');
title('Потужність: Оптимальна vs P&O vs NN-GT vs NN-VI');
legend('Оптимум', 'P&O', 'NN-GT', 'NN-VI', 'Location', 'best');
grid on;

% Графік 4: Помилка напруги (наближення до оптимуму)
subplot(3, 3, 4);
error_po    = abs(result_selected.V_po    - result_selected.V_optimal);
error_nn    = abs(result_selected.V_nn    - result_selected.V_optimal);
error_nn_vi = abs(result_selected.V_nn_vi - result_selected.V_optimal);
semilogy(time_hours, error_po,    'b--', 'LineWidth', 1.5);
hold on;
semilogy(time_hours, error_nn,    'r-.', 'LineWidth', 1.5);
semilogy(time_hours, error_nn_vi, 'm:',  'LineWidth', 2);
xlabel('Час [год]');
ylabel('Помилка [V]');
title('Помилка напруги від оптимальної (log scale)');
legend('P&O', 'NN-GT', 'NN-VI');
grid on;

% Графік 5: Ефективність в часі
subplot(3, 3, 5);
eff_po    = result_selected.P_po    ./ result_selected.P_optimal * 100;
eff_nn    = result_selected.P_nn    ./ result_selected.P_optimal * 100;
eff_nn_vi = result_selected.P_nn_vi ./ result_selected.P_optimal * 100;
eff_po(isinf(eff_po) | isnan(eff_po))       = 0;
eff_nn(isinf(eff_nn) | isnan(eff_nn))       = 0;
eff_nn_vi(isinf(eff_nn_vi) | isnan(eff_nn_vi)) = 0;
plot(time_hours, eff_po,    'b--', 'LineWidth', 1.5);
hold on;
plot(time_hours, eff_nn,    'r-.', 'LineWidth', 1.5);
plot(time_hours, eff_nn_vi, 'm:',  'LineWidth', 2);
xlabel('Час [год]');
ylabel('Ефективність [%]');
title('Ефективність в часі (P/P\_optimal)');
legend('P&O', 'NN-GT', 'NN-VI');
ylim([0 110]);
grid on;

% Графік 6: Кумулятивна енергія
subplot(3, 3, 6);
energy_po_cumsum    = cumsum(result_selected.P_po)    * 1 / 3600;
energy_nn_cumsum    = cumsum(result_selected.P_nn)    * 1 / 3600;
energy_nn_vi_cumsum = cumsum(result_selected.P_nn_vi) * 1 / 3600;
energy_opt_cumsum   = cumsum(result_selected.P_optimal) * 1 / 3600;
plot(time_hours, energy_opt_cumsum,   'g-',  'LineWidth', 2);
hold on;
plot(time_hours, energy_po_cumsum,    'b--', 'LineWidth', 1.5);
plot(time_hours, energy_nn_cumsum,    'r-.', 'LineWidth', 1.5);
plot(time_hours, energy_nn_vi_cumsum, 'm:',  'LineWidth', 2);
xlabel('Час [год]');
ylabel('Кумулятивна енергія [Wh]');
title('Вироблена енергія');
legend('Оптимум', 'P&O', 'NN-GT', 'NN-VI');
grid on;

% Графік 7-9: Порівняння всіх сценаріїв
subplot(3, 3, 7);
all_names    = {};
all_po_eff   = [];
all_nn_eff   = [];
all_nn_vi_eff = [];

for i = 1:length(all_results)
    all_names{i}   = all_results{i}.scenario_name; %#ok<AGROW>
    all_po_eff     = [all_po_eff,    all_results{i}.metrics.efficiency_po];    %#ok<AGROW>
    all_nn_eff     = [all_nn_eff,    all_results{i}.metrics.efficiency_nn];    %#ok<AGROW>
    all_nn_vi_eff  = [all_nn_vi_eff, all_results{i}.metrics.efficiency_nn_vi]; %#ok<AGROW>
end

bar(1:length(all_names), [all_po_eff; all_nn_eff; all_nn_vi_eff]');
set(gca, 'XTickLabel', all_names);
ylabel('Ефективність [%]');
title('Порівняння ефективності');
legend('P&O', 'NN-GT', 'NN-VI');
xtickangle(45);
grid on;

% Графік 8
subplot(3, 3, 8);
all_po_error    = [];
all_nn_error    = [];
all_nn_vi_error = [];

for i = 1:length(all_results)
    all_po_error    = [all_po_error,    all_results{i}.metrics.error_po];    %#ok<AGROW>
    all_nn_error    = [all_nn_error,    all_results{i}.metrics.error_nn];    %#ok<AGROW>
    all_nn_vi_error = [all_nn_vi_error, all_results{i}.metrics.error_nn_vi]; %#ok<AGROW>
end

bar(1:length(all_names), [all_po_error; all_nn_error; all_nn_vi_error]');
set(gca, 'XTickLabel', all_names);
ylabel('Середня помилка [V]');
title('Помилка напруги від оптимальної');
legend('P&O', 'NN-GT', 'NN-VI');
xtickangle(45);
grid on;

% Графік 9
subplot(3, 3, 9);
all_po_oscill    = [];
all_nn_oscill    = [];
all_nn_vi_oscill = [];

for i = 1:length(all_results)
    all_po_oscill    = [all_po_oscill,    all_results{i}.metrics.oscill_po];    %#ok<AGROW>
    all_nn_oscill    = [all_nn_oscill,    all_results{i}.metrics.oscill_nn];    %#ok<AGROW>
    all_nn_vi_oscill = [all_nn_vi_oscill, all_results{i}.metrics.oscill_nn_vi]; %#ok<AGROW>
end

bar(1:length(all_names), [all_po_oscill; all_nn_oscill; all_nn_vi_oscill]');
set(gca, 'XTickLabel', all_names);
ylabel('Стандартне відхилення [V]');
title('Стабільність (осциляції напруги)');
legend('P&O', 'NN-GT', 'NN-VI');
xtickangle(45);
grid on;

sgtitle('Порівняльне дослідження MPPT алгоритмів: P&O | NN-GT | NN-VI', ...
        'FontSize', 14, 'FontWeight', 'bold');

fprintf('\n✓ Порівняння завершено\n');
