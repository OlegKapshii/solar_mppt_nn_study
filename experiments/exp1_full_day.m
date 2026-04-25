% exp1_full_day.m — Експеримент 1: Повний день з хмарністю.
%
%  Що показує: загальна картина роботи P&O, NN та ідеального трекерів
%  протягом доби. Підраховується сумарна енергія, ефективність трекінгу.
%
%  Запуск:
%    cd full_system
%    octave-cli --no-gui --eval "run('experiments/exp1_full_day.m')"
%
%  Графіки зберігаються у results/exp1_*.png

% Налаштовуємо шляхи модулів
this_dir = fileparts(mfilename('fullpath'));
root = fileparts(this_dir);
addpath(root);
addpath(fullfile(root, 'modules'));
addpath(fullfile(root, 'trackers'));
addpath(fullfile(root, 'nn'));
addpath(fullfile(root, 'sim'));
addpath(fullfile(root, 'utils'));

cfg = config();

fprintf('\n========== EXP 1: Повний день, хмарність %d%% ==========\n', ...
        cfg.clouds.avg_cloudiness_pct);

% --- Симуляції ---
fprintf('Запуск ідеального...\n');
r_id = run_simulation('full_day', @mppt_ideal, cfg);

fprintf('Запуск P&O...\n');
r_po = run_simulation('full_day', @mppt_po, cfg);

fprintf('Запуск NN...\n');
r_nn = run_simulation('full_day', @mppt_nn, cfg);

% --- Енергія ---
E_id = integrate_energy(r_id.P, r_id.dt_s);
E_po = integrate_energy(r_po.P, r_po.dt_s);
E_nn = integrate_energy(r_nn.P, r_nn.dt_s);
E_max = integrate_energy(r_po.P_mpp, r_po.dt_s);

fprintf('\n--- Підсумки ---\n');
fprintf('Теоретичний максимум: %.3f кВт·год\n', E_max);
fprintf('Ідеальний трекер:     %.3f кВт·год  (%.2f%%)\n', E_id, 100*E_id/E_max);
fprintf('P&O:                  %.3f кВт·год  (%.2f%%)\n', E_po, 100*E_po/E_max);
fprintf('NN:                   %.3f кВт·год  (%.2f%%)\n', E_nn, 100*E_nn/E_max);
fprintf('Час P&O:  %.2f с\n', r_po.exec_time_s);
fprintf('Час NN:   %.2f с\n', r_nn.exec_time_s);

% --- Графік 1: Освітленість і температура ---
fig1 = make_figure('Exp 1 — Погода');
subplot(2,1,1);
plot(r_po.t, r_po.G_clear, 'k:', 'LineWidth', 1); hold on;
plot(r_po.t, r_po.G, 'b', 'LineWidth', 1.2);
xlabel('Час, год'); ylabel('G_{POA}, Вт/м²');
title(sprintf('Освітленість (хмарність %d%%)', cfg.clouds.avg_cloudiness_pct));
legend({'Чисте небо', 'З хмарами'}, 'Location', 'northeast');
grid on; xlim([4 21]);

subplot(2,1,2);
plot(r_po.t, r_po.T_amb, 'b', 'LineWidth', 1.2); hold on;
plot(r_po.t, r_po.T_cell, 'r', 'LineWidth', 1.2);
xlabel('Час, год'); ylabel('Температура, °C');
title('Температура повітря і клітин');
legend({'T повітря', 'T клітин'}, 'Location', 'northeast');
grid on; xlim([4 21]);
save_fig(fig1, 'exp1_weather', cfg);

% --- Графік 2: Потужність всіх трекерів ---
fig2 = make_figure('Exp 1 — Потужність');
plot(r_po.t, r_po.P_mpp/1000, 'k:', 'LineWidth', 1); hold on;
plot(r_po.t, r_po.P/1000, 'b', 'LineWidth', 1.2);
plot(r_nn.t, r_nn.P/1000, 'r', 'LineWidth', 1.2);
xlabel('Час, год'); ylabel('Потужність, кВт');
title(sprintf('Потужність впродовж дня (P&O=%.1f%%, NN=%.1f%%)', ...
        100*E_po/E_max, 100*E_nn/E_max));
legend({'Теор. максимум', 'P&O', 'NN'}, 'Location', 'northeast');
grid on; xlim([4 21]);
save_fig(fig2, 'exp1_power', cfg);

% --- Графік 3: Напруга трекерів ---
fig3 = make_figure('Exp 1 — Напруга');
plot(r_po.t, r_po.V_mpp, 'k:', 'LineWidth', 1); hold on;
plot(r_po.t, r_po.V, 'b', 'LineWidth', 0.7);
plot(r_nn.t, r_nn.V, 'r', 'LineWidth', 1);
xlabel('Час, год'); ylabel('V масиву, В');
title('Команда напруги від трекерів vs справжня V_{mpp}');
legend({'V_{mpp} (істина)', 'V (P&O)', 'V (NN)'}, 'Location', 'southeast');
grid on; xlim([4 21]);
save_fig(fig3, 'exp1_voltage', cfg);

% --- CSV дамп ---
if cfg.io.save_csv
    if ~exist(cfg.io.results_dir, 'dir'), mkdir(cfg.io.results_dir); end
    M = [r_po.t(:), r_po.G(:), r_po.T_cell(:), r_po.V_mpp(:), r_po.P_mpp(:), ...
         r_po.V(:), r_po.P(:), r_nn.V(:), r_nn.P(:)];
    fid = fopen(fullfile(cfg.io.results_dir, 'exp1_timeseries.csv'), 'w');
    fprintf(fid, 't_h,G,Tcell,Vmpp,Pmpp,Vpo,Ppo,Vnn,Pnn\n');
    fclose(fid);
    dlmwrite(fullfile(cfg.io.results_dir, 'exp1_timeseries.csv'), M, ...
             '-append', 'precision', '%.4f');
    fprintf('Часові ряди збережено: results/exp1_timeseries.csv\n');
end

fprintf('========== EXP 1 завершено ==========\n');
