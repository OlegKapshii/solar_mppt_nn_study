clear;
clc;

fprintf('=== ЕКСПЕРИМЕНТИ ДЛЯ ПОШУКУ ПЕРЕВАГИ NN MPPT ===\n\n');

project_dir = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_dir, 'solar_model'));
addpath(fullfile(project_dir, 'mppt_classical'));
addpath(fullfile(project_dir, 'neural_network'));
addpath(fullfile(project_dir, 'cloud_model'));

gt_model_file = fullfile(project_dir, 'neural_network', 'trained_network.mat');
vi_model_file = fullfile(project_dir, 'neural_network', 'trained_network_vi_v5.mat');

gt_loaded = load(gt_model_file);
network_gt = gt_loaded.network;

vi_loaded = load(vi_model_file);
network_vi = vi_loaded.network_vi;
action_limit = network_vi.action_limit;

experiments = {
    struct('name', 'Fast flicker baseline',      'stress', 'fast_flicker',   'cloud', 'sudden', 'day', 170, 'update_period', 3,  'power_noise_frac', 0.00, 'power_delay_steps', 0),
    struct('name', 'Fast flicker + slow P&O',    'stress', 'fast_flicker',   'cloud', 'sudden', 'day', 170, 'update_period', 12, 'power_noise_frac', 0.00, 'power_delay_steps', 0),
    struct('name', 'Fast flicker + slow/noisy',  'stress', 'fast_flicker',   'cloud', 'sudden', 'day', 170, 'update_period', 12, 'power_noise_frac', 0.02, 'power_delay_steps', 0),
    struct('name', 'Storm front + slow/noisy',   'stress', 'storm_front',    'cloud', 'mixed',  'day', 170, 'update_period', 10, 'power_noise_frac', 0.03, 'power_delay_steps', 0),
    struct('name', 'Partial shade surrogate',    'stress', 'shade_mismatch', 'cloud', 'mixed',  'day', 170, 'update_period', 12, 'power_noise_frac', 0.04, 'power_delay_steps', 8)
};

fprintf('Порівнюємо: P&O | P&O+Pyr | NN-GT | NN-VI Hybrid\n\n');

results = struct('name', {}, 'update_period', {}, 'power_noise_frac', {}, 'power_delay_steps', {}, ...
                 'eff_po', {}, 'eff_pyr', {}, 'eff_gt', {}, 'eff_hyb', {}, 'winner', {});

