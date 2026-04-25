% smoke_nn.m — перевіряємо NN: генерація датасету, тренування, точність.

addpath('modules'); addpath('trackers'); addpath('nn'); addpath('sim'); addpath('utils');

cfg = config();
% Для smoke тесту зменшимо датасет і епохи
cfg.nn.dataset_size = 1000;
cfg.nn.epochs = 200;

fprintf('=== NN smoke test ===\n');

[weights, history] = nn_train(cfg);

% Перевіряємо точність на ручних прикладах
Voc_arr = cfg.panel.Voc_stc * cfg.array.Ns_panels;

test_cases = [1000, 25;
              500,  25;
              800,  40;
              200,  30;
              1100, 50];

fprintf('\n=== Порівняння NN vs справжнього V_mpp ===\n');
fprintf('   G     T    V_mpp(true)   V_mpp(NN)   err[V]   err[%%]\n');
for i = 1:size(test_cases, 1)
    G = test_cases(i, 1); T = test_cases(i, 2);
    [V_true, ~, ~] = pv_mpp(G, T, cfg);
    x = [G / cfg.nn.G_norm; (T - cfg.nn.T_shift) / cfg.nn.T_norm];
    y = nn_forward(x, weights, cfg);
    V_pred = y(1) * Voc_arr;
    err_V = abs(V_pred - V_true);
    err_pct = 100 * err_V / V_true;
    fprintf('  %4.0f  %3.0f     %6.2f      %6.2f    %5.2f    %5.2f\n', ...
            G, T, V_true, V_pred, err_V, err_pct);
end
fprintf('\nFinal val MSE = %.5g\n', history.val_loss(end));
