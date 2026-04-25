% Порівняння MPPT алгоритмів із дослідженням відхилень структури
% Алгоритми:
%   1) P&O
%   2) P&O + піранометр (адаптивний P&O)
%   3) NN-GT (входи G,T)
%   4) NN-VI Pure (входи V,V_prev,I,P,dV,dP)
%   5) NN-VI Hybrid (NN-VI + локальна P&O корекція)

clear; close all; clc;

sim_dir = fileparts(mfilename('fullpath'));
project_dir = fileparts(sim_dir);

addpath(fullfile(project_dir, 'solar_model'));
addpath(fullfile(project_dir, 'cloud_model'));
addpath(fullfile(project_dir, 'mppt_classical'));
addpath(fullfile(project_dir, 'neural_network'));
addpath(fullfile(project_dir, 'data_generation'));
addpath(fullfile(project_dir, 'compat'));
addpath(sim_dir);

use_safe_toolkit();   % gnuplot замість fltk — обхід Win32 err 87

fprintf('=== ПОРІВНЮВАЛЬНЕ ДОСЛІДЖЕННЯ MPPT АЛГОРИТМІВ ===\n');
fprintf('Алгоритми: P&O | P&O+Pyr | NN-GT | NN-VI Pure | NN-VI Hybrid\n\n');

% NN-GT
model_file = fullfile(project_dir, 'neural_network', 'trained_network.mat');
if ~exist(model_file, 'file')
    error('Натренована мережа NN-GT не знайдена. Спочатку запустіть run_full_simulation.m');
end
loaded_model = load(model_file);
network = loaded_model.network;
fprintf('✓ NN-GT завантажена\n');

% NN-VI v4 (покращена версія з V_prev входом та більшою архітектурою)
model_vi_file = fullfile(project_dir, 'neural_network', 'trained_network_vi_v4.mat');
data_vi_file = fullfile(project_dir, 'data_generation', 'training_data_vi_v4.mat');

if ~exist(data_vi_file, 'file')
    fprintf('VI train-дані v4 не знайдено. Генеруємо...\n');
    [training_data_vi, validation_data_vi] = generate_training_data_vi(350);
else
    loaded_data_vi = load(data_vi_file);
    training_data_vi = loaded_data_vi.training_data;
    validation_data_vi = loaded_data_vi.validation_data;
end

retrain_vi = false;
if ~exist(model_vi_file, 'file')
    retrain_vi = true;
else
    loaded_vi = load(model_vi_file);
    network_vi = loaded_vi.network_vi;
    if ~isfield(network_vi, 'version') || network_vi.version < 4
        retrain_vi = true;
    end
end

if retrain_vi
    fprintf('Навчаємо NN-VI v4 (покращена архітектура)...\n');
    network_vi = nn_init_vi();
    [network_vi, training_info_vi] = nn_train_vi(network_vi, training_data_vi, validation_data_vi); %#ok<NASGU>
    save(model_vi_file, 'network_vi', 'training_info_vi');
end

if ~exist('network_vi', 'var')
    loaded_vi = load(model_vi_file);
    network_vi = loaded_vi.network_vi;
end

if isfield(network_vi, 'action_limit')
    action_limit = network_vi.action_limit;
else
    action_limit = 1.2;
end
fprintf('✓ NN-VI v4 завантажена (архітектура 6-24-12-1, action_limit=%.2f V)\n\n', action_limit);

scenarios = {
    struct('name', 'Ясний день', 'cloud', 'clear', 'day', 170, 'stress', 'none'),
    struct('name', 'Хмарний день (раптові зміни)', 'cloud', 'sudden', 'day', 170, 'stress', 'none'),
    struct('name', 'Хмарний день (частіші хмари)', 'cloud', 'frequent', 'day', 170, 'stress', 'none'),
    struct('name', 'Змішаний сценарій', 'cloud', 'mixed', 'day', 170, 'stress', 'none'),
    struct('name', 'Зимовий день', 'cloud', 'mixed', 'day', 20, 'stress', 'none'),
    struct('name', 'Весняний день', 'cloud', 'gradual', 'day', 100, 'stress', 'none'),
    struct('name', 'Stress: фронт + провали', 'cloud', 'mixed', 'day', 170, 'stress', 'storm_front'),
    struct('name', 'Stress: швидке мерехтіння', 'cloud', 'sudden', 'day', 170, 'stress', 'fast_flicker')
};

all_results = {};
comparison_table = {};

