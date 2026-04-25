% exp5_compute_cost.m — Експеримент 5: Обчислювальна складність.
%
%  Що показує: час, який витрачає кожен трекер на 100 000 викликів,
%  тобто скільки тактів процесора йде на одне рішення.
%
%  P&O — кілька умовних операторів і одне додавання;
%  NN — два множення матриць (2→12, 12→8, 8→1) + tanh.
%  Очікуємо, що NN на ~порядок повільніше за P&O в чистому викликку.

this_dir = fileparts(mfilename('fullpath'));
root = fileparts(this_dir);
addpath(root);
addpath(fullfile(root, 'modules'));
addpath(fullfile(root, 'trackers'));
addpath(fullfile(root, 'nn'));
addpath(fullfile(root, 'sim'));
addpath(fullfile(root, 'utils'));

cfg = config();

N_calls = 100000;

% --- Підготовка ---
Voc_arr = cfg.panel.Voc_stc * cfg.array.Ns_panels;
G_test = 800;
T_test = 35;
V_test = 0.8 * Voc_arr;
P_test = 3500;

% --- Бенчмарк P&O ---
state_po = struct();
[~, state_po] = mppt_po(G_test, T_test, 0, 0, state_po, cfg);  % init

tic;
for k = 1:N_calls
    [~, state_po] = mppt_po(G_test, T_test, V_test, P_test, state_po, cfg);
end
t_po = toc;

% --- Бенчмарк NN ---
state_nn = struct();
[~, state_nn] = mppt_nn(G_test, T_test, 0, 0, state_nn, cfg);  % init

tic;
for k = 1:N_calls
    [~, state_nn] = mppt_nn(G_test, T_test, V_test, P_test, state_nn, cfg);
end
t_nn = toc;

% --- Бенчмарк pv_panel (для порівняння — найдорожча операція в циклі) ---
tic;
for k = 1:N_calls
    [~, ~] = pv_panel(V_test, G_test, T_test, cfg);
end
t_pv = toc;

t_per_po = t_po / N_calls * 1e6;  % мкс
t_per_nn = t_nn / N_calls * 1e6;
t_per_pv = t_pv / N_calls * 1e6;

fprintf('\n========== EXP 5: Обчислювальна складність ==========\n');
fprintf('Кількість викликів: %d\n', N_calls);
fprintf('  P&O:      %.2f с (%.2f мкс/виклик)\n', t_po, t_per_po);
fprintf('  NN:       %.2f с (%.2f мкс/виклик)\n', t_nn, t_per_nn);
fprintf('  pv_panel: %.2f с (%.2f мкс/виклик)\n', t_pv, t_per_pv);
fprintf('Відношення NN/P&O: x%.2f\n', t_per_nn / t_per_po);

% --- Розрахунок навантаження для різних частот трекінгу ---
freqs = [1 10 100 1000];
fprintf('\nЗайнятість CPU при різних частотах оновлення трекера:\n');
fprintf('  Гц       P&O        NN\n');
for f = freqs
    cpu_po = t_per_po * f / 1e4;  % %
    cpu_nn = t_per_nn * f / 1e4;
    fprintf('  %4d   %5.2f%%   %5.2f%%\n', f, cpu_po, cpu_nn);
end

% --- Графік ---
fig = make_figure('Exp 5 — Compute cost', 800, 500);
bar([t_per_po, t_per_nn], 'FaceColor', [0.4 0.6 0.9]);
set(gca, 'XTickLabel', {'P&O', 'NN'});
ylabel('Час на один виклик, мкс');
title('Обчислювальна складність трекерів');
grid on;
save_fig(fig, 'exp5_compute_cost', cfg);

if cfg.io.save_csv
    if ~exist(cfg.io.results_dir, 'dir'), mkdir(cfg.io.results_dir); end
    fid = fopen(fullfile(cfg.io.results_dir, 'exp5_cost.csv'), 'w');
    fprintf(fid, 'tracker,t_per_call_us,total_s\n');
    fprintf(fid, 'po,%.4f,%.4f\n', t_per_po, t_po);
    fprintf(fid, 'nn,%.4f,%.4f\n', t_per_nn, t_nn);
    fprintf(fid, 'pv_panel,%.4f,%.4f\n', t_per_pv, t_pv);
    fclose(fid);
end

fprintf('========== EXP 5 завершено ==========\n');
