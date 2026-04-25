function weights = nn_init(layers, seed)
%NN_INIT  Ініціалізація ваг FC-мережі (Xavier/Glorot).
%
%   weights = nn_init([2 12 8 1])
%   weights = nn_init([2 12 8 1], seed)
%
%   Повертає struct:
%     weights.W — cell-масив матриць ваг:  W{i} має розмір (layers(i+1), layers(i))
%     weights.b — cell-масив векторів зміщень:  b{i} має розмір (layers(i+1), 1)
%     weights.layers — копія конфігурації шарів
%
%   Ініціалізація Xavier:
%     W ~ Uniform(-sqrt(6/(fan_in + fan_out)), +sqrt(6/(fan_in + fan_out)))
%     b = 0

    if nargin < 2, seed = 1; end
    rng(seed);

    L = numel(layers);
    W = cell(1, L-1);
    b = cell(1, L-1);

    for i = 1:L-1
        fan_in  = layers(i);
        fan_out = layers(i+1);
        limit = sqrt(6 / (fan_in + fan_out));
        W{i} = (2*rand(fan_out, fan_in) - 1) * limit;
        b{i} = zeros(fan_out, 1);
    end

    weights.W = W;
    weights.b = b;
    weights.layers = layers;
end
