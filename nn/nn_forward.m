function [y, cache] = nn_forward(x, weights, cfg)
%NN_FORWARD  Прямий прохід повнозв'язної мережі.
%
%   y = nn_forward(x, weights, cfg)          — лише вихід
%   [y, cache] = nn_forward(x, weights, cfg) — плюс проміжні активації для backprop
%
%   Архітектура шару i (i = 1..L-1):
%       z_i = W_i * a_{i-1} + b_i
%       a_i = f(z_i),   де f = tanh для внутрішніх шарів,
%                             f = linear для вихідного
%   a_0 = x (вхід)
%
%   x      — стовпець розміром (n_inputs, 1) або матриця (n_inputs, batch)
%   weights — з nn_init()
%   cfg    — конфіг (використовується cfg.nn.activation)

    if nargin < 3, cfg = config(); end

    if isrow(x)
        x = x(:);  % стовпцеве оформлення
    end

    W = weights.W;
    b = weights.b;
    L = numel(W);

    a = x;                     % активація попереднього шару
    cache.a = cell(1, L+1);
    cache.z = cell(1, L);
    cache.a{1} = a;

    for i = 1:L
        z = W{i} * a + b{i};
        cache.z{i} = z;
        if i == L
            a = z;             % вихідний шар — лінійний
        else
            a = tanh(z);
        end
        cache.a{i+1} = a;
    end

    y = a;
end