for exp_idx = 1:numel(experiments)
    exp_cfg = experiments{exp_idx};
    rng(1000 + exp_idx, 'twister');

    [time_array, irradiance_cloudy, T_panel] = build_profile(exp_cfg, exp_idx);
    num_steps = numel(time_array);

    V_po = zeros(1, num_steps);        P_po = zeros(1, num_steps);
    V_po_pyr = zeros(1, num_steps);    P_po_pyr = zeros(1, num_steps);
    V_nn = zeros(1, num_steps);        P_nn = zeros(1, num_steps);
    V_vi_hybrid = zeros(1, num_steps); P_vi_hybrid = zeros(1, num_steps);
    P_optimal = zeros(1, num_steps);

    V_po(1) = 230;
    V_po_pyr(1) = 230;
    V_vi_hybrid(1) = 230;

    V_po_prev = 230;      P_po_prev = 0;
    V_po_pyr_prev = 230;  P_po_pyr_prev = 0;
    V_hyb_prev = 230;     P_hyb_prev = 0;

    update_counter_po = 0;
    update_counter_pyr = 0;
    dV_po = 2.0;

    for i = 1:num_steps
        G = irradiance_cloudy(i);
        T = T_panel(i);

        [V_opt, P_opt] = calculate_panel_output(G, T);
        P_optimal(i) = P_opt;

        [~, p_at_v_po] = calculate_panel_output(G, T, V_po(i));
        P_po(i) = p_at_v_po;
        p_meas_po = delayed_noisy_power(P_po, i, exp_cfg.power_delay_steps, exp_cfg.power_noise_frac, P_opt);

        if update_counter_po == 0
            v_new = mppt_po(V_po_prev, P_po_prev, V_po(i), p_meas_po, dV_po);
            if i < num_steps
                V_po(i+1) = clamp_voltage(v_new);
            end
            P_po_prev = p_meas_po;
            V_po_prev = V_po(i);
        elseif i < num_steps
            V_po(i+1) = V_po(i);
        end
        update_counter_po = mod(update_counter_po + 1, exp_cfg.update_period);

        [~, p_at_v_po_pyr] = calculate_panel_output(G, T, V_po_pyr(i));
        P_po_pyr(i) = p_at_v_po_pyr;
        p_meas_pyr = delayed_noisy_power(P_po_pyr, i, exp_cfg.power_delay_steps, exp_cfg.power_noise_frac, P_opt);

        if update_counter_pyr == 0
            G_prev = irradiance_cloudy(max(1, i-1));
            v_new_pyr = mppt_po_adaptive( ...
                V_po_pyr_prev, P_po_pyr_prev, V_po_pyr(i), p_meas_pyr, G, G_prev, dV_po);
            if i < num_steps
                V_po_pyr(i+1) = clamp_voltage(v_new_pyr);
            end
            P_po_pyr_prev = p_meas_pyr;
            V_po_pyr_prev = V_po_pyr(i);
        elseif i < num_steps
            V_po_pyr(i+1) = V_po_pyr(i);
        end
        update_counter_pyr = mod(update_counter_pyr + 1, exp_cfg.update_period);

        V_nn(i) = nn_forward(network_gt, [G; T]);
        [~, P_nn(i)] = calculate_panel_output(G, T, V_nn(i));

        [~, p_hyb, i_hyb] = calculate_panel_output(G, T, V_vi_hybrid(i));
        P_vi_hybrid(i) = p_hyb;
        p_meas_hyb = delayed_noisy_power(P_vi_hybrid, i, exp_cfg.power_delay_steps, exp_cfg.power_noise_frac, P_opt);

        if i == 1
            dV_hyb = 0;
            dP_hyb = 0;
            V_vi_hybrid_prev = V_vi_hybrid(i);
        else
            V_vi_hybrid_prev = V_vi_hybrid(i-1);
            dV_hyb = V_vi_hybrid(i) - V_vi_hybrid(i-1);
            dP_hyb = p_meas_hyb - P_hyb_prev;
        end

        dv_nn = nn_forward_vi(network_vi, [V_vi_hybrid(i); V_vi_hybrid_prev; i_hyb; p_meas_hyb; dV_hyb; dP_hyb]);
        V_po_like = mppt_po(V_hyb_prev, P_hyb_prev, V_vi_hybrid(i), p_meas_hyb, 1.5);
        dv_po_like = V_po_like - V_vi_hybrid(i);

        if i == 1
            dv_hyb = 0.6 * dv_nn;
        elseif dP_hyb < -1.0
            dv_hyb = dv_po_like;
        elseif sign(dv_nn) ~= sign(dv_po_like) && abs(dP_hyb) > 2.0
            dv_hyb = 0.75 * dv_po_like + 0.25 * dv_nn;
        else
            dv_hyb = 0.55 * dv_nn + 0.45 * dv_po_like;
        end

        if abs(dP_hyb) < 0.5
            dv_hyb = 0.5 * dv_hyb;
        end

        if i < num_steps
            V_vi_hybrid(i+1) = clamp_voltage(V_vi_hybrid(i) + max(-action_limit, min(action_limit, dv_hyb)));
        end
        V_hyb_prev = V_vi_hybrid(i);
        P_hyb_prev = p_meas_hyb;
    end

    eff_po = 100 * sum(P_po) / sum(P_optimal);
    eff_pyr = 100 * sum(P_po_pyr) / sum(P_optimal);
    eff_gt = 100 * sum(P_nn) / sum(P_optimal);
    eff_hyb = 100 * sum(P_vi_hybrid) / sum(P_optimal);

    fprintf('%s\n', exp_cfg.name);
    fprintf('  update_period = %d, power_noise = %.1f%% of Popt, power_delay = %d steps\n', ...
            exp_cfg.update_period, 100 * exp_cfg.power_noise_frac, exp_cfg.power_delay_steps);
    fprintf('  P&O       : %.3f%%\n', eff_po);
    fprintf('  P&O+Pyr   : %.3f%%\n', eff_pyr);
    fprintf('  NN-GT     : %.3f%%\n', eff_gt);
    fprintf('  NN-VI Hyb : %.3f%%\n', eff_hyb);

    best_eff = max([eff_po, eff_pyr, eff_gt, eff_hyb]);
    if best_eff == eff_gt
        winner = 'NN-GT';
        fprintf('  -> Перемагає NN-GT\n\n');
    elseif best_eff == eff_hyb
        winner = 'NN-VI Hybrid';
        fprintf('  -> Перемагає NN-VI Hybrid\n\n');
    elseif best_eff == eff_pyr
        winner = 'P&O+Pyr';
        fprintf('  -> Перемагає P&O+Pyr\n\n');
    else
        winner = 'P&O';
        fprintf('  -> Перемагає P&O\n\n');
    end

    results(exp_idx).name = exp_cfg.name;
    results(exp_idx).update_period = exp_cfg.update_period;
    results(exp_idx).power_noise_frac = exp_cfg.power_noise_frac;
    results(exp_idx).power_delay_steps = exp_cfg.power_delay_steps;
    results(exp_idx).eff_po = eff_po;
    results(exp_idx).eff_pyr = eff_pyr;
    results(exp_idx).eff_gt = eff_gt;
    results(exp_idx).eff_hyb = eff_hyb;
    results(exp_idx).winner = winner;
