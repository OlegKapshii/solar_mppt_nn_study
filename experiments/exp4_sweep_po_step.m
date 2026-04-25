% exp4_sweep_po_step.m — Експеримент 4: Свіп V_step для P&O.
%
%  Що показує: tradeoff «швидкість сходження ↔ точність у стаціонарі».
%  Малий V_step → висока точність на MPP, але повільне сходження.
%  Великий V_step → швидке сходження, але великі осциляції.
%
%  Студент бачить: оптимальний V_step залежить від динаміки погоди.

this_dir = fileparts(mfilename('fullpath'));
root = fileparts(this_dir);
addpath(root);
addpath(fullfile(root, 'modules'));
addpath(fullfile(root, 'trackers'));
addpath(fullfile(root, 'nn'));
addpath(fullfile(root, 'sim'));
addpath(fullfile(root, 'utils'));

cfg = config();

V_steps = [0.2 0.5 1.0 2.0 5.0];
N = numel(V_steps);

E_po_arr = zeros(1, N);
E_id_arr = zeros(1, N);
osc_amp  = zeros(1, N);  % середня амплітуда осциляції в стаціонарі

fprintf('\n========== EXP 4: Свіп V_step для P&O ==========\n');

for k = 1:N
    cfg.po.V_step = V_steps(k);
    fprintf('  V_step = %.2f В ...', V_steps(k));
    fflush(stdout);

    r_po = run_simulation('full_day', @mppt_po, cfg);
    E_po_arr(k) = integrate_energy(r_po.P, r_po.dt_s);
    E_id_arr(k) = integrate_energy(r_po.P_mpp, r_po.dt_s);  % з тих самих даних

    % Оцінка осциляції — std V у вікні стабільної освітленості (полудень)
    mid_idx = (r_po.t > 11.5) & (r_po.t < 12.5) & (r_po.G > 800);
    if any(mid_idx)
        osc_amp(k) = std(r_po.V(mid_idx));
    end

    fprintf(' E_po=%.3f, eff=%.2f%%, osc_amp=%.2f В\n', ...
            E_po_arr(k), 100*E_po_arr(k)/E_id_arr(k), osc_amp(k));
    fflush(stdout);
end

eff_po = 100 * E_po_arr ./ E_id_arr;

% --- Графік ---
fig = make_figure('Exp 4 — V_step tradeoff', 1000, 500);
subplot(1,2,1);
semilogx(V_steps, eff_po, 'b-s', 'LineWidth', 1.5);
xlabel('V_{step}, В (масштаб масиву)'); ylabel('Ефективність, %');
title('Ефективність P&O vs крок збурення');
grid on;

subplot(1,2,2);
semilogx(V_steps, osc_amp, 'r-o', 'LineWidth', 1.5);
xlabel('V_{step}, В'); ylabel('std(V) в стаціонарі, В');
title('Амплітуда осциляції у MPP');
grid on;
save_fig(fig, 'exp4_po_step', cfg);

if cfg.io.save_csv
    if ~exist(cfg.io.results_dir, 'dir'), mkdir(cfg.io.results_dir); end
    M = [V_steps(:), E_po_arr(:), eff_po(:), osc_amp(:)];
    fid = fopen(fullfile(cfg.io.results_dir, 'exp4_sweep.csv'), 'w');
    fprintf(fid, 'V_step,E_po,eff_po,osc_amp\n');
    fclose(fid);
    dlmwrite(fullfile(cfg.io.results_dir, 'exp4_sweep.csv'), M, ...
             '-append', 'precision', '%.4f');
end

fprintf('========== EXP 4 завершено ==========\n');
