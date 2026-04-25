function solar_sim4()
    % Очищення
    close all;
    clc;

    % =========================================================================
    % СТВОРЕННЯ ГОЛОВНОГО ВІКНА ПРОГРАМИ
    % =========================================================================
    f = figure('Name', 'MPPT Simulator v3.2 - Hard Physics', 'Units', 'normalized', ...
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
        PO_speed = 3;

        t_hours = 0 : (dt_min/60) : 24;
        Tamb = 22 + 8*sin(pi*(t_hours - 8)/12);

        % Математика сонця
        I_sc = 1367; deg2rad = pi/180;
        E0 = 1 + 0.033*cos(2*pi*dayOfYear/365);
        B = 2*pi*(dayOfYear - 81)/364;
        EoT_min = 9.87*sin(2*B) - 7.53*cos(B) - 1.5*sin(B);
        solar_hours = (t_hours*60 + lon*4 + EoT_min)/60;
        H = deg2rad * (15*(solar_hours - 12));
        delta = deg2rad * (23.45*sin(deg2rad*(360*(284 + dayOfYear)/365)));

        tiltr = tilt*deg2rad; latr = lat*deg2rad;
        cosInc = sin(delta)*sin(latr)*cos(tiltr) - ...
                 sin(delta)*cos(latr)*sin(tiltr) + ...
                 cos(delta)*cos(latr)*cos(tiltr).*cos(H) + ...
                 cos(delta)*sin(latr)*sin(tiltr).*cos(H);
        cosInc = max(0, cosInc);

        z = sin(latr)*sin(delta) + cos(latr)*cos(delta).*cos(H);
        mu = max(0, z);
        G_ideal = 1100 * mu .* (cosInc ./ (mu + 0.001));
        G_ideal(mu == 0) = 0;

        % ЖОРСТКІШІ ХМАРИ (глибші провали)
        cloud_prob = cloud_pct / 100;
        rand('seed', 42);
        cloud_factor = ones(size(t_hours));
        for i = 1:length(t_hours)
            if t_hours(i) >= 8 && t_hours(i) <= 18 && rand() < cloud_prob
                cloud_factor(i) = 0.10 + 0.50 * rand();
            end
        end
        G_POA = G_ideal .* cloud_factor;

        % --- ФІЗИКА НАПІВПРОВІДНИКА ТА АЛГОРИТМ ---
        P_ideal = zeros(size(t_hours));
        P_po = zeros(size(t_hours));
        Tcell_arr = zeros(size(t_hours));

        V_curr = V_mpp_nominal;
        P_prev = 0; V_prev = V_curr - 0.1;

        for i = 1:length(t_hours)
            if G_POA(i) < 5
                continue;
            end

            Tcell = Tamb(i) + (G_POA(i)/800) * 25;
            Tcell_arr(i) = Tcell;

            % Сильніший зсув напруги при хмарах
            V_mpp_dyn = V_mpp_nominal - 0.1*(Tcell - 25) + 3.0*log(max(G_POA(i), 1)/1000);
            if V_mpp_dyn < 10, V_mpp_dyn = 10; end

            P_ideal(i) = G_POA(i) * A_total * 0.18 * (1 - 0.004*(Tcell - 25));

            P_sum = 0;
            for s = 1:PO_speed
                % НОВА МОДЕЛЬ: Експоненційний штраф за помилку напруги (Діодна крива)
                mismatch = (V_curr - V_mpp_dyn) / V_mpp_dyn;
                if mismatch > 0
                    % Якщо напруга зависока -> різкий обрив струму
                    penalty = exp(-40 * mismatch^2);
                else
                    % Якщо занизька -> струм є, але потужність втрачається похило
                    penalty = exp(-15 * mismatch^2);
                end

                P_act = P_ideal(i) * penalty;
                if P_act < 0, P_act = 0; end

                P_sum = P_sum + P_act;

                % Логіка P&O з імітацією "дезорієнтації"
                dP = P_act - P_prev;
                dV = V_curr - V_prev;

                if dP > 0
                    if dV > 0, V_next = V_curr + V_step;
                    else,      V_next = V_curr - V_step; end
                else
                    if dV > 0, V_next = V_curr - V_step;
                    else,      V_next = V_curr + V_step; end
                end

                V_prev = V_curr; V_curr = V_next; P_prev = P_act;
            end

            P_po(i) = P_sum / PO_speed;
        end

        % --- МАЛЮЄМО ГРАФІК 1 ---
        axes(ax1); cla;
        fill([t_hours fliplr(t_hours)], [G_POA zeros(size(G_POA))], [1 0.9 0.7], 'EdgeColor', 'none'); hold on;
        plot(t_hours, G_POA, 'Color', [0.8 0.4 0], 'LineWidth', 1.5);
        y_lim1 = ylim; plot([obs_time obs_time], y_lim1, 'b-.', 'LineWidth', 1.5); hold off;
        title(['Освітленість (Хмарність ', num2str(cloud_pct), '%)']);
        grid on; xlim([4 21]); ylabel('Вт/м^2');

       % --- МАЛЮЄМО ГРАФІК 2 ---
        axes(ax2); cla;

        % 1. Спочатку малюємо червону (реальність)
        plot(t_hours, P_po/1000, 'r', 'LineWidth', 1.5); hold on;

        % 2. ЗВЕРХУ малюємо чорний пунктир
        plot(t_hours, P_ideal/1000, 'k--', 'LineWidth', 1.0); % <--- Змінили 2.0 на 1.0

        max_kw = max(P_ideal/1000);
        if max_kw > 0, ylim([0, max_kw * 1.2]); end

        y_lim2 = ylim; plot([obs_time obs_time], y_lim2, 'b-.', 'LineWidth', 1.5); hold off;
        grid on; xlim([4 21]); ylabel('кВт'); xlabel('Години дня');
        legend(ax2, {'Реальна робота P&O', 'Теоретичний максимум', 'Маркер часу'}, 'Location', 'northwest');

        % --- ДАНІ МАРКЕРА ТА ВИВІД ---
        [~, idx] = min(abs(t_hours - obs_time));
        actual_obs_time = t_hours(idx);

        E_ideal = sum(P_ideal)*(dt_min/60)/1000;
        E_po = sum(P_po)*(dt_min/60)/1000;
        if E_ideal > 0, eff = (E_po / E_ideal) * 100; else, eff = 0; end

        clc;
        fprintf('--- ЗАГАЛЬНІ РЕЗУЛЬТАТИ СИМУЛЯЦІЇ ---\n');
        fprintf('Хмарність: %g%%\n', cloud_pct);
        fprintf('Теоретично можливо: %.2f кВт*год\n', E_ideal);
        fprintf('Зібрано алгоритмом: %.2f кВт*год\n', E_po);
        fprintf('Ефективність P&O: %.1f%%\n', eff);
        fprintf('Втрати на трекінг: %.1f%%\n\n', 100 - eff);

        fprintf('--- ТОЧКОВИЙ АНАЛІЗ (t = %.2f год) ---\n', actual_obs_time);
        fprintf('Освітленість: %.1f Вт/м^2\n', G_POA(idx));
        fprintf('Ідеальна напруга Vmpp: %.1f В\n', V_mpp_nominal - 0.1*(Tcell_arr(idx) - 25) + 3.0*log(max(G_POA(idx), 1)/1000));
        fprintf('Потужність P&O: %.2f кВт\n', P_po(idx)/1000);
    end
end