end

report_path = fullfile(project_dir, 'analysis', 'nn_advantage_report.txt');
fid = fopen(report_path, 'w');
if fid ~= -1
    fprintf(fid, 'ЗВІТ: ЕКСПЕРИМЕНТИ ДЛЯ ПОШУКУ ПЕРЕВАГИ NN MPPT\n');
    fprintf(fid, '===========================================\n\n');
    fprintf(fid, 'Примітка: сценарій Partial shade surrogate є наближенням часткового затінення в межах одномаксимумної моделі масиву.\n');
    fprintf(fid, 'Мета: перевірити режими, де класичні алгоритми втрачають через рідкі оновлення, шум та затримку в каналі потужності.\n\n');

    for exp_idx = 1:numel(results)
        r = results(exp_idx);
        fprintf(fid, '%s\n', r.name);
        fprintf(fid, '  update_period=%d, power_noise=%.1f%%, power_delay=%d steps\n', ...
                r.update_period, 100 * r.power_noise_frac, r.power_delay_steps);
        fprintf(fid, '  P&O=%.3f%% | P&O+Pyr=%.3f%% | NN-GT=%.3f%% | NN-VI Hybrid=%.3f%%\n', ...
                r.eff_po, r.eff_pyr, r.eff_gt, r.eff_hyb);
        fprintf(fid, '  Winner: %s\n\n', r.winner);
    end

    fclose(fid);
    fprintf('✓ Звіт збережено: %s\n', report_path);
else
    warning('Не вдалося зберегти звіт: %s', report_path);
end

function [time_array, irradiance_cloudy, T_panel] = build_profile(exp_cfg, seed_idx)
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
        irradiance_clear(i) = get_solar_irradiance(exp_cfg.day, hour, minute);
    end

    irradiance_cloudy = apply_cloud_variation(irradiance_clear, exp_cfg.cloud, time_array);

    switch exp_cfg.stress
        case 'storm_front'
            t_norm = time_array / max(time_array);
            front = 1 - 0.35 ./ (1 + exp(-(t_norm - 0.45) * 35));
            dips = ones(size(time_array));
            rng(400 + seed_idx, 'twister');
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
        case 'shade_mismatch'
            % Surrogate часткового затінення: дві неузгоджені підгрупи з глибокими провалами.
            rng(700 + seed_idx, 'twister');
            g_a = irradiance_cloudy .* (0.88 + 0.10 * sin(2 * pi * time_array / 180));
            g_b = irradiance_cloudy .* (0.60 + 0.30 * sign(sin(2 * pi * time_array / 55)));

            dips = ones(size(time_array));
            for k = 1:12
                c = randi([900, num_steps-900]);
                w = randi([40, 140]);
                a = 0.25 + 0.45 * rand();
                idx = max(1, c-w):min(num_steps, c+w);
                shape = 1 - a * exp(-((idx-c) / (0.35*w)).^2);
                dips(idx) = dips(idx) .* shape;
            end
            g_b = g_b .* dips;

            % Еквівалентний G для поточної моделі PV (без явної multi-peak кривої).
            irradiance_cloudy = 0.58 * g_a + 0.42 * g_b;
    end

    irradiance_cloudy = max(0, min(1000, irradiance_cloudy));

    T_ambient_min = 15;
    T_ambient_max = 35;
    T_ambient = T_ambient_min + (T_ambient_max - T_ambient_min) * 0.5 * ...
                (1 + cos(2*pi*(time_array/(12*3600)-0.5)));
    T_panel = T_ambient + 20 * (irradiance_cloudy / 1000).^1.2;
    T_panel = max(15, min(60, T_panel));
end

function p_meas = noisy_power(p_true, p_opt, noise_frac)
    if noise_frac <= 0
        p_meas = p_true;
        return;
    end

    sigma = noise_frac * max(100, p_opt);
    p_meas = p_true + sigma * randn();
end

function p_meas = delayed_noisy_power(p_series, idx, delay_steps, noise_frac, p_opt)
    delayed_idx = max(1, idx - delay_steps);
    p_base = p_series(delayed_idx);
    p_meas = noisy_power(p_base, p_opt, noise_frac);
end

function v = clamp_voltage(v)
    v = max(30, min(320, v));
end