fprintf('Запуск %d сценаріїв...\n\n', length(scenarios));

for scenario_idx = 1:length(scenarios)
    scenario = scenarios{scenario_idx};

    fprintf('[%d/%d] %s (%s, stress=%s)...\n', scenario_idx, length(scenarios), ...
            scenario.name, scenario.cloud, scenario.stress);

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

    irradiance_cloudy = apply_cloud_variation(irradiance_clear, scenario.cloud, time_array);

    switch scenario.stress
        case 'storm_front'
            t_norm = time_array / max(time_array);
            front = 1 - 0.35 ./ (1 + exp(-(t_norm - 0.45) * 35));
            dips = ones(size(time_array));
            rng(500 + scenario_idx, 'twister');
            for k = 1:8
                c = randi([1200, num_steps-1200]);
                w = randi([60, 180]);
                a = 0.15 + 0.2 * rand();
                idx = max(1, c-w):min(num_steps, c+w);
                shape = 1 - a * exp(-((idx-c) / (0.45*w)).^2);
                dips(idx) = dips(idx) .* shape;
            end
            irradiance_cloudy = irradiance_cloudy .* front .* dips;

        case 'fast_flicker'
            flicker = 0.78 + 0.20 * sign(sin(2 * pi * time_array / 40));
            flicker = movmean(flicker, 5);
            irradiance_cloudy = irradiance_cloudy .* flicker;

        otherwise
            % no-op
    end

    irradiance_cloudy = max(0, min(1000, irradiance_cloudy));

    T_ambient_min = 15;
    T_ambient_max = 35;
    T_ambient = T_ambient_min + (T_ambient_max - T_ambient_min) * 0.5 * ...
                (1 + cos(2*pi*(time_array/(12*3600)-0.5)));
    T_panel = T_ambient + 20 * (irradiance_cloudy / 1000).^1.2;
    T_panel = max(15, min(60, T_panel));

    V_po = zeros(1, num_steps);        P_po = zeros(1, num_steps);
    V_po_pyr = zeros(1, num_steps);    P_po_pyr = zeros(1, num_steps);
    V_nn = zeros(1, num_steps);        P_nn = zeros(1, num_steps);
    V_vi_pure = zeros(1, num_steps);   P_vi_pure = zeros(1, num_steps);
    V_vi_hybrid = zeros(1, num_steps); P_vi_hybrid = zeros(1, num_steps);
    V_optimal = zeros(1, num_steps);   P_optimal = zeros(1, num_steps);

    V_po(1) = 40;
    V_po_pyr(1) = 40;
    V_vi_pure(1) = 40;
    V_vi_hybrid(1) = 40;

    V_po_prev = 40;      P_po_prev = 0;
    V_po_pyr_prev = 40;  P_po_pyr_prev = 0;
    V_pure_prev = 40;    P_pure_prev = 0;
    V_hyb_prev = 40;     P_hyb_prev = 0;

    dV_cmd_pure = zeros(1, num_steps);
    dV_cmd_hyb = zeros(1, num_steps);

    update_counter = 0;
    update_period = 3;
    dV_po = 0.8;

    for i = 1:num_steps
        G = irradiance_cloudy(i);
        T = T_panel(i);

        [V_opt, P_opt, ~] = calculate_panel_output(G, T);
        V_optimal(i) = V_opt;
        P_optimal(i) = P_opt;

        % P&O
        [~, p_at_v_po, ~] = calculate_panel_output(G, T, V_po(i));
        P_po(i) = p_at_v_po;

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

        % P&O + піранометр (адаптивний)
        [~, p_at_v_po_pyr, ~] = calculate_panel_output(G, T, V_po_pyr(i));
        P_po_pyr(i) = p_at_v_po_pyr;

        if update_counter == 0
            G_prev = irradiance_cloudy(max(1, i-1));
            v_new_pyr = mppt_po_adaptive( ...
                V_po_pyr_prev, P_po_pyr_prev, V_po_pyr(i), P_po_pyr(i), G, G_prev, dV_po);
            if i < num_steps
                V_po_pyr(i+1) = v_new_pyr;
            end
            P_po_pyr_prev = P_po_pyr(i);
            V_po_pyr_prev = V_po_pyr(i);
        else
            if i < num_steps
                V_po_pyr(i+1) = V_po_pyr(i);
            end
        end

        % NN-GT
        V_nn(i) = nn_forward(network, [G; T]);
        [~, p_at_v_nn, ~] = calculate_panel_output(G, T, V_nn(i));
        P_nn(i) = p_at_v_nn;

        % NN-VI Pure
        [~, p_pure, i_pure] = calculate_panel_output(G, T, V_vi_pure(i));
        P_vi_pure(i) = p_pure;

        if i == 1
            V_vi_pure_prev = V_vi_pure(i);  % На першому кроці попередня напруга = поточна
            dV_pure = 0;
            dP_pure = 0;
        else
            V_vi_pure_prev = V_vi_pure(i-1);
            dV_pure = V_vi_pure(i) - V_vi_pure(i-1);
            dP_pure = P_vi_pure(i) - P_vi_pure(i-1);
        end

        % Нове: додаємо V_prev (попередня напруга) як 2-й вхід
        dv_pure = nn_forward_vi(network_vi, [V_vi_pure(i); V_vi_pure_prev; i_pure; P_vi_pure(i); dV_pure; dP_pure]);
        if abs(dP_pure) < 0.5
            dv_pure = 0.5 * dv_pure;
        end
        dv_pure = max(-action_limit, min(action_limit, dv_pure));
        dV_cmd_pure(i) = dv_pure;

        if i < num_steps
            V_vi_pure(i+1) = V_vi_pure(i) + dv_pure;
            V_vi_pure(i+1) = max(15, min(65, V_vi_pure(i+1)));
        end

        % NN-VI Hybrid
        [~, p_hyb, i_hyb] = calculate_panel_output(G, T, V_vi_hybrid(i));
        P_vi_hybrid(i) = p_hyb;

        if i == 1
            V_vi_hybrid_prev = V_vi_hybrid(i);  % На першому кроці попередня напруга = поточна
            dV_hyb = 0;
            dP_hyb = 0;
        else
            V_vi_hybrid_prev = V_vi_hybrid(i-1);
            dV_hyb = V_vi_hybrid(i) - V_vi_hybrid(i-1);
            dP_hyb = P_vi_hybrid(i) - P_vi_hybrid(i-1);
        end

        % Нове: додаємо V_prev (попередня напруга) як 2-й вхід
        dv_nn = nn_forward_vi(network_vi, [V_vi_hybrid(i); V_vi_hybrid_prev; i_hyb; P_vi_hybrid(i); dV_hyb; dP_hyb]);
        V_po_like = mppt_po(V_hyb_prev, P_hyb_prev, V_vi_hybrid(i), P_vi_hybrid(i), 0.6);
        dv_po = V_po_like - V_vi_hybrid(i);

        if i == 1
            dv_hyb = 0.6 * dv_nn;
        elseif dP_hyb < -1.0
            dv_hyb = dv_po;
        elseif sign(dv_nn) ~= sign(dv_po) && abs(dP_hyb) > 2.0
            dv_hyb = 0.75 * dv_po + 0.25 * dv_nn;
        else
            dv_hyb = 0.55 * dv_nn + 0.45 * dv_po;
        end

        if abs(dP_hyb) < 0.5
            dv_hyb = 0.5 * dv_hyb;
        end

        dv_hyb = max(-action_limit, min(action_limit, dv_hyb));
        dV_cmd_hyb(i) = dv_hyb;

        if i < num_steps
            V_vi_hybrid(i+1) = V_vi_hybrid(i) + dv_hyb;
            V_vi_hybrid(i+1) = max(15, min(65, V_vi_hybrid(i+1)));
        end
        V_hyb_prev = V_vi_hybrid(i);
        P_hyb_prev = P_vi_hybrid(i);
    end

    energy_po = sum(P_po) * dt / 3600;
    energy_po_pyr = sum(P_po_pyr) * dt / 3600;
    energy_nn = sum(P_nn) * dt / 3600;
    energy_vi_pure = sum(P_vi_pure) * dt / 3600;
    energy_vi_hybrid = sum(P_vi_hybrid) * dt / 3600;
    energy_opt = sum(P_optimal) * dt / 3600;

    eff_po = 100 * energy_po / max(energy_opt, eps);
    eff_po_pyr = 100 * energy_po_pyr / max(energy_opt, eps);
    eff_nn = 100 * energy_nn / max(energy_opt, eps);
    eff_vi_pure = 100 * energy_vi_pure / max(energy_opt, eps);
    eff_vi_hybrid = 100 * energy_vi_hybrid / max(energy_opt, eps);

    err_po = mean(abs(V_po - V_optimal));
    err_po_pyr = mean(abs(V_po_pyr - V_optimal));
    err_nn = mean(abs(V_nn - V_optimal));
    err_vi_pure = mean(abs(V_vi_pure - V_optimal));
    err_vi_hybrid = mean(abs(V_vi_hybrid - V_optimal));

    osc_po = std(diff(V_po));
    osc_po_pyr = std(diff(V_po_pyr));
    osc_nn = std(diff(V_nn));
    osc_vi_pure = std(diff(V_vi_pure));
    osc_vi_hybrid = std(diff(V_vi_hybrid));

    result.scenario_name = scenario.name;
    result.cloud_type = scenario.cloud;
    result.stress_type = scenario.stress;
    result.day_of_year = day_of_year;
    result.time = time_array;
    result.irradiance_clear = irradiance_clear;
    result.irradiance_cloudy = irradiance_cloudy;
    result.temperature = T_panel;

    result.V_optimal = V_optimal;
    result.P_optimal = P_optimal;

    result.V_po = V_po;
    result.P_po = P_po;

    result.V_po_pyr = V_po_pyr;
    result.P_po_pyr = P_po_pyr;

    result.V_nn = V_nn;
    result.P_nn = P_nn;

    result.V_nn_vi_pure = V_vi_pure;
    result.P_nn_vi_pure = P_vi_pure;
    result.deltaV_nn_vi_pure = dV_cmd_pure;

    result.V_nn_vi = V_vi_hybrid;
    result.P_nn_vi = P_vi_hybrid;
    result.deltaV_nn_vi = dV_cmd_hyb;

    result.metrics.energy_po = energy_po;
    result.metrics.energy_po_pyr = energy_po_pyr;
    result.metrics.energy_nn = energy_nn;
    result.metrics.energy_nn_vi_pure = energy_vi_pure;
    result.metrics.energy_nn_vi = energy_vi_hybrid;
    result.metrics.energy_optimal = energy_opt;

    result.metrics.efficiency_po = eff_po;
    result.metrics.efficiency_po_pyr = eff_po_pyr;
    result.metrics.efficiency_nn = eff_nn;
    result.metrics.efficiency_nn_vi_pure = eff_vi_pure;
    result.metrics.efficiency_nn_vi = eff_vi_hybrid;

    result.metrics.error_po = err_po;
    result.metrics.error_po_pyr = err_po_pyr;
    result.metrics.error_nn = err_nn;
    result.metrics.error_nn_vi_pure = err_vi_pure;
    result.metrics.error_nn_vi = err_vi_hybrid;

    result.metrics.oscill_po = osc_po;
    result.metrics.oscill_po_pyr = osc_po_pyr;
    result.metrics.oscill_nn = osc_nn;
    result.metrics.oscill_nn_vi_pure = osc_vi_pure;
    result.metrics.oscill_nn_vi = osc_vi_hybrid;

    all_results{scenario_idx} = result;

    comparison_table(end+1, :) = { ...
        scenario.name, ...
        energy_po, energy_po_pyr, energy_nn, energy_vi_pure, energy_vi_hybrid, energy_opt, ...
        eff_po, eff_po_pyr, eff_nn, eff_vi_pure, eff_vi_hybrid, ...
        err_po, err_po_pyr, err_nn, err_vi_pure, err_vi_hybrid ...
    }; %#ok<AGROW>

    fprintf('  ✓ Енергія [Wh] P&O %.1f | P&O+Pyr %.1f | NN-GT %.1f | VI-Pure %.1f | VI-Hybrid %.1f | Opt %.1f\n', ...
        energy_po, energy_po_pyr, energy_nn, energy_vi_pure, energy_vi_hybrid, energy_opt);
    fprintf('    Ефективність [%%] P&O %.2f | P&O+Pyr %.2f | NN-GT %.2f | VI-Pure %.2f | VI-Hybrid %.2f\n\n', ...
        eff_po, eff_po_pyr, eff_nn, eff_vi_pure, eff_vi_hybrid);
