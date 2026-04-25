% exp3_sweep_cloudiness.m — Експеримент 3: Свіп хмарності.
%
%  Що показує: як ефективність обох трекерів змінюється з ростом
%  середньої хмарності. Будує криву efficiency(cloud%) для P&O і NN.

this_dir = fileparts(mfilename('fullpath'));
root = fileparts(this_dir);
addpath(root);
addpath(fullfile(root, 'modules'));
addpath(fullfile(root, 'trackers'));
addpath(fullfile(root, 'nn'));
addpath(fullfile(root, 'sim'));
addpath(fullfile(root, 'utils'));

cfg = config();

cloud_levels = [0 30 60 80];
N = numel(cloud_levels);

E_po_arr = zeros(1, N);
E_nn_arr = zeros(1, N);
E_id_arr = zeros(1, N);

fprintf('\n========== EXP 3: Свіп хмарності ==========\n');

for k = 1:N
    cfg.clouds.avg_cloudiness_pct = cloud_levels(k);
    fprintf('  Хмарність %d%% ...', cloud_levels(k));
    fflush(stdout);

    r_po = run_simulation('full_day', @mppt_po, cfg);
    r_nn = run_simulation('full_day', @mppt_nn, cfg);

    E_po_arr(k) = integrate_energy(r_po.P, r_po.dt_s);
    E_nn_arr(k) = integrate_energy(r_nn.P, r_nn.dt_s);
    % Замість 3-ї симуляції беремо P_mpp з першої — ідентично ідеалу
    E_id_arr(k) = integrate_energy(r_po.P_mpp, r_po.dt_s);

    fprintf(' E_po=%.2f, E_nn=%.2f, E_id=%.2f кВт·год\n', ...
            E_po_arr(k), E_nn_arr(k), E_id_arr(k));
    fflush(stdout);
end

eff_po = 100 * E_po_arr ./ E_id_arr;
eff_nn = 100 * E_nn_arr ./ E_id_arr;

% --- Графіки ---
fig1 = make_figure('Exp 3 — Енергія vs хмарність');
plot(cloud_levels, E_id_arr, 'k:o', 'LineWidth', 1.2); hold on;
plot(cloud_levels, E_po_arr, 'b-s', 'LineWidth', 1.2);
plot(cloud_levels, E_nn_arr, 'r-^', 'LineWidth', 1.2);
xlabel('Середня хмарність, %'); ylabel('Енергія за добу, кВт·год');
legend({'Ідеал', 'P&O', 'NN'}, 'Location', 'northeast');
title('Залежність зібраної енергії від хмарності');
grid on;
save_fig(fig1, 'exp3_energy_vs_cloud', cfg);

fig2 = make_figure('Exp 3 — Ефективність');
plot(cloud_levels, eff_po, 'b-s', 'LineWidth', 1.5); hold on;
plot(cloud_levels, eff_nn, 'r-^', 'LineWidth', 1.5);
xlabel('Середня хмарність, %'); ylabel('Ефективність трекінгу, %');
legend({'P&O', 'NN'}, 'Location', 'best');
title('Ефективність як функція хмарності');
ylim([min(min(eff_po), min(eff_nn)) - 1, 100]);
grid on;
save_fig(fig2, 'exp3_efficiency_vs_cloud', cfg);

% --- CSV ---
if cfg.io.save_csv
    if ~exist(cfg.io.results_dir, 'dir'), mkdir(cfg.io.results_dir); end
    M = [cloud_levels(:), E_id_arr(:), E_po_arr(:), E_nn_arr(:), eff_po(:), eff_nn(:)];
    fid = fopen(fullfile(cfg.io.results_dir, 'exp3_sweep.csv'), 'w');
    fprintf(fid, 'cloud_pct,E_ideal,E_po,E_nn,eff_po,eff_nn\n');
    fclose(fid);
    dlmwrite(fullfile(cfg.io.results_dir, 'exp3_sweep.csv'), M, ...
             '-append', 'precision', '%.4f');
end

fprintf('========== EXP 3 завершено ==========\n');
