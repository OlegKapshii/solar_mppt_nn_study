function grads = nn_backward(x, y_true, weights, cache, cfg)
%NN_BACKWARD  Зворотне поширення помилки (backpropagation) вручну.
%
%   grads = nn_backward(x, y_true, weights, cache, cfg)
%
%   Функція втрат — MSE:
%       L = (1/N) * Σ (y_pred - y_true)^2
%
%   Повертає grads.dW{i}, grads.db{i} — градієнти для кожного шару.
%
%   Математика:
%     Для вихідного (лінійного) шару:
%       dL/dz_L = (2/N) * (a_L - y_true)
%
%     Для прихованого шару з tanh:
%       dL/dz_i = (dL/dz_{i+1}) * W_{i+1}' * (1 - tanh(z_i)^2) з перевзмноженням
%
%     Градієнти ваг:
%       dW_i = dL/dz_i * a_{i-1}'
%       db_i = sum(dL/dz_i, 2)

    if nargin < 5, cfg = config(); end

    W = weights.W;
    L = numel(W);
    a = cache.a;
    z = cache.z;

    if size(y_true, 1) == 1
        y_true = y_true(:)';
        if size(x, 2) ~= size(y_true, 2)
            y_true = y_true';
        end
    end

    N_batch = size(x, 2);

    % Градієнти
    dW = cell(1, L);
    db = cell(1, L);

    % Вихідний шар (лінійний)
    dz = (2/N_batch) * (a{L+1} - y_true);

    for i = L:-1:1
        dW{i} = dz * a{i}';
        db{i} = sum(dz, 2);

        if i > 1
            % Похідна tanh: 1 - tanh(z)^2
            dz = (W{i}' * dz) .* (1 - tanh(z{i-1}).^2);
        end
    end

    grads.dW = dW;
    grads.db = db;
end