end

fprintf('=== ТАБЛИЦЯ ПОРІВНЯННЯ ===\n\n');
fprintf('%30s | %8s | %8s | %8s | %8s | %8s | %8s\n', ...
    'Сценарій', 'P&O', 'P&O+Pyr', 'NN-GT', 'VI-Pure', 'VI-Hyb', 'Opt');
fprintf(repmat('-', 1, 107));
fprintf('\n');
for i = 1:size(comparison_table, 1)
    fprintf('%30s | %8.1f | %8.1f | %8.1f | %8.1f | %8.1f | %8.1f\n', ...
        comparison_table{i,1}, comparison_table{i,2}, comparison_table{i,3}, ...
        comparison_table{i,4}, comparison_table{i,5}, comparison_table{i,6}, comparison_table{i,7});
end

save(fullfile(sim_dir, 'comparison_results.mat'), 'all_results', 'comparison_table');
fprintf('\n✓ Результати збережені в comparison_results.mat\n\n');

sel = min(7, length(all_results));
result_selected = all_results{sel};
time_hours = result_selected.time / 3600;

figure('Name', 'Ablation: MPPT алгоритми', 'NumberTitle', 'off', 'Position', [100 100 1450 920]);

subplot(3,3,1);
plot(time_hours, result_selected.irradiance_cloudy, 'LineWidth', 1.4);
xlabel('Час [год]'); ylabel('Радіація [W/m^2]'); title('Сонячна радіація'); grid on;

