% exp6_po_vs_nn.m — Експеримент 6: Зведене порівняння для курсової.
%
%  Будує 4 окремі графіки:
%    fig 6a — Часткова ділянка дня — потужність трекерів
%    fig 6b — Енергія за кілька рівнів хмарності — стовпчики
%    fig 6c — Часткова ділянка — напруга команди
%    fig 6d — Залежність ефективності від хмарності — лінії

this_dir = fileparts(mfilename('fullpath'));
root = fileparts(this_dir);
addpath(root);
addpath(fullfile(root, 'modules'));
addpath(fullfile(root, 'trackers'));
addpath(fullfile(root, 'nn'));
addpath(fullfile(root, 'sim'));
addpath(fullfile(root, 'utils'));

cfg = config();
cfg.clouds.avg_cloudiness_pct = 50;
cfg.clouds.seed = 13;

fprintf('\n========== EXP 6: Зведене порівняння ==========\n');
fflush(stdout);

% --- Базова симуляція (cloud=50%) для графіків 6a і 6c ---
fprintf('Базова симуляція (хм=50%%)... ');
fflush(stdout);
r_po = run_simulation('full_day', @mppt_po, cfg);
r_nn = run_simulation('full_day', @mppt_nn, cfg);
E_po = integrate_energy(r_po.P, r_po.dt_s);
E_nn = integrate_energy(r_nn.P, r_nn.dt_s);
E_max = integrate_energy(r_po.P_mpp, r_po.dt_s);
fprintf('OK\n  P&O=%.2f, NN=%.2f, max=%.2f кВт·год\n', E_po, E_nn, E_max);
fflush(stdout);

% --- Свіп для графіків 6b і 6d ---
cloud_levels = [0 50 80];
N = numel(cloud_levels);
E_po_arr = zeros(1, N);
E_nn_arr = zeros(1, N);
E_id_arr = zeros(1, N);

% Для cloud=50% беремо вже пораховане
E_po_arr(2) = E_po;
E_nn_arr(2) = E_nn;
E_id_arr(2) = E_max;

for k = 1:N
    if k == 2, continue; end
    fprintf('Свіп: хм=%d%% ', cloud_levels(k));
    fflush(stdout);
    cfg.clouds.avg_cloudiness_pct = cloud_levels(k);
    cfg.clouds.seed = 100 + k;
    rA = run_simulation('full_day', @mppt_po, cfg);
    rB = run_simulation('full_day', @mppt_nn, cfg);
    E_po_arr(k) = integrate_energy(rA.P, rA.dt_s);
    E_nn_arr(k) = integrate_energy(rB.P, rB.dt_s);
    E_id_arr(k) = integrate_energy(rA.P_mpp, rA.dt_s);
    fprintf('po=%.2f nn=%.2f id=%.2f\n', E_po_arr(k), E_nn_arr(k), E_id_arr(k));
    fflush(stdout);
end

eff_po = 100 * E_po_arr ./ E_id_arr;
eff_nn = 100 * E_nn_arr ./ E_id_arr;

% --- Графік 6a: повний день, потужність ---
fig = make_figure('Exp 6a — Потужність');
plot(r_po.t, r_po.P_mpp/1000, 'k:', 'LineWidth', 1); hold on;
plot(r_po.t, r_po.P/1000, 'b', 'LineWidth', 0.9);
plot(r_nn.t, r_nn.P/1000, 'r', 'LineWidth', 0.9);
xlabel('Час, год'); ylabel('P, кВт');
legend({'Теор.', 'P&O', 'NN'}, 'Location', 'northeast');
title(sprintf('Повний день, хм=50%% (P&O=%.1f%%, NN=%.1f%%)', ...
        100*E_po/E_max, 100*E_nn/E_max));
grid on; xlim([4 21]);
save_fig(fig, 'exp6a_power', cfg);

% --- Графік 6b: bar по хмарності ---
fig = make_figure('Exp 6b — Енергія');
bar_data = [E_po_arr; E_nn_arr; E_id_arr]';
bar(cloud_levels, bar_data);
xlabel('Хмарність, %'); ylabel('Енергія, кВт·год');
legend({'P&O', 'NN', 'Ідеал'}, 'Location', 'northeast');
title('Енергія за добу при різній хмарності');
grid on;
save_fig(fig, 'exp6b_energy_bar', cfg);

% --- Графік 6c: zoom V в полудень ---
fig = make_figure('Exp 6c — Напруга');
mask = (r_po.t > 11.8) & (r_po.t < 12.2);
plot(r_po.t(mask), r_po.V_mpp(mask), 'k:', 'LineWidth', 1.2); hold on;
plot(r_po.t(mask), r_po.V(mask), 'b', 'LineWidth', 0.7);
plot(r_nn.t(mask), r_nn.V(mask), 'r', 'LineWidth', 1);
xlabel('Час, год'); ylabel('V, В');
legend({'V_{mpp}', 'V P&O', 'V NN'}, 'Location', 'southeast');
title('Напруга трекерів (zoom 11:48-12:12)');
grid on;
save_fig(fig, 'exp6c_voltage_zoom', cfg);

% --- Графік 6d: ефективність ---
fig = make_figure('Exp 6d — Ефективність');
plot(cloud_levels, eff_po, 'b-s', 'LineWidth', 1.5); hold on;
plot(cloud_levels, eff_nn, 'r-^', 'LineWidth', 1.5);
xlabel('Хмарність, %'); ylabel('Ефективність, %');
legend({'P&O', 'NN'}, 'Location', 'southwest');
title('Ефективність трекінгу');
ylim([min(min(eff_po), min(eff_nn))-1, 100]);
grid on;
save_fig(fig, 'exp6d_efficiency', cfg);

% --- CSV ---
if cfg.io.save_csv
    if ~exist(cfg.io.results_dir, 'dir'), mkdir(cfg.io.results_dir); end
    M = [cloud_levels(:), E_id_arr(:), E_po_arr(:), E_nn_arr(:), eff_po(:), eff_nn(:)];
    fid = fopen(fullfile(cfg.io.results_dir, 'exp6_sweep.csv'), 'w');
    fprintf(fid, 'cloud_pct,E_ideal,E_po,E_nn,eff_po,eff_nn\n');
    fclose(fid);
    dlmwrite(fullfile(cfg.io.results_dir, 'exp6_sweep.csv'), M, ...
             '-append', 'precision', '%.4f');
end

fprintf('\nP&O: %.3f кВт·год (%.1f%%)\n', E_po, 100*E_po/E_max);
fprintf('NN:  %.3f кВт·год (%.1f%%)\n', E_nn, 100*E_nn/E_max);
fprintf('========== EXP 6 завершено ==========\n');
