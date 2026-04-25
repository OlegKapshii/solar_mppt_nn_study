% Тренування нейронної мережи методом gradient descent
% Навчає мережу на синтетичних даних сонячних панелей

function [network, training_info] = nn_train(network, training_data, validation_data)
    % Входи:
    %   network - ініціалізована структура мережі
    %   training_data - структура з полями:
    %                  .G - вектор освітленостей [W/m²]
    %                  .T - вектор температур [°C]
    %                  .V - вектор оптимальних напруг [V]
    %   validation_data - структура аналогічна training_data (опціонально)
    %
    % Виходи:
    %   network - натренована мережа
    %   training_info - інформація про тренування
    
    if nargin < 3
        validation_data = [];
    end
    
    learning_rate = network.learning_rate;
    momentum = network.momentum;
    num_epochs = network.num_epochs;
    
    X_train = [training_data.G; training_data.T];
    y_train = training_data.V;

    num_samples = size(X_train, 2);

    Xn_train = normalize_inputs(network, X_train);
    yn_train = normalize_output(network, y_train);
    
    % Ініціалізація velocity для momentum
    velocity = {};
    for i = 1:(network.num_layers - 1)
        velocity{i}.W = zeros(size(network.W{i}));
        velocity{i}.b = zeros(size(network.b{i}));
    end
    
    train_losses = [];
    validation_losses = [];
    
    % Тренування
    fprintf('Тренування нейронної мережи...\n');
    fprintf('Архітектура: %s\n', network.architecture_description);
    fprintf('Кількість епох: %d\n', num_epochs);
    fprintf('Learning rate: %.4f\n', learning_rate);
    fprintf('Momentum: %.4f\n\n', momentum);
    
    for epoch = 1:num_epochs
        % Forward pass у нормалізованому просторі
        [y_hat_n, activations, pre_activations] = forward_normalized(network, Xn_train);

        residual_n = y_hat_n - yn_train;
        train_loss = mean((denormalize_output(network, y_hat_n) - y_train).^2);
        train_losses = [train_losses, train_loss];

        % Validation loss
        if ~isempty(validation_data)
            X_val = [validation_data.G; validation_data.T];
            y_val = validation_data.V;
            pred_val = nn_forward(network, X_val);
            val_loss = mean((pred_val - y_val).^2);
            validation_losses = [validation_losses, val_loss];
        end

        % Backpropagation
        dA = (2 / num_samples) * residual_n;
        deltas = {};

        for layer = (network.num_layers - 1):-1:1
            act_name = network.activation{layer};
            dZ = dA .* activation_derivative(act_name, pre_activations{layer}, activations{layer + 1});
            deltas{layer} = dZ;

            if layer > 1
                dA = network.W{layer}' * dZ;
            end
        end

        % Оновлення ваг
        for layer = 1:(network.num_layers - 1)
            dL_dW = deltas{layer} * activations{layer}';
            dL_db = sum(deltas{layer}, 2);

            % Оновлення з моментом
            velocity{layer}.W = momentum * velocity{layer}.W - learning_rate * dL_dW;
            velocity{layer}.b = momentum * velocity{layer}.b - learning_rate * dL_db;

            network.W{layer} = network.W{layer} + velocity{layer}.W;
            network.b{layer} = network.b{layer} + velocity{layer}.b;
        end
        
        % Виведення прогресу кожні 20 епох
        if mod(epoch, max(1, num_epochs / 10)) == 0
            if ~isempty(validation_data)
                fprintf('Епоха %3d/%3d: Train MSE = %.6f, Val MSE = %.6f\n', ...
                    epoch, num_epochs, train_loss, val_loss);
            else
                fprintf('Епоха %3d/%3d: Train MSE = %.6f\n', ...
                    epoch, num_epochs, train_loss);
            end
        end
    end
    
    % Фінальний вивід
    fprintf('\n✓ Тренування завершено\n');
    fprintf('Фінальна помилка на тренуванні: %.6f\n', train_losses(end));
    if ~isempty(validation_data)
        fprintf('Фінальна помилка на валідації: %.6f\n', validation_losses(end));
    end
    
    % Зберігаємо історію для аналізу
    network.loss_history.train = train_losses;
    network.loss_history.validation = validation_losses;
    
    % Структура інформації про тренування
    training_info.final_train_mse = train_losses(end);
    training_info.best_train_mse = min(train_losses);
    training_info.train_losses = train_losses;
    if ~isempty(validation_data)
        training_info.final_val_mse = validation_losses(end);
        training_info.best_val_mse = min(validation_losses);
        training_info.val_losses = validation_losses;
    end
    
end

function Xn = normalize_inputs(network, X)
    G_norm = (X(1, :) - network.G_min) / (network.G_max - network.G_min);
    T_norm = (X(2, :) - network.T_min) / (network.T_max - network.T_min);
    Xn = [max(0, min(1, G_norm)); max(0, min(1, T_norm))];
end

function yn = normalize_output(network, y)
    yn = (y - network.V_min) / (network.V_max - network.V_min);
    yn = max(0, min(1, yn));
end

function y = denormalize_output(network, yn)
    y = yn * (network.V_max - network.V_min) + network.V_min;
end

function [y_hat_n, activations, pre_activations] = forward_normalized(network, Xn)
    activations = {};
    pre_activations = {};
    activations{1} = Xn;
    z = Xn;

    for layer = 1:(network.num_layers - 1)
        pre_z = network.W{layer} * z + network.b{layer};
        pre_activations{layer} = pre_z;

        switch network.activation{layer}
            case 'tanh'
                z = tanh(pre_z);
            case 'sigmoid'
                z = 1 ./ (1 + exp(-pre_z));
            case 'relu'
                z = max(0, pre_z);
            case 'linear'
                z = pre_z;
            otherwise
                error('Unknown activation: %s', network.activation{layer});
        end
        activations{layer + 1} = z;
    end

    y_hat_n = z;
end

function d = activation_derivative(name, pre_a, a)
    switch name
        case 'tanh'
            d = 1 - a.^2;
        case 'sigmoid'
            d = a .* (1 - a);
        case 'relu'
            d = double(pre_a > 0);
        case 'linear'
            d = ones(size(pre_a));
        otherwise
            error('Unknown activation: %s', name);
    end
end
