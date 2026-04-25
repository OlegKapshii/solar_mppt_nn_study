% Ініціалізація нейронної мережи 2-8-4-1
% Архітектура: 2 входи -> 8 нейронів -> 4 нейрони -> 1 вихід

function network = nn_init()
    % Ініціалізація мережі з випадковими вагами за Xavier методом
    
    % Розміри шарів
    network.layer_sizes = [2, 8, 4, 1];
    network.num_layers = length(network.layer_sizes);
    
    % Діапазони нормалізації входів та виходів
    network.G_min = 0;      % Мінімальна освітленість [W/m²]
    network.G_max = 1000;   % Максимальна освітленість [W/m²]
    network.T_min = 15;     % Мінімальна температура [°C]
    network.T_max = 60;     % Максимальна температура [°C]
    network.V_min = 20;     % Мінімальна вихідна напруга [V]
    network.V_max = 60;     % Максимальна вихідна напруга [V]
    
    network.W = {};
    network.b = {};
    
    for layer = 2:network.num_layers
        input_size = network.layer_sizes(layer - 1);
        output_size = network.layer_sizes(layer);
        
        % Випадкова ініціалізація: випадкові значення з нормальним розподілом
        % Стандартне відхилення = sqrt(1 / input_size)
        limit = sqrt(6 / (input_size + output_size));
        network.W{layer - 1} = 2 * limit * (rand(output_size, input_size) - 0.5);
        network.b{layer - 1} = zeros(output_size, 1);
    end
    
    network.activation = {};
    network.activation{1} = 'tanh';      % Прихований шар 1
    network.activation{2} = 'tanh';      % Прихований шар 2
    network.activation{3} = 'linear';    % Вихідний шар
    
    % Параметри тренування
    network.learning_rate = 0.01;
    network.momentum = 0.9;
    network.num_epochs = 200;
    
    % Інформація про мережу
    network.name = 'Simple MPPT Neural Network';
    network.architecture_description = '2-8-4-1 (2 inputs -> 8 hidden -> 4 hidden -> 1 output)';
    
    % Історія втрат для моніторингу тренування
    network.loss_history = [];
    
end
