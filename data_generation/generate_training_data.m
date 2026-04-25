% Генерація синтетичних даних для тренування нейронної мережи MPPT
% Розраховує оптимальну напругу для різних комбінацій освітленості та температури

function [training_data, validation_data] = generate_training_data(num_points)
    % Входи:
    %   num_points - кількість синтетичних точок для генерації (за замовчуванням 150)
    %
    % Виходи:
    %   training_data - структура з полями .G, .T, .V (80% даних)
    %   validation_data - структура з полями .G, .T, .V (20% даних)
    
    if nargin < 1
        num_points = 150;  % Стандартна кількість
    end

    this_dir = fileparts(mfilename('fullpath'));
    project_dir = fileparts(this_dir);
    addpath(fullfile(project_dir, 'solar_model'));
    
    fprintf('Генерація синтетичних даних для тренування...\n');
    fprintf('Кількість точок: %d\n', num_points);
    
    % Діапазони освітленості та температури — узгоджено з nn_init.m
    G_min = 50;      % Мінімальна освітленість [W/m²]
    G_max = 1100;    % Максимальна (нахилена панель влітку дає 1100+)
    T_min = 5;       % Мінімальна температура клітини [°C]
    T_max = 65;      % Максимальна температура клітини [°C]
    
    % Генеруємо комбінації (G, T) на сітці + невеликий шум
    G_values = linspace(G_min, G_max, ceil(sqrt(num_points)));
    T_values = linspace(T_min, T_max, ceil(sqrt(num_points)));
    
    [G_grid, T_grid] = meshgrid(G_values, T_values);
    G_points = G_grid(:);
    T_points = T_grid(:);
    
    % Зберігаємо перший N точок
    G_points = G_points(1:num_points);
    T_points = T_points(1:num_points);
    
    % Додаємо невелику випадковість для різноманітності
    rng(42);  % Детермінований seed
    G_points = G_points + 20 * randn(num_points, 1);
    T_points = T_points + 5 * randn(num_points, 1);
    
    % Обмежуємо діапазони
    G_points = max(G_min, min(G_max, G_points));
    T_points = max(T_min, min(T_max, T_points));
    
    % Ініціалізуємо масиви для збереження результатів
    V_optimal = zeros(num_points, 1);
    P_optimal = zeros(num_points, 1);
    
    % Для кожної комбінації (G, T) розраховуємо оптимальну напругу
    fprintf('Розрахунок оптимальних напруг...\n');
    fprintf('Прогрес: ');
    
    for i = 1:num_points
        G = G_points(i);
        T = T_points(i);
        
        % Розраховуємо оптимальну напругу та потужність
        [V_opt, P_opt, ~] = calculate_panel_output(G, T);
        
        V_optimal(i) = V_opt;
        P_optimal(i) = P_opt;
        
        % Вивід прогресу
        if mod(i, max(1, floor(num_points / 10))) == 0
            fprintf('%d%% ', round(100 * i / num_points));
        end
    end
    fprintf('\n');
    
    % Розділяємо дані на тренування та валідацію (80/20)
    shuffle_indices = randperm(num_points);
    num_train = round(0.8 * num_points);
    
    train_indices = shuffle_indices(1:num_train);
    val_indices = shuffle_indices((num_train+1):end);
    
    % Структури для тренування
    training_data.G = G_points(train_indices)';
    training_data.T = T_points(train_indices)';
    training_data.V = V_optimal(train_indices)';
    training_data.P = P_optimal(train_indices)';
    
    validation_data.G = G_points(val_indices)';
    validation_data.T = T_points(val_indices)';
    validation_data.V = V_optimal(val_indices)';
    validation_data.P = P_optimal(val_indices)';
    
    % Статистика даних
    fprintf('\n✓ Дані згенеровані\n');
    fprintf('Статистика тренувальних даних:\n');
    fprintf('  Освітленість: %.1f - %.1f W/m² (середня: %.1f)\n', ...
        min(training_data.G), max(training_data.G), mean(training_data.G));
    fprintf('  Температура: %.1f - %.1f °C (середня: %.1f)\n', ...
        min(training_data.T), max(training_data.T), mean(training_data.T));
    fprintf('  Оптимальна напруга: %.1f - %.1f V (середня: %.1f)\n', ...
        min(training_data.V), max(training_data.V), mean(training_data.V));
    fprintf('  Потужність: %.1f - %.1f W (середня: %.1f)\n', ...
        min(training_data.P), max(training_data.P), mean(training_data.P));
    
    fprintf('\nСтатистика валідаційних даних:\n');
    fprintf('  Кількість прикладів: %d (тренування: %d, валідація: %d)\n', ...
        num_points, length(train_indices), length(val_indices));
    
    % Зберігаємо дані у файл для подальшого використання
    save(fullfile(this_dir, 'training_data.mat'), 'training_data', 'validation_data');
    fprintf('\n✓ Дані збережені в data_generation/training_data.mat\n');
    
    % Візуалізація розподілу даних
    % Перемикаємо тулкіт на gnuplot — fltk на Windows падає з err 87 (LoadLibrary)
    % при scatter3/складних графіках. Дані ВЖЕ збережено вище —
    % якщо рендер усе одно впаде, дані не загубляться.
    if exist('use_safe_toolkit', 'file'), use_safe_toolkit(); end
    try
        figure('Name', 'Розподіл тренувальних даних', 'NumberTitle', 'off');

        % Графік 1: Освітленість vs Температура
        subplot(2, 2, 1);
        scatter(training_data.G, training_data.T, 50, training_data.V, 'filled');
        colorbar;
        xlabel('Освітленість [W/m²]');
        ylabel('Температура [°C]');
        title('Розподіл даних (колір - оптимальна напруга)');
        grid on;

        % Графік 2: Оптимальна напруга
        subplot(2, 2, 2);
        plot(training_data.G, training_data.V, 'o', 'MarkerSize', 4);
        xlabel('Освітленість [W/m²]');
        ylabel('Оптимальна напруга [V]');
        title('Оптимальна напруга vs Освітленість');
        grid on;

        % Графік 3: Потужність — 2D scatter з кольоровим кодуванням замість 3D
        % (3D scatter в gnuplot теж працює, але 2D надійніше і інформативно)
        subplot(2, 2, 3);
        scatter(training_data.G, training_data.T, 50, training_data.P, 'filled');
        colorbar;
        xlabel('Освітленість [W/m²]');
        ylabel('Температура [°C]');
        title('Потужність [W] (колір)');
        grid on;

        % Графік 4: Гістограма оптимальних напруг
        subplot(2, 2, 4);
        hist(training_data.V, 20);
        xlabel('Оптимальна напруга [V]');
        ylabel('Частота');
        title('Розподіл оптимальних напруг');
        grid on;
    catch err
        warning('generate_training_data:plot_failed', ...
                'Графік не вдалося побудувати (%s). Дані збережено у training_data.mat — наступним кроком запустіть run_full_simulation.', ...
                err.message);
    end

end