subplot(3,3,2);
plot(time_hours, result_selected.V_optimal, 'g-', 'LineWidth', 2); hold on;
plot(time_hours, result_selected.V_po, 'b--', 'LineWidth', 1.2);
plot(time_hours, result_selected.V_po_pyr, 'k-', 'LineWidth', 1.2);
plot(time_hours, result_selected.V_nn, 'r-.', 'LineWidth', 1.2);
plot(time_hours, result_selected.V_nn_vi_pure, 'c:', 'LineWidth', 1.8);
plot(time_hours, result_selected.V_nn_vi, 'm-', 'LineWidth', 1.2);
xlabel('Час [год]'); ylabel('Напруга [V]'); title('Напруга');
legend('Оптимум','P&O','P&O+Pyr','NN-GT','NN-VI Pure','NN-VI Hybrid','Location','best'); grid on;

subplot(3,3,3);
plot(time_hours, result_selected.P_optimal, 'g-', 'LineWidth', 2); hold on;
plot(time_hours, result_selected.P_po, 'b--', 'LineWidth', 1.2);
plot(time_hours, result_selected.P_po_pyr, 'k-', 'LineWidth', 1.2);
plot(time_hours, result_selected.P_nn, 'r-.', 'LineWidth', 1.2);
plot(time_hours, result_selected.P_nn_vi_pure, 'c:', 'LineWidth', 1.8);
plot(time_hours, result_selected.P_nn_vi, 'm-', 'LineWidth', 1.2);
xlabel('Час [год]'); ylabel('Потужність [W]'); title('Потужність');
legend('Оптимум','P&O','P&O+Pyr','NN-GT','NN-VI Pure','NN-VI Hybrid','Location','best'); grid on;

