function [X, Y] = nn_generate_dataset(cfg, verbose)
%NN_GENERATE_DATASET  Генерує навчальний набір (G, T) → V_mpp/Voc_arr.
%
%   [X, Y] = nn_generate_dataset(cfg)
%
%   X — матриця (2, N) з нормалізованими входами:
%       рядок 1: G / G_norm         (0..1+)
%       рядок 2: (T - T_shift) / T_norm
%   Y — вектор-рядок (1, N) з нормалізованим виходом:
%       V_mpp / Voc_array           (0..1)
%
%   Додається випадковий шум вимірювань на входах, щоб мережа
%   вчилась бути стійкою до похибок сенсорів.
%
%   Розподіл точок (G, T):
%     G ∈ [50, 1200]  — лог-рівномірно (більше точок при низькій G)
%     T ∈ [0, 70]     — рівномірно
%
%   Лог-розподіл по G робить мережу точнішою при низькій освітленості,
%   де V_mpp змінюється найсильніше.

    if nargin < 1, cfg = config(); end
    if nargin < 2, verbose = true; end

    rng(cfg.clouds.seed + 100);  % окремий seed для стабільності

    N = cfg.nn.dataset_size;
    Voc_arr = cfg.panel.Voc_stc * cfg.array.Ns_panels;

    % --- Розподіл входів ---
    G_min = 50; G_max = 1200;
    logG_min = log(G_min); logG_max = log(G_max);
    G_samples = exp(logG_min + (logG_max - logG_min) * rand(1, N));

    T_min = 0; T_max = 70;
    T_samples = T_min + (T_max - T_min) * rand(1, N);

    if verbose
        fprintf('[nn_generate_dataset] Генерую %d зразків (G, T) → V_mpp...\n', N);
    end

    % --- Цільові значення V_mpp ---
    V_mpp_samples = zeros(1, N);
    for k = 1:N
        [V_mpp_samples(k), ~, ~] = pv_mpp(G_samples(k), T_samples(k), cfg);
        if verbose && mod(k, max(1, floor(N/20))) == 0
            fprintf('  %d/%d\n', k, N);
        end
    end

    % --- Шум на вимірюваннях (на входах, не на цілі) ---
    noise = cfg.nn.measurement_noise;
    G_noisy = G_samples .* (1 + noise * (2*rand(1, N) - 1));
    T_noisy = T_samples + noise * 20 * (2*rand(1, N) - 1);  % ±0.4°C при noise=0.02

    % --- Нормалізація ---
    X = zeros(2, N);
    X(1, :) = G_noisy / cfg.nn.G_norm;
    X(2, :) = (T_noisy - cfg.nn.T_shift) / cfg.nn.T_norm;
    Y = V_mpp_samples / Voc_arr;

    if verbose
        fprintf('[nn_generate_dataset] Готово. X: %dx%d, Y: %dx%d\n', ...
                size(X,1), size(X,2), size(Y,1), size(Y,2));
    end
end
