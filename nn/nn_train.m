function [weights, history] = nn_train(cfg, X, Y, verbose)
%NN_TRAIN  Тренування повнозв'язної нейромережі на датасеті (X, Y).
%
%   [weights, history] = nn_train(cfg)
%       — генерує датасет з nn_generate_dataset і тренує мережу
%   [weights, history] = nn_train(cfg, X, Y)
%       — тренує на вже згенерованому датасеті
%
%   Алгоритм:
%     Mini-batch SGD з:
%       - MSE як функцією втрат
%       - фіксованим learning rate (без адаптивних оптимізаторів, щоб
%         студент бачив найпростіший варіант)
%       - перемішуванням прикладів на кожній епосі
%       - валідаційним split 80/20
%
%   Повертає:
%     weights   — навчені ваги
%     history   — struct з полями:
%                 .train_loss (вектор, 1 на епоху)
%                 .val_loss   (вектор, 1 на епоху)
%
%   Ваги зберігаються у cfg.nn.weights_file.

    if nargin < 1, cfg = config(); end
    if nargin < 4, verbose = true; end

    if nargin < 3 || isempty(X) || isempty(Y)
        [X, Y] = nn_generate_dataset(cfg, verbose);
    end

    % --- Train/val split ---
    N = size(X, 2);
    rng(cfg.clouds.seed + 200);
    perm = randperm(N);
    N_train = round(0.8 * N);
    idx_train = perm(1:N_train);
    idx_val   = perm(N_train+1:end);

    X_tr = X(:, idx_train);  Y_tr = Y(idx_train);
    X_va = X(:, idx_val);    Y_va = Y(idx_val);

    % --- Ініціалізація ---
    weights = nn_init(cfg.nn.layers, cfg.clouds.seed + 300);

    lr     = cfg.nn.learning_rate;
    nep    = cfg.nn.epochs;
    bs     = cfg.nn.batch_size;

    history.train_loss = zeros(1, nep);
    history.val_loss   = zeros(1, nep);

    if verbose
        fprintf('[nn_train] Архітектура: [%s]\n', num2str(cfg.nn.layers));
        fprintf('[nn_train] Train: %d, Val: %d, lr=%.3g, epochs=%d, batch=%d\n', ...
                N_train, numel(idx_val), lr, nep, bs);
    end

    % --- Цикл навчання ---
    t_start = tic;
    for ep = 1:nep
        % Перемішування
        p = randperm(N_train);
        batch_losses = [];

        for b_start = 1:bs:N_train
            b_end = min(b_start + bs - 1, N_train);
            idx_b = p(b_start:b_end);

            x_b = X_tr(:, idx_b);
            y_b = Y_tr(idx_b);

            [y_pred, cache] = nn_forward(x_b, weights, cfg);

            loss = mean((y_pred(:) - y_b(:)).^2);
            batch_losses(end+1) = loss;

            grads = nn_backward(x_b, y_b, weights, cache, cfg);

            % SGD step
            for i = 1:numel(weights.W)
                weights.W{i} = weights.W{i} - lr * grads.dW{i};
                weights.b{i} = weights.b{i} - lr * grads.db{i};
            end
        end

        history.train_loss(ep) = mean(batch_losses);

        % Валідація
        y_val = nn_forward(X_va, weights, cfg);
        history.val_loss(ep) = mean((y_val(:) - Y_va(:)).^2);

        if verbose && (mod(ep, max(1, floor(nep/20))) == 0 || ep == 1)
            fprintf('  ep %3d/%d: train=%.5g  val=%.5g  (t=%.1fs)\n', ...
                    ep, nep, history.train_loss(ep), history.val_loss(ep), toc(t_start));
        end
    end

    if verbose
        fprintf('[nn_train] Навчання завершено за %.1f с\n', toc(t_start));
        fprintf('[nn_train] Final val MSE = %.5g  (RMSE на V_mpp ≈ %.2f В)\n', ...
                history.val_loss(end), ...
                sqrt(history.val_loss(end)) * cfg.panel.Voc_stc * cfg.array.Ns_panels);
    end

    % --- Збереження ---
    nn_dir = fileparts(cfg.nn.weights_file);
    if ~exist(nn_dir, 'dir')
        mkdir(nn_dir);
    end
    save('-mat-binary', cfg.nn.weights_file, 'weights', 'history');
    if verbose
        fprintf('[nn_train] Ваги збережено: %s\n', cfg.nn.weights_file);
    end
end
