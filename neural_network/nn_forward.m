% Пряма передача через нейронну мережу
% Розраховує вихід мережі для заданих входів (Irradiance, Temperature)

function [output, hidden_activations] = nn_forward(network, inputs)
    % Входи:
    %   network - структура нейронної мережи (з ваг та зміщень)
    %   inputs - вектор [G; T] або матриця [G T; G T; ...]
    %          G - освітленість [W/m²]
    %          T - температура [°C]
    %
    % Виходи:
    %   output - вихідна напруга [V] (такої ж розмірності що й входи)
    %   hidden_activations - активації прихованих шарів (для аналізу)
    
    % Переведемо входи у правильний формат
    if isvector(inputs) && numel(inputs) == 2
        x = inputs(:);
    elseif size(inputs, 1) == 2
        x = inputs;
    elseif size(inputs, 2) == 2
        x = inputs';
    else
        error('Невірний формат входів. Очікуються [G; T], [2xN] або [Nx2].');
    end

    single_sample = (size(x, 2) == 1);
    
    % Нормалізація входів
    G_norm = (x(1, :) - network.G_min) / (network.G_max - network.G_min);
    T_norm = (x(2, :) - network.T_min) / (network.T_max - network.T_min);
    
    % Обмеження нормалізованих входів [0, 1]
    G_norm = max(0, min(1, G_norm));
    T_norm = max(0, min(1, T_norm));
    
    z = [G_norm; T_norm];
    
    activations = {};
    activations{1} = z;
    
    for layer = 1:(network.num_layers - 1)
        pre_z = network.W{layer} * z + network.b{layer};
        
        % Застосуємо функцію активації
        switch network.activation{layer}
            case 'tanh'
                a = tanh(pre_z);
            case 'sigmoid'
                a = 1 ./ (1 + exp(-pre_z));
            case 'relu'
                a = max(0, pre_z);
            case 'linear'
                a = pre_z;
            otherwise
                error('Unknown activation function: %s', network.activation{layer});
        end
        
        z = a;
        activations{layer + 1} = a;
    end
    
    output_normalized = z;
    
    % Денормалізація виходу
    output = output_normalized * (network.V_max - network.V_min) + network.V_min;
    
    % Обмеження виходу
    output = max(network.V_min, min(network.V_max, output));
    
    if single_sample
        output = output(1);
    end
    
    % Повертаємо активації прихованих шарів (якщо потрібні)
    if nargout > 1
        hidden_activations = activations;
    end
    
end
