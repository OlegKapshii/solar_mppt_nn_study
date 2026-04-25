% Функція для візуалізації результатів симуляції

function plot_simulation_results(results)

    if exist('use_safe_toolkit', 'file'), use_safe_toolkit(); end

    time_hours = results.time / 3600;  % Переведення в години

    figure('Name', 'Результати симуляції MPPT', 'NumberTitle', 'off', 'Position', [100 100 1200 800]);
    
    % Графік 1: Сонячна радіація
    subplot(3, 3, 1);
    plot(time_hours, results.irradiance_clear, 'b-', 'LineWidth', 1.5);
    hold on;
    plot(time_hours, results.irradiance_cloudy, 'r--', 'LineWidth', 1.5);
    xlabel('Час [год]');
    ylabel('Радіація [W/m²]');
    title('Сонячна радіація');
    legend('Чиста', 'З хмарами');
    grid on;
    
    % Графік 2: Температура панелі
    subplot(3, 3, 2);
    plot(time_hours, results.temperature, 'k-', 'LineWidth', 1.5);
    xlabel('Час [год]');
    ylabel('Температура [°C]');
    title('Температура панелі');
    grid on;
    
    % Графік 3: Напруга
    subplot(3, 3, 3);
    plot(time_hours, results.V_optimal, 'g-', 'LineWidth', 2);
    hold on;
    plot(time_hours, results.V_po, 'b--', 'LineWidth', 1.5, 'DisplayName', 'P&O');
    plot(time_hours, results.V_nn, 'r-.', 'LineWidth', 1.5, 'DisplayName', 'NN-GT');
    if isfield(results, 'V_nn_vi')
        plot(time_hours, results.V_nn_vi, 'm:', 'LineWidth', 2, 'DisplayName', 'NN-VI');
    end
    xlabel('Час [год]');
    ylabel('Напруга [V]');
    title('Напруга панелі');
    if isfield(results, 'V_nn_vi')
        legend('Оптимальна', 'P&O', 'NN-GT', 'NN-VI');
    else
        legend('Оптимальна', 'P&O', 'NN-GT');
    end
    grid on;
    ylim([15 70]);
    
    % Графік 4: Потужність
    subplot(3, 3, 4);
    plot(time_hours, results.P_optimal, 'g-', 'LineWidth', 2);
    hold on;
    plot(time_hours, results.P_po, 'b--', 'LineWidth', 1.5);
    plot(time_hours, results.P_nn, 'r-.', 'LineWidth', 1.5);
    if isfield(results, 'P_nn_vi')
        plot(time_hours, results.P_nn_vi, 'm:', 'LineWidth', 2);
    end
    xlabel('Час [год]');
    ylabel('Потужність [W]');
    title('Потужність панелей');
    if isfield(results, 'P_nn_vi')
        legend('Оптимальна', 'P&O', 'NN-GT', 'NN-VI');
    else
        legend('Оптимальна', 'P&O', 'NN-GT');
    end
    grid on;
    
    % Графік 5: Струм
    subplot(3, 3, 5);
    plot(time_hours, results.I_po, 'b--', 'LineWidth', 1.5);
    hold on;
    plot(time_hours, results.I_nn, 'r-.', 'LineWidth', 1.5);
    if isfield(results, 'I_nn_vi')
        plot(time_hours, results.I_nn_vi, 'm:', 'LineWidth', 2);
    end
    xlabel('Час [год]');
    ylabel('Струм [A]');
    title('Струм панелей');
    if isfield(results, 'I_nn_vi')
        legend('P&O', 'NN-GT', 'NN-VI');
    else
        legend('P&O', 'NN-GT');
    end
    grid on;
    
    % Графік 6: Помилка напруги
    subplot(3, 3, 6);
    error_po = abs(results.V_po - results.V_optimal);
    error_nn = abs(results.V_nn - results.V_optimal);
    plot(time_hours, error_po, 'b--', 'LineWidth', 1.5);
    hold on;
    plot(time_hours, error_nn, 'r-.', 'LineWidth', 1.5);
    if isfield(results, 'V_nn_vi')
        error_nn_vi = abs(results.V_nn_vi - results.V_optimal);
        plot(time_hours, error_nn_vi, 'm:', 'LineWidth', 2);
    end
    xlabel('Час [год]');
    ylabel('Помилка [V]');
    title('Помилка напруги від оптимальної');
    if isfield(results, 'V_nn_vi')
        legend('P&O', 'NN-GT', 'NN-VI');
    else
        legend('P&O', 'NN-GT');
    end
    grid on;
    
    % Графік 7: Кумулятивна енергія
    subplot(3, 3, 7);
    energy_po_cumsum  = cumsum(results.P_po)      * 1 / 3600;  % Wh
    energy_nn_cumsum  = cumsum(results.P_nn)      * 1 / 3600;
    energy_opt_cumsum = cumsum(results.P_optimal) * 1 / 3600;

    plot(time_hours, energy_opt_cumsum, 'g-',  'LineWidth', 2);
    hold on;
    plot(time_hours, energy_po_cumsum,  'b--', 'LineWidth', 1.5);
    plot(time_hours, energy_nn_cumsum,  'r-.', 'LineWidth', 1.5);
    if isfield(results, 'P_nn_vi')
        energy_nn_vi_cumsum = cumsum(results.P_nn_vi) * 1 / 3600;
        plot(time_hours, energy_nn_vi_cumsum, 'm:', 'LineWidth', 2);
    end
    xlabel('Час [год]');
    ylabel('Кумулятивна енергія [Wh]');
    title('Вироблена енергія');
    if isfield(results, 'P_nn_vi')
        legend('Оптимальна', 'P&O', 'NN-GT', 'NN-VI');
    else
        legend('Оптимальна', 'P&O', 'NN-GT');
    end
    grid on;
    
    % Графік 8: Порівняння метрик
    subplot(3, 3, 8);
    metrics = {'Енергія (Wh)', 'Ефективність (%)', 'Помилка V (V)', 'Стабільність (V)'};
    po_values = [results.metrics.energy_po, results.metrics.efficiency_po, ...
                 results.metrics.error_po, std(diff(results.V_po))];
    nn_values = [results.metrics.energy_nn, results.metrics.efficiency_nn, ...
                 results.metrics.error_nn, std(diff(results.V_nn))];

    x     = 1:length(metrics);
    width = 0.25;
    bar(x - width, po_values, width, 'b', 'DisplayName', 'P&O');
    hold on;
    bar(x,         nn_values, width, 'r', 'DisplayName', 'NN-GT');
    if isfield(results, 'metrics') && isfield(results.metrics, 'energy_nn_vi')
        nn_vi_values = [results.metrics.energy_nn_vi, results.metrics.efficiency_nn_vi, ...
                        results.metrics.error_nn_vi, std(diff(results.V_nn_vi))];
        bar(x + width, nn_vi_values, width, 'm', 'DisplayName', 'NN-VI');
        legend('P&O', 'NN-GT', 'NN-VI');
    else
        legend('P&O', 'NN-GT');
    end
    set(gca, 'XTickLabel', metrics);
    ylabel('Значення');
    title('Порівняння метрик');
    grid on;
    xtickangle(45);
    
    % Графік 9: Фазовий портрет (V-I характеристика)
    subplot(3, 3, 9);
    % Лише для визуалізації зберігаємо кілька графіків
    % Візьмемо дані коли освітленість > 500 W/m²
    mask = results.irradiance_cloudy > 500;
    
    plot(results.V_optimal(mask), results.P_optimal(mask) ./ results.V_optimal(mask), ...
         'g-', 'LineWidth', 2);
    hold on;
    plot(results.V_po(mask), results.I_po(mask), 'b--', 'LineWidth', 1.5);
    plot(results.V_nn(mask), results.I_nn(mask), 'r-.', 'LineWidth', 1.5);
    xlabel('Напруга [V]');
    ylabel('Струм [A]');
    title('I-V характеристика (G > 500 W/m²)');
    legend('Оптимальна', 'P&O', 'NN');
    grid on;
    
    % Загальний заголовок
    sgtitle(sprintf('Симуляція MPPT - Сценарій: %s', results.cloud_scenario), ...
            'FontSize', 14, 'FontWeight', 'bold');
    
end
