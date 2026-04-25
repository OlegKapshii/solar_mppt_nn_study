% exp2_transient.m — Експеримент 2: Швидкий хмарний транзієнт.
%
%  Що показує: поведінку трекерів на короткому інтервалі з різкими
%  змінами освітленості. Тут видно проблему «drift» класичного P&O —
%  при швидких змінах G алгоритм робить хибні висновки про напрямок,
%  тоді як NN миттєво реагує (бо вимірює G безпосередньо).
%
%  Використовуємо штучно швидші хмари — щоб ефект був візуально помітний.

this_dir = fileparts(mfilename('fullpath'));
root = fileparts(this_dir);
addpath(root);
addpath(fullfile(root, 'modules'));
addpath(fullfile(root, 'trackers'));
addpath(fullfile(root, 'nn'));
addpath(fullfile(root, 'sim'));
addpath(fullfile(root, 'utils'));

cfg = config();

% --- Налаштовуємо швидку хмарну активність ---
cfg.clouds.avg_cloudiness_pct = 60;
cfg.clouds.p_clear_to_cloudy  = 0.3;   % дуже часті переходи
cfg.clouds.p_cloudy_to_clear  = 0.3;
cfg.clouds.transition_steps   = 3;     % майже без згладжування
cfg.clouds.attenuation_range  = [0.15 0.6];
cfg.clouds.seed = 7;

% Часовий діапазон — 30 хвилин у полудень
t_range = [12.0, 12.5];

fprintf('\n========== EXP 2: Швидкий хмарний транзієнт (30 хв) ==========\n');

r_po = run_simulation('custom', @mppt_po, cfg, 't_range', t_range);
r_nn = run_simulation('custom', @mppt_nn, cfg, 't_range', t_range);
r_id = run_simulation('custom', @mppt_ideal, cfg, 't_range', t_range);

E_po = integrate_energy(r_po.P, r_po.dt_s);
E_nn = integrate_energy(r_nn.P, r_nn.dt_s);
E_id = integrate_energy(r_id.P, r_id.dt_s);

fprintf('Енергія за 30 хв:\n');
fprintf('  Ідеал: %.4f кВт·год\n', E_id);
fprintf('  P&O:   %.4f кВт·год  (%.2f%%)\n', E_po, 100*E_po/E_id);
fprintf('  NN:    %.4f кВт·год  (%.2f%%)\n', E_nn, 100*E_nn/E_id);

% --- Графік: освітленість + потужність ---
fig = make_figure('Exp 2 — Транзієнт', 1000, 700);
t_min = (r_po.t - t_range(1)) * 60;  % хвилини від початку

subplot(3,1,1);
plot(t_min, r_po.G, 'b', 'LineWidth', 1.2);
xlabel('Час, хв'); ylabel('G, Вт/м²');
title('Освітленість (швидкі хмари)'); grid on;

subplot(3,1,2);
plot(t_min, r_po.P_mpp/1000, 'k:', 'LineWidth', 1); hold on;
plot(t_min, r_po.P/1000, 'b', 'LineWidth', 1.0);
plot(t_min, r_nn.P/1000, 'r', 'LineWidth', 1.0);
xlabel('Час, хв'); ylabel('P, кВт');
legend({'Теор. макс.', 'P&O', 'NN'}, 'Location', 'best');
title(sprintf('Потужність  (P&O=%.1f%%, NN=%.1f%%)', 100*E_po/E_id, 100*E_nn/E_id));
grid on;

subplot(3,1,3);
plot(t_min, r_po.V_mpp, 'k:', 'LineWidth', 1); hold on;
plot(t_min, r_po.V, 'b', 'LineWidth', 0.8);
plot(t_min, r_nn.V, 'r', 'LineWidth', 0.8);
xlabel('Час, хв'); ylabel('V_{команда}, В');
legend({'V_{mpp} (істина)', 'V P&O', 'V NN'}, 'Location', 'best');
title('Команда напруги — drift P&O при швидких хмарах');
grid on;

save_fig(fig, 'exp2_transient', cfg);

fprintf('========== EXP 2 завершено ==========\n');