subplot(3,3,4);
semilogy(time_hours, abs(result_selected.V_po - result_selected.V_optimal), 'b--', 'LineWidth', 1.2); hold on;
semilogy(time_hours, abs(result_selected.V_po_pyr - result_selected.V_optimal), 'k-', 'LineWidth', 1.2);
semilogy(time_hours, abs(result_selected.V_nn - result_selected.V_optimal), 'r-.', 'LineWidth', 1.2);
semilogy(time_hours, abs(result_selected.V_nn_vi_pure - result_selected.V_optimal), 'c:', 'LineWidth', 1.8);
semilogy(time_hours, abs(result_selected.V_nn_vi - result_selected.V_optimal), 'm-', 'LineWidth', 1.2);
xlabel('Час [год]'); ylabel('|V-Vopt| [V]'); title('Помилка напруги (log)');
legend('P&O','P&O+Pyr','NN-GT','NN-VI Pure','NN-VI Hybrid','Location','best'); grid on;

subplot(3,3,5);
eff_po = 100 * result_selected.P_po ./ max(result_selected.P_optimal, eps);
eff_po_pyr = 100 * result_selected.P_po_pyr ./ max(result_selected.P_optimal, eps);
eff_nn = 100 * result_selected.P_nn ./ max(result_selected.P_optimal, eps);
eff_vi_p = 100 * result_selected.P_nn_vi_pure ./ max(result_selected.P_optimal, eps);
eff_vi_h = 100 * result_selected.P_nn_vi ./ max(result_selected.P_optimal, eps);
plot(time_hours, eff_po, 'b--', 'LineWidth', 1.2); hold on;
plot(time_hours, eff_po_pyr, 'k-', 'LineWidth', 1.2);
plot(time_hours, eff_nn, 'r-.', 'LineWidth', 1.2);
plot(time_hours, eff_vi_p, 'c:', 'LineWidth', 1.8);
plot(time_hours, eff_vi_h, 'm-', 'LineWidth', 1.2);
xlabel('Час [год]'); ylabel('Ефективність [%]'); title('Локальна ефективність');
legend('P&O','P&O+Pyr','NN-GT','NN-VI Pure','NN-VI Hybrid','Location','best'); grid on; ylim([80 105]);

