function solar_sim4_u()
    % Очищення
    close all;
    clc;

    % =========================================================================
    % СТВОРЕННЯ ГОЛОВНОГО ВІКНА ПРОГРАМИ
    % =========================================================================
        figure('Name', 'MPPT Simulator v3.2 - Hard Physics', 'Units', 'normalized', ...
            'Position', [0.05, 0.05, 0.9, 0.85], 'Color', [0.95 0.95 0.95]);

    % --- РЯДОК 1 (Параметри Довкілля) ---
    uicontrol('Style', 'text', 'Units', 'normalized', 'Position', [0.03, 0.12, 0.05, 0.03], ...
              'String', 'Широта:', 'HorizontalAlignment', 'left', 'BackgroundColor', [0.95 0.95 0.95]);
    h_lat = uicontrol('Style', 'edit', 'Units', 'normalized', 'Position', [0.08, 0.12, 0.04, 0.04], 'String', '49.83');

    uicontrol('Style', 'text', 'Units', 'normalized', 'Position', [0.14, 0.12, 0.07, 0.03], ...
              'String', 'День року:', 'HorizontalAlignment', 'left', 'BackgroundColor', [0.95 0.95 0.95]);
    h_day = uicontrol('Style', 'edit', 'Units', 'normalized', 'Position', [0.21, 0.12, 0.04, 0.04], 'String', '172');

    uicontrol('Style', 'text', 'Units', 'normalized', 'Position', [0.27, 0.12, 0.07, 0.03], ...
              'String', 'Кут нахилу:', 'HorizontalAlignment', 'left', 'BackgroundColor', [0.95 0.95 0.95]);
    h_tilt = uicontrol('Style', 'edit', 'Units', 'normalized', 'Position', [0.34, 0.12, 0.04, 0.04], 'String', '35');

    uicontrol('Style', 'text', 'Units', 'normalized', 'Position', [0.40, 0.12, 0.08, 0.03], ...
              'String', 'Хмарність (%):', 'HorizontalAlignment', 'left', 'BackgroundColor', [0.95 0.95 0.95], 'FontWeight', 'bold');
    h_clouds = uicontrol('Style', 'edit', 'Units', 'normalized', 'Position', [0.48, 0.12, 0.04, 0.04], 'String', '40');

    % --- РЯДОК 2 (Параметри Обладнання та Аналізу) ---
    uicontrol('Style', 'text', 'Units', 'normalized', 'Position', [0.03, 0.06, 0.07, 0.03], ...
              'String', 'Панелей (шт):', 'HorizontalAlignment', 'left', 'BackgroundColor', [0.95 0.95 0.95]);
    h_panels = uicontrol('Style', 'edit', 'Units', 'normalized', 'Position', [0.10, 0.06, 0.04, 0.04], 'String', '22');

    uicontrol('Style', 'text', 'Units', 'normalized', 'Position', [0.16, 0.06, 0.07, 0.03], ...
              'String', 'Інтервал (хв):', 'HorizontalAlignment', 'left', 'BackgroundColor', [0.95 0.95 0.95]);
    h_interval = uicontrol('Style', 'edit', 'Units', 'normalized', 'Position', [0.23, 0.06, 0.04, 0.04], 'String', '5');

    uicontrol('Style', 'text', 'Units', 'normalized', 'Position', [0.29, 0.06, 0.07, 0.03], ...
              'String', 'Крок P&O (В):', 'HorizontalAlignment', 'left', 'BackgroundColor', [0.95 0.95 0.95]);
    h_step = uicontrol('Style', 'edit', 'Units', 'normalized', 'Position', [0.36, 0.06, 0.04, 0.04], 'String', '0.5');

    uicontrol('Style', 'text', 'Units', 'normalized', 'Position', [0.41, 0.06, 0.07, 0.03], ...
              'String', 'Час (год):', 'HorizontalAlignment', 'left', 'BackgroundColor', [0.95 0.95 0.95], 'ForegroundColor', [0 0 0.8], 'FontWeight', 'bold');
    h_time = uicontrol('Style', 'edit', 'Units', 'normalized', 'Position', [0.48, 0.06, 0.04, 0.04], 'String', '12.5');

    % --- КНОПКА ---
    uicontrol('Style', 'pushbutton', 'Units', 'normalized', 'Position', [0.55, 0.05, 0.18, 0.10], ...
              'String', '⚡ ОНОВИТИ', 'FontSize', 12, 'FontWeight', 'bold', ...
              'BackgroundColor', [0.2 0.6 0.2], 'ForegroundColor', [1 1 1], 'Callback', @update_sim);

    % Зони для графіків
    ax1 = axes('Units', 'normalized', 'Position', [0.08, 0.60, 0.85, 0.35]);
    ax2 = axes('Units', 'normalized', 'Position', [0.08, 0.22, 0.85, 0.30]);

    % Перший запуск
    update_sim();

    function update_sim(~, ~)
        % Зчитування
        lat = str2double(get(h_lat, 'String')); if isnan(lat), lat = 49.83; end
        dayOfYear = str2double(get(h_day, 'String')); if isnan(dayOfYear), dayOfYear = 172; end
        tilt = str2double(get(h_tilt, 'String')); if isnan(tilt), tilt = 35; end
        cloud_pct = str2double(get(h_clouds, 'String')); if isnan(cloud_pct), cloud_pct = 40; end

        num_panels = str2double(get(h_panels, 'String')); if isnan(num_panels), num_panels = 22; end
        dt_min = str2double(get(h_interval, 'String')); if isnan(dt_min) || dt_min <= 0, dt_min = 5; end
        V_step = str2double(get(h_step, 'String')); if isnan(V_step), V_step = 0.5; end

        obs_time = str2double(get(h_time, 'String'));
        if isnan(obs_time) || obs_time < 0 || obs_time > 24, obs_time = 12.0; end

        lon = 23.96;
        A_total = 1.6 * num_panels;
        V_mpp_nominal = 30;

        % Режим фокус-вікна для дослідження швидких змін освітлення.
        % Можна перевизначити з MATLAB base workspace: USE_FOCUS_WINDOW = false;
        if evalin('base', 'exist(''USE_FOCUS_WINDOW'', ''var'')')
            use_focus_window = logical(evalin('base', 'USE_FOCUS_WINDOW'));
        else
            use_focus_window = false;
        end
        focus_start_h = 10;
        focus_end_h = 14;

        % Сценарій дослідження MPPT (можна перевизначити у base workspace):
        %   MPPT_SCENARIO = 'smooth' | 'mixed' | 'stress'
        if evalin('base', 'exist(''MPPT_SCENARIO'', ''var'')')
            scenario_name = lower(char(evalin('base', 'MPPT_SCENARIO')));
        else
            scenario_name = 'mixed';
        end
        valid_scenarios = {'smooth', 'mixed', 'stress'};
        if ~any(strcmp(scenario_name, valid_scenarios))
            scenario_name = 'mixed';
        end

        if use_focus_window
            t_hours = focus_start_h : (dt_min/60) : focus_end_h;
            obs_time = min(max(obs_time, focus_start_h), focus_end_h);
        else
            t_hours = 0 : (dt_min/60) : 24;
        end
        Tamb = 22 + 8*sin(pi*(t_hours - 8)/12);

        % Фізична модель освітленості ясного неба (ASHRAE DNI+DHI+Reflected).
        % Виклик calc_solar_irradiance: повна 5-членна формула Duffie&Beckman,
        % air mass Kasten-Young, ізотропна модель розсіяного POA Liu&Jordan.
        % Аргументи: t_hours, lat, lon, dayOfYear, tilt, panel_az=180(Південь), albedo=0.20
        G_ideal = calc_solar_irradiance(t_hours, lat, lon, dayOfYear, tilt, 180, 0.20);

        % --- НАЛАШТУВАННЯ КЛАСИЧНОГО P&O ---
        po_cfg = struct( ...
            'V_step',           V_step, ...
            'V_init',           V_mpp_nominal, ...
            'curve_k',          18, ...
            'dP_deadband_w',    0.5, ...
            'updates_per_step', max(1, round(3 / max(dt_min, 0.1))) ...
        );

        % --- АВТОМАТИЧНИЙ ПРОГІН УСІХ СЦЕНАРІЇВ ДЛЯ ПОРІВНЯННЯ ---
        scenario_list = {'smooth', 'mixed', 'stress'};
        scenario_result = cell(1, numel(scenario_list));

        for s_idx = 1:numel(scenario_list)
            s_name = scenario_list{s_idx};
            [G_case, fast_mode_case, fast_info_case, shade_factor_case] = ...
                build_scenario_signal(s_name, t_hours, G_ideal, cloud_pct, focus_start_h, focus_end_h);

            % Фізична модель панелі.
            Tcell_case = Tamb + (G_case / 800) * 25;
            V_mpp_case = V_mpp_nominal - 0.1*(Tcell_case - 25) + ...
                         3.0 * log(max(G_case, 1) / 1000);
            V_mpp_case = max(10, V_mpp_case);
            V_mpp_case(G_case < 5) = 0;

            P_ideal_case = G_case .* A_total .* 0.18 .* (1 - 0.004*(Tcell_case - 25));
            P_ideal_case(G_case < 5) = 0;

            [P_po_case, V_ref_case, po_case] = run_mppt_po(t_hours, P_ideal_case, V_mpp_case, po_cfg);

            % Метрики динаміки: оцінка реакції на швидкі зміни освітленості.
            dG = [0, abs(diff(G_case))];
            rapid_idx = dG > 80; % >80 Вт/м^2 за один відлік
            if any(rapid_idx)
                eff_rapid = mean(po_case.eff_inst_pct(rapid_idx));
            else
                eff_rapid = NaN;
            end

            scenario_result{s_idx} = struct( ...
                'name', s_name, ...
                'fast_mode', fast_mode_case, ...
                'fast_events', fast_info_case.num_events, ...
                'shade_pct', 100*mean(shade_factor_case < 0.995), ...
                'G_POA', G_case, ...
                'Tcell', Tcell_case, ...
                'V_mpp', V_mpp_case, ...
                'P_ideal', P_ideal_case, ...
                'P_po', P_po_case, ...
                'V_ref', V_ref_case, ...
                'po', po_case, ...
                'eff_rapid', eff_rapid ...
            );
        end

        active_idx = find(strcmp(scenario_name, scenario_list), 1, 'first');
        if isempty(active_idx), active_idx = 2; end
        active = scenario_result{active_idx};

        % Активний сценарій використовується для графіків.
        G_POA = active.G_POA;
        V_mpp_dyn_arr = active.V_mpp;
        P_ideal = active.P_ideal;
        P_po = active.P_po;
        V_ref_hist = active.V_ref;
        po_out = active.po;
        fast_mode = active.fast_mode;
        fast_info = struct('num_events', active.fast_events);

        % --- МАЛЮЄМО ГРАФІК 1 ---
        axes(ax1); cla;
        fill([t_hours fliplr(t_hours)], [G_POA zeros(size(G_POA))], [1 0.9 0.7], 'EdgeColor', 'none'); hold on;
        plot(t_hours, G_POA, 'Color', [0.8 0.4 0], 'LineWidth', 1.5);
        y_lim1 = ylim; plot([obs_time obs_time], y_lim1, 'b-.', 'LineWidth', 1.5); hold off;
        if use_focus_window
            title(['Освітленість [', upper(active.name), '] (', num2str(focus_start_h), ':00-', num2str(focus_end_h), ...
                  ':00, Хмарність ', num2str(cloud_pct), '%, Fast=', fast_mode, ')']);
        else
            title(['Освітленість [', upper(active.name), '] (Хмарність ', num2str(cloud_pct), '%, Fast=', fast_mode, ')']);
        end
        grid on;
        if use_focus_window
            xlim([focus_start_h focus_end_h]);
        else
            xlim([4 21]);
        end
        ylabel('Вт/м^2');

       % --- МАЛЮЄМО ГРАФІК 2 ---
        axes(ax2); cla;

        % Потужність P&O та ідеальний MPPT.
        plot(t_hours, P_po/1000,    'r',  'LineWidth', 1.5); hold on;
        plot(t_hours, P_ideal/1000, 'k--','LineWidth', 1.0);

        % Зона між ідеальним і реальним — наочно показує втрати трекінгу.
        fill([t_hours fliplr(t_hours)], ...
             [P_ideal/1000 fliplr(P_po/1000)], ...
             [1 0.7 0.7], 'EdgeColor', 'none', 'FaceAlpha', 0.35);

        % Робоча напруга (права вісь) — показує «блукання» P&O навколо Vmpp.
        yyaxis right;
        plot(t_hours, V_ref_hist, 'Color', [0.2 0.5 0.9], 'LineWidth', 0.8, 'LineStyle', ':');
        ylabel('В (V_{ref})');
        yyaxis left;

        max_kw = max(P_ideal/1000);
        if max_kw > 0, ylim([0, max_kw * 1.2]); end

        y_lim2 = ylim; plot([obs_time obs_time], y_lim2, 'b-.', 'LineWidth', 1.5); hold off;
        grid on;
        if use_focus_window
            xlim([focus_start_h focus_end_h]);
        else
            xlim([4 21]);
        end
        ylabel('кВт'); xlabel('Години дня');
        legend(ax2, {'Реальна P&O', 'Ідеальний MPPT', 'Втрати трекінгу', 'V_{ref} P&O', 'Маркер часу'}, ...
               'Location', 'northwest', 'FontSize', 8);

        % --- ДАНІ МАРКЕРА ТА ВИВІД ---
        [~, idx] = min(abs(t_hours - obs_time));
        actual_obs_time = t_hours(idx);

        clc;
        fprintf('--- ЗАГАЛЬНІ РЕЗУЛЬТАТИ СИМУЛЯЦІЇ ---\n');
        fprintf('Хмарність: %g%%, Швидкі хмари: %s (%d подій)\n', ...
                cloud_pct, fast_mode, fast_info.num_events);
        fprintf('Активний сценарій: %s\n', upper(active.name));
        fprintf('Крок часу: %.2f хв, P&O ітерацій/крок: %d\n', ...
                dt_min, po_cfg.updates_per_step);
        fprintf('\n');
        fprintf('Ідеальний MPPT:       %.2f кВт*год\n', po_out.E_ideal_kWh);
        fprintf('Реальний P&O:         %.2f кВт*год\n', po_out.E_track_kWh);
        fprintf('Ефективність:         %.1f%%\n',       po_out.eff_energy_pct);
        fprintf('Втрати трекінгу:      %.1f%%\n',       100 - po_out.eff_energy_pct);
        fprintf('\n');
        fprintf('--- ТОЧКОВИЙ АНАЛІЗ (t = %.2f год) ---\n', actual_obs_time);
        fprintf('Освітленість:         %.1f Вт/м^2\n',  G_POA(idx));
        fprintf('Істинна V_mpp:        %.1f В\n',       V_mpp_dyn_arr(idx));
        fprintf('Робоча напруга V_ref: %.1f В\n',       V_ref_hist(idx));
        fprintf('Відхилення від Vmpp:  %.1f В  (%.1f%%)\n', ...
                V_ref_hist(idx) - V_mpp_dyn_arr(idx), ...
                100*(V_ref_hist(idx) - V_mpp_dyn_arr(idx)) / max(V_mpp_dyn_arr(idx), 1));
        fprintf('Миттєва ефективність: %.1f%%\n',       po_out.eff_inst_pct(idx));
        fprintf('Потужність P&O:       %.2f кВт\n',     P_po(idx)/1000);
        fprintf('\n');
        fprintf('--- ПОРІВНЯННЯ СЦЕНАРІЇВ (P&O) ---\n');
        fprintf('Сценарій | Fast | Подій | Частк. затінення | E_ideal кВт*год | E_PO кВт*год | Eff %% | Eff rapid %%\n');
        for s_idx = 1:numel(scenario_result)
            rs = scenario_result{s_idx};
            if isnan(rs.eff_rapid)
                rapid_txt = 'n/a';
            else
                rapid_txt = sprintf('%.1f', rs.eff_rapid);
            end
            fprintf('%-8s | %-6s | %5d | %15.1f | %13.2f | %10.2f | %5.1f | %10s\n', ...
                    upper(rs.name), upper(rs.fast_mode), rs.fast_events, rs.shade_pct, ...
                    rs.po.E_ideal_kWh, rs.po.E_track_kWh, rs.po.eff_energy_pct, rapid_txt);
        end
    end

    function [G_case, fast_mode_case, fast_info_case, shade_factor_case] = ...
            build_scenario_signal(s_name, t_h, G_clear, cloud_percent, t0, t1)
        [G_slow_case, ~] = apply_cloud_model(t_h, G_clear, cloud_percent, 42);

        switch lower(s_name)
            case 'smooth'
                fast_mode_case = 'off';
                [G_fast_case, fast_info_case] = apply_fast_cloud_events(t_h, G_slow_case, fast_mode_case, 77, [t0 t1]);
                shade_factor_case = ones(size(t_h));
                G_case = G_fast_case;

            case 'mixed'
                fast_mode_case = 'mild';
                [G_fast_case, fast_info_case] = apply_fast_cloud_events(t_h, G_slow_case, fast_mode_case, 77, [t0 t1]);
                shade_factor_case = ones(size(t_h));
                G_case = G_fast_case;

            case 'stress'
                fast_mode_case = 'strong';
                [G_fast_case, fast_info_case] = apply_fast_cloud_events(t_h, G_slow_case, fast_mode_case, 77, [t0 t1]);
                shade_factor_case = build_partial_shading_factor(t_h, 2026);
                G_case = G_fast_case .* shade_factor_case;

            otherwise
                fast_mode_case = 'mild';
                [G_fast_case, fast_info_case] = apply_fast_cloud_events(t_h, G_slow_case, fast_mode_case, 77, [t0 t1]);
                shade_factor_case = ones(size(t_h));
                G_case = G_fast_case;
        end
    end

    function shade_factor = build_partial_shading_factor(t_h, seed)
        % Імітація часткового затінення (локальні провали 10-45%).
        rng(seed, 'twister');
        shade_factor = ones(size(t_h));

        n_events = max(2, round((max(t_h) - min(t_h)) * 1.2));
        for e = 1:n_events
            c = min(t_h) + (max(t_h) - min(t_h)) * rand();
            depth = 0.10 + 0.35 * rand();
            width_h = (5 + 15*rand()) / 60; % 5..20 хв
            sigma = max(width_h / 2.355, 1e-3);
            profile = exp(-0.5 * ((t_h - c) / sigma).^2);
            shade_factor = shade_factor .* (1 - depth * profile);
        end

        shade_factor = min(1.0, max(0.45, shade_factor));
    end
end
