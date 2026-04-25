% Пряма передача через VI нейронну мережу
% Розраховує корекцію напруги deltaV на основі поточних вимірювань.
%
% Відрізняється від nn_forward тим, що НЕ використовує освітленість (G)
% та температуру (T) — лише ті величини, що доступні в реальній системі.

function [output, hidden_activations] = nn_forward_vi(network, inputs)
    % Входи:
    %   network - структура мережі (з nn_init_vi або nn_train_vi)
    %   inputs  - вектор [V; I; P; dV; dP] або матриця [5xN] або [Nx5]
    %             V  - поточна напруга панелі [V]
    %             I  - поточний струм панелі [A]
    %             P  - поточна потужність панелі [W]
    %             dV - зміна напруги між двома кроками [V]
    %             dP - зміна потужності між двома кроками [W]
    %
    % Виходи:
    %   output             - прогнозована корекція deltaV [V]
    %   hidden_activations - активації шарів (для аналізу, опціонально)

    % Переведення у формат [5 x N]
    if isvector(inputs) && numel(inputs) == 5
        x = inputs(:);
    elseif size(inputs, 1) == 5
        x = inputs;
    elseif size(inputs, 2) == 5
        x = inputs';
    else
        error('Невірний формат входів. Очікуються [V; I; P; dV; dP], [5xN] або [Nx5].');
    end

    single_sample = (size(x, 2) == 1);

    % Нормалізація входів: [0, 1]
    V_norm = (x(1, :) - network.V_in_min) / (network.V_in_max - network.V_in_min);
    I_norm = (x(2, :) - network.I_in_min) / (network.I_in_max - network.I_in_min);
    P_norm = (x(3, :) - network.P_in_min) / (network.P_in_max - network.P_in_min);
    dV_norm = (x(4, :) - network.dV_min) / (network.dV_max - network.dV_min);
    dP_norm = (x(5, :) - network.dP_min) / (network.dP_max - network.dP_min);

    V_norm = max(0, min(1, V_norm));
    I_norm = max(0, min(1, I_norm));
    P_norm = max(0, min(1, P_norm));
    dV_norm = max(0, min(1, dV_norm));
    dP_norm = max(0, min(1, dP_norm));

    z = [V_norm; I_norm; P_norm; dV_norm; dP_norm];

    activations    = {};
    activations{1} = z;

    % Пряма передача через шари
    for layer = 1:(network.num_layers - 1)
        pre_z = network.W{layer} * z + network.b{layer};

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

    % Денормалізація виходу
    output = z * (network.output_max - network.output_min) + network.output_min;
    output = max(network.output_min, min(network.output_max, output));

    if single_sample
        output = output(1);
    end

    if nargout > 1
        hidden_activations = activations;
    end

end
