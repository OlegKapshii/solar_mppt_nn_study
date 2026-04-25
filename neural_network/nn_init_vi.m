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

    network.version = 4;

    % Розміри шарів: 6 входів -> 24 -> 12 -> 1 вихід (deltaV)
    % Збільшена архітектура для кращого захоплення динаміки
    network.layer_sizes = [6, 24, 12, 1];
    network.num_layers = length(network.layer_sizes);

    % Діапазони нормалізації входів
    % Масив 10 series × 2 parallel KC200GT:
    %   Voc_arr ≈ 329 V, Isc_arr ≈ 17 A, Pmax ≈ 4000 W
    network.V_in_min = 0;      % Мінімальна напруга [V]
    network.V_in_max = 340;    % Максимальна напруга [V] (~Voc_arr + запас)
    network.V_prev_min = 0;    % Мінімальна напруга попереднього кроку [V]
    network.V_prev_max = 340;  % Максимальна напруга попереднього кроку [V]
    network.I_in_min = 0;      % Мінімальний струм [A]
    network.I_in_max = 20;     % Максимальний струм [A] (вище за Isc_arr=17.1)
    network.P_in_min = 0;      % Мінімальна потужність [W]
    network.P_in_max = 4500;   % Максимальна потужність [W]
    network.dV_min   = -8;     % Мінімальна зміна напруги [V] на крок
    network.dV_max   = 8;      % Максимальна зміна напруги [V] на крок
    network.dP_min   = -1200;  % Мінімальна зміна потужності [W]
    network.dP_max   = 1200;   % Максимальна зміна потужності [W]

    % Діапазони виходу: корекція напруги deltaV
    % Узгоджено з runtime-обмеженням керування. Раніше було ±1.2 В для масиву
    % з Voc=66 В (~1.8% Voc); зараз масштабовано до ±6 В для Voc=329 В (~1.8%).
    network.output_min = -6;
    network.output_max = 6;
    network.action_limit = 6;

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

    % Параметри тренування (оптимізовані для покращеної генералізації)
    network.learning_rate = 0.002;  % Зменшена швидкість навчання для більш стабільної конвергенції
    network.momentum      = 0.9;
    network.num_epochs    = 500;    % Збільшена кількість епох для кращого навчання

    % Інформація про мережу
    network.name = 'Enhanced Dynamic VI-based MPPT Neural Network (v4)';
    network.architecture_description = ...
        '6-24-12-1 (V,V_prev,I,P,dV,dP -> 24 hidden -> 12 hidden -> deltaV)';
    network.input_description = ...
        'Входи: V, V_prev, I, P, dV, dP; вихід: deltaV';

    network.loss_history = [];

end
