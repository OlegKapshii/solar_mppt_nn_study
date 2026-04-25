% Ініціалізація нейронної мережи для динамічного MPPT-керування
% Архітектура: 5 входів -> 16 нейронів -> 8 нейронів -> 1 вихід
%
% На відміну від nn_init (входи [G, T] - освітленість та температура),
% ця мережа використовує лише вимірювані в системі значення:
%   V  - напруга панелі [V]
%   I  - струм панелі [A]
%   P  - потужність панелі [W]
%   dV - зміна напруги між двома останніми вимірюваннями [V]
%   dP - зміна потужності між двома останніми вимірюваннями [W]
%
% Вихід мережі - не абсолютна оптимальна напруга, а корекція deltaV,
% яку потрібно додати до поточної напруги. Це ближче до реального MPPT.

function network = nn_init_vi()
    % Ініціалізація мережі з випадковими вагами за Xavier методом

    network.version = 2;

    % Розміри шарів: 5 входів -> 16 -> 8 -> 1 вихід (deltaV)
    network.layer_sizes = [5, 16, 8, 1];
    network.num_layers = length(network.layer_sizes);

    % Діапазони нормалізації входів
    % Масив 10 паралельних x 2 послідовних KC200GT
    network.V_in_min = 0;      % Мінімальна напруга [V]
    network.V_in_max = 70;     % Максимальна напруга [V] (вище за Voc масиву ~65.8V)
    network.I_in_min = 0;      % Мінімальний струм [A]
    network.I_in_max = 100;    % Максимальний струм [A] (вище за Isc масиву ~85.5A)
    network.P_in_min = 0;      % Мінімальна потужність [W]
    network.P_in_max = 4500;   % Максимальна потужність [W]
    network.dV_min   = -5;     % Мінімальна зміна напруги [V]
    network.dV_max   = 5;      % Максимальна зміна напруги [V]
    network.dP_min   = -1200;  % Мінімальна зміна потужності [W]
    network.dP_max   = 1200;   % Максимальна зміна потужності [W]

    % Діапазони виходу: корекція напруги deltaV
    network.output_min = -4;
    network.output_max = 4;

    network.W = {};
    network.b = {};

    for layer = 2:network.num_layers
        input_size  = network.layer_sizes(layer - 1);
        output_size = network.layer_sizes(layer);

        % Xavier ініціалізація
        limit = sqrt(6 / (input_size + output_size));
        network.W{layer - 1} = 2 * limit * (rand(output_size, input_size) - 0.5);
        network.b{layer - 1} = zeros(output_size, 1);
    end

    network.activation = {};
    network.activation{1} = 'tanh';      % Прихований шар 1
    network.activation{2} = 'tanh';      % Прихований шар 2
    network.activation{3} = 'linear';    % Вихідний шар

    % Параметри тренування
    network.learning_rate = 0.005;
    network.momentum      = 0.9;
    network.num_epochs    = 300;

    % Інформація про мережу
    network.name = 'Dynamic VI-based MPPT Neural Network';
    network.architecture_description = ...
        '5-16-8-1 (V,I,P,dV,dP -> 16 hidden -> 8 hidden -> deltaV)';
    network.input_description = ...
        'Входи: V, I, P, dV, dP; вихід: deltaV';

    network.loss_history = [];

end
