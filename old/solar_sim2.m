function solar_sim2()
    % Очищення пам'яті та консолі перед новим запуском
    close all; 
    clc;

    % =========================================================================
    % СТВОРЕННЯ ГОЛОВНОГО ВІКНА ПРОГРАМИ (Графічний інтерфейс)
    % =========================================================================
    f = figure('Name', 'MPPT Simulator v2.6 - Dynamic Clouds', 'Position', [150, 100, 1000, 700], 'Color', [0.95 0.95 0.95]);

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
    h_clouds = uicontrol('Style', 'edit', 'Units', 'normalized', 'Position', [0.48, 0.12, 0.04, 0.04], 'String', '30');

    % --- РЯДОК 2 (Параметри Обладнання) ---
    uicontrol('Style', 'text', 'Units', 'normalized', 'Position', [0.03, 0.06, 0.07, 0.03], ...
              'String', 'Панелей (шт):', 'HorizontalAlignment', 'left', 'BackgroundColor', [0.95 0.95 0.95]);
    h_panels = uicontrol('Style', 'edit', 'Units', 'normalized', 'Position', [0.10, 0.06, 0.04, 0.04], 'String', '22');

    uicontrol('Style', 'text', 'Units', 'normalized', 'Position', [0.16, 0.06, 0.07, 0.03], ...
              'String', 'Інтервал (хв):', 'HorizontalAlignment', 'left', 'BackgroundColor', [0.95 0.95 0.95]);
    h_interval = uicontrol('Style', 'edit', 'Units', 'normalized', 'Position', [0.23, 0.06, 0.04, 0.04], 'String', '5');

    uicontrol('Style', 'text', 'Units', 'normalized', 'Position', [0.29, 0.06, 0.07, 0.03], ...
              'String', 'Крок P&O (В):', 'HorizontalAlignment', 'left', 'BackgroundColor', [0.95 0.95 0.95]);
    h_step = uicontrol('Style', 'edit', 'Units', 'normalized', 'Position', [0.36, 0.06, 0.04, 0.04], 'String', '0.5');

    % --- КНОПКА ---
    uicontrol('Style', 'pushbutton', 'Units', 'normalized', 'Position', [0.55, 0.05, 0.18, 0.10], ...
              'String', '⚡ ОНОВИТИ', 'FontSize', 12, 'FontWeight', 'bold', ...
              'BackgroundColor', [0.2 0.6 0.2], 'ForegroundColor', [1 1 1], 'Callback', @update_sim);

    % Зони для побудови графіків
    ax1 = axes('Units', 'normalized', 'Position', [0.08, 0.60, 0.85, 0.35]);
    ax2 = axes('Units', 'normalized', 'Position', [0.08, 0.22, 0.85, 0.30]);

    update_sim();

    % =========================================================================
    % ГОЛОВНА ФУНКЦІЯ РОЗРАХУНКУ (Викликається при натисканні кнопки)
    % =========================================================================
    function update_sim(~, ~)
        % --- 1. Зчитування введених користувачем значень ---
        lat = str2double(get(h_lat, 'String'));
        dayOfYear = str2double(get(h_day, 'String'));
        tilt = str2double(get(h_tilt, 'String'));
        cloud_pct = str2double(get(h_clouds, 'String')); 
        
        num_panels = str2double(get(h_panels, 'String'));
        dt_min = str2double(get(h_interval, 'String'));
        V_step = str2double(get(h_step, 'String'));
        
        % Базові константи системи
        lon = 23.96; % Довгота (регіон Львівщини)
        A_total = 1.6 * num_panels; % Загальна площа всіх панелей
        V_mpp_nominal = 30; PO_speed = 5; 
        
        % Генерація часової шкали (вісь X) із заданим кроком дискретизації
        t_hours = 0 : (dt_min/60) : 24;
        
        % --- 2. АСТРОНОМІЧНА МАТЕМАТИКА СОНЦЯ ---
        I_sc = 1367; deg2rad = pi/180; % Сонячна стала (Вт/м2) за межами атмосфери
        
        % Ексцентриситет орбіти Землі (враховує овальність орбіти)
        E0 = 1 + 0.033*cos(2*pi*dayOfYear/365);
        I0n = I_sc * E0;
        
        % Рівняння часу (корекція сонячного полудня)
        B = 2*pi*(dayOfYear - 81)/364;
        EoT_min = 9.87*sin(2*B) - 7.53*cos(B) - 1.5*sin(B);
        solar_hours = (t_hours*60 + lon*4 + EoT_min)/60;
        H = deg2rad * (15*(solar_hours - 12)); % Годинний кут
        
        % Кут схилення Сонця (зміна висоти Сонця залежно від пори року)
        delta = deg2rad * (23.45*sin(deg2rad*(360*(284 + dayOfYear)/365)));
        
        % Розрахунок кута падіння променів на похилу площину панелі
        tiltr = tilt*deg2rad; latr = lat*deg2rad;
        cosInc = sin(delta)*sin(latr)*cos(tiltr) - ...
                 sin(delta)*cos(latr)*sin(tiltr) + ...
                 cos(delta)*cos(latr)*cos(tiltr).*cos(H) + ...
                 cos(delta)*sin(latr)*sin(tiltr).*cos(H);
        cosInc = max(0, cosInc); % Відкидаємо від'ємні значення (коли сонце позаду панелі)
        
        % Розрахунок зенітного кута (товщина атмосфери, яку пробиває промінь)
        z = sin(latr)*sin(delta) + cos(latr)*cos(delta).*cos(H);
        mu = max(0, z);
        
        % Ідеальна інсоляція на поверхню (без хмар)
        G_ideal = 1100 * mu .* (cosInc ./ (mu + 0.001)); 
        G_ideal(mu == 0) = 0; % Вночі інсоляція дорівнює нулю

        % --- 3. ГЕНЕРАТОР ХМАРНОСТІ ---
        cloud_prob = cloud_pct / 100; % Імовірність появи хмари
        rand('seed', 42); % Фіксація генератора для стабільних графіків при тестуванні
        cloud_factor = ones(size(t_hours));
        
        for i = 1:length(t_hours)
            if t_hours(i) >= 8 && t_hours(i) <= 18 && rand() < cloud_prob
                % Якщо випала хмара, вона випадково зрізає від 0% до 80% освітленості
                cloud_factor(i) = 0.2 + 0.8 * rand();
            end
        end
        G_POA = G_ideal .* cloud_factor; % Реальна освітленість з урахуванням хмар

        % --- 4. СИМУЛЯЦІЯ АЛГОРИТМУ MPPT (Perturb and Observe) ---
        P_ideal = G_POA .* A_total * 0.18; % Теоретичний максимум потужності системи (ККД 18%)
        P_po = zeros(size(t_hours));       % Масив для запису реальної роботи контролера
        V_curr = 15; P_prev = 0; V_prev = 14.5; % Початкові умови алгоритму зранку
        
        for i = 1:length(t_hours)
            if G_POA(i) < 5, continue; end % Якщо дуже темно - мікроконтролер спить
            
            for s = 1:PO_speed % Внутрішній цикл: частота роботи мікроконтролера
                % Фізична модель панелі: потужність падає при відхиленні напруги від ідеальної
                P_act = P_ideal(i) * (1 - ((V_curr - V_mpp_nominal)/V_mpp_nominal)^2);
                
                % Головна логіка P&O: порівнюємо поточну потужність із попереднім кроком
                if (P_act - P_prev) > 0
                    % Потужність зросла -> продовжуємо рух в тому ж напрямку
                    V_next = V_curr + sign(V_curr - V_prev)*V_step;
                else
                    % Потужність впала -> розвертаємо крок (змінюємо знак збурення)
                    V_next = V_curr - sign(V_curr - V_prev)*V_step;
                end
                
                % Зберігаємо дані для наступної ітерації
                V_prev = V_curr; V_curr = V_next; P_prev = P_act;
            end
            P_po(i) = P_act; % Записуємо результат контролера для поточного часу
        end

        % --- 5. ПОБУДОВА ГРАФІКІВ ---
        % Графік 1: Погода (Вхідні дані)
        axes(ax1); cla;
        fill([t_hours fliplr(t_hours)], [G_POA zeros(size(G_POA))], [1 0.9 0.7], 'EdgeColor', 'none'); hold on;
        plot(t_hours, G_POA, 'Color', [0.8 0.4 0], 'LineWidth', 1.5); hold off;
        title(['Освітленість (День ', num2str(dayOfYear), ', Нахил ', num2str(tilt), '°, Хмарність ', num2str(cloud_pct), '%)']);
        grid on; xlim([4 21]); ylabel('Вт/м^2');

        % Графік 2: Порівняння потужності
        axes(ax2); cla;
        plot(t_hours, P_ideal/1000, 'k--', 'LineWidth', 1); hold on;
        plot(t_hours, P_po/1000, 'r', 'LineWidth', 1.5); hold off;
        grid on; xlim([4 21]); 
        
        % Автоматичне масштабування осі Y (на 20% вище за максимальний пік)
        max_kw = max(P_ideal/1000);
        if max_kw > 0
            ylim([0, max_kw * 1.2]);
        end
        
        ylabel('кВт'); xlabel('Години дня');
        legend(ax2, {'Теоретичний максимум', 'Алгоритм P&O'}, 'Location', 'northwest');
        
        % --- 6. РОЗРАХУНОК ЕНЕРГІЇ ТА ВИВІД РЕЗУЛЬТАТІВ ---
        % Інтегрування потужності за часом для отримання кВт*год
        E_ideal = sum(P_ideal)*(dt_min/60)/1000;
        E_po = sum(P_po)*(dt_min/60)/1000;
        eff = (E_po / E_ideal) * 100; % Розрахунок ефективності алгоритму
        
        clc; 
        fprintf('--- СИМУЛЯЦІЯ ЗАВЕРШЕНА ---\n');
        fprintf('Хмарність: %g%%\n', cloud_pct);
        fprintf('Теоретично можливо: %.2f кВт*год\n', E_ideal);
        fprintf('Зібрано алгоритмом: %.2f кВт*год\n', E_po);
        fprintf('Ефективність P&O: %.1f%%\n', eff);
    end
end