subplot(3,3,6);
plot(time_hours, cumsum(result_selected.P_optimal)/3600, 'g-', 'LineWidth', 2); hold on;
plot(time_hours, cumsum(result_selected.P_po)/3600, 'b--', 'LineWidth', 1.2);
plot(time_hours, cumsum(result_selected.P_po_pyr)/3600, 'k-', 'LineWidth', 1.2);
plot(time_hours, cumsum(result_selected.P_nn)/3600, 'r-.', 'LineWidth', 1.2);
plot(time_hours, cumsum(result_selected.P_nn_vi_pure)/3600, 'c:', 'LineWidth', 1.8);
plot(time_hours, cumsum(result_selected.P_nn_vi)/3600, 'm-', 'LineWidth', 1.2);
xlabel('Час [год]'); ylabel('Енергія [Wh]'); title('Кумулятивна енергія');
legend('Opt','P&O','P&O+Pyr','NN-GT','NN-VI Pure','NN-VI Hybrid','Location','best'); grid on;

names = cellfun(@(r) r.scenario_name, all_results, 'UniformOutput', false);
po_eff = cellfun(@(r) r.metrics.efficiency_po, all_results);
po_pyr_eff = cellfun(@(r) r.metrics.efficiency_po_pyr, all_results);
nn_eff = cellfun(@(r) r.metrics.efficiency_nn, all_results);
vi_p_eff = cellfun(@(r) r.metrics.efficiency_nn_vi_pure, all_results);
vi_h_eff = cellfun(@(r) r.metrics.efficiency_nn_vi, all_results);

subplot(3,3,7);
bar([po_eff; po_pyr_eff; nn_eff; vi_p_eff; vi_h_eff]');
set(gca, 'XTickLabel', names); xtickangle(40);
ylabel('Ефективність [%]'); title('Порівняння ефективності');
legend('P&O','P&O+Pyr','NN-GT','NN-VI Pure','NN-VI Hybrid','Location','best'); grid on;

po_err = cellfun(@(r) r.metrics.error_po, all_results);
po_pyr_err = cellfun(@(r) r.metrics.error_po_pyr, all_results);
nn_err = cellfun(@(r) r.metrics.error_nn, all_results);
vi_p_err = cellfun(@(r) r.metrics.error_nn_vi_pure, all_results);
vi_h_err = cellfun(@(r) r.metrics.error_nn_vi, all_results);

subplot(3,3,8);
bar([po_err; po_pyr_err; nn_err; vi_p_err; vi_h_err]');
set(gca, 'XTickLabel', names); xtickangle(40);
ylabel('MAE напруги [V]'); title('Похибка напруги');
legend('P&O','P&O+Pyr','NN-GT','NN-VI Pure','NN-VI Hybrid','Location','best'); grid on;

po_osc = cellfun(@(r) r.metrics.oscill_po, all_results);
po_pyr_osc = cellfun(@(r) r.metrics.oscill_po_pyr, all_results);
nn_osc = cellfun(@(r) r.metrics.oscill_nn, all_results);
vi_p_osc = cellfun(@(r) r.metrics.oscill_nn_vi_pure, all_results);
vi_h_osc = cellfun(@(r) r.metrics.oscill_nn_vi, all_results);

subplot(3,3,9);
bar([po_osc; po_pyr_osc; nn_osc; vi_p_osc; vi_h_osc]');
set(gca, 'XTickLabel', names); xtickangle(40);
ylabel('std(dV) [V]'); title('Стабільність напруги');
legend('P&O','P&O+Pyr','NN-GT','NN-VI Pure','NN-VI Hybrid','Location','best'); grid on;

sgtitle(sprintf('Ablation MPPT: %s', result_selected.scenario_name), 'FontSize', 14, 'FontWeight', 'bold');

fprintf('\n✓ Порівняння завершено\n');
