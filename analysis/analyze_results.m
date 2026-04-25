% Аналіз результатів порівняння MPPT алгоритмів

clear; close all; clc;

analysis_dir = fileparts(mfilename('fullpath'));
project_dir = fileparts(analysis_dir);

comparison_file = fullfile(project_dir, 'simulation', 'comparison_results.mat');
if ~exist(comparison_file, 'file')
    fprintf('Файл comparison_results.mat не знайдено. Спочатку запустіть compare_algorithms.\n');
    return;
end

loaded = load(comparison_file);
all_results = loaded.all_results;

N = length(all_results);
if N == 0
    fprintf('Немає результатів для аналізу.\n');
    return;
end

has_vi_pure = isfield(all_results{1}.metrics, 'efficiency_nn_vi_pure');
has_vi_hybrid = isfield(all_results{1}.metrics, 'efficiency_nn_vi');
has_po_pyr = isfield(all_results{1}.metrics, 'efficiency_po_pyr');

fprintf('=== АНАЛІЗ РЕЗУЛЬТАТІВ MPPT ===\n\n');

for i = 1:N
    r = all_results{i};
    fprintf('─────────────────────────────────────────\n');
    fprintf('Сценарій: %s\n', r.scenario_name);
    fprintf('─────────────────────────────────────────\n');

    fprintf('Енергія та ефективність:\n');
    fprintf('  P&O:      %.2f Wh (%.2f%%)\n', r.metrics.energy_po, r.metrics.efficiency_po);
    if has_po_pyr
        fprintf('  P&O+Pyr:  %.2f Wh (%.2f%%)\n', r.metrics.energy_po_pyr, r.metrics.efficiency_po_pyr);
    end
    fprintf('  NN-GT:    %.2f Wh (%.2f%%)\n', r.metrics.energy_nn, r.metrics.efficiency_nn);
    if has_vi_pure
        fprintf('  NN-VI Pure:   %.2f Wh (%.2f%%)\n', r.metrics.energy_nn_vi_pure, r.metrics.efficiency_nn_vi_pure);
    end
    if has_vi_hybrid
        fprintf('  NN-VI Hybrid: %.2f Wh (%.2f%%)\n', r.metrics.energy_nn_vi, r.metrics.efficiency_nn_vi);
    end
    fprintf('  Оптимум:  %.2f Wh\n', r.metrics.energy_optimal);

    fprintf('Похибка напруги (MAE):\n');
    fprintf('  P&O:   %.3f V\n', r.metrics.error_po);
    if has_po_pyr
        fprintf('  P&O+Pyr: %.3f V\n', r.metrics.error_po_pyr);
    end
    fprintf('  NN-GT: %.3f V\n', r.metrics.error_nn);
    if has_vi_pure
        fprintf('  NN-VI Pure:   %.3f V\n', r.metrics.error_nn_vi_pure);
    end
    if has_vi_hybrid
        fprintf('  NN-VI Hybrid: %.3f V\n', r.metrics.error_nn_vi);
    end

    fprintf('Стабільність (std(dV)):\n');
    fprintf('  P&O:   %.4f V\n', r.metrics.oscill_po);
    if has_po_pyr
        fprintf('  P&O+Pyr: %.4f V\n', r.metrics.oscill_po_pyr);
    end
    fprintf('  NN-GT: %.4f V\n', r.metrics.oscill_nn);
    if has_vi_pure
        fprintf('  NN-VI Pure:   %.4f V\n', r.metrics.oscill_nn_vi_pure);
    end
    if has_vi_hybrid
        fprintf('  NN-VI Hybrid: %.4f V\n', r.metrics.oscill_nn_vi);
    end

    fprintf('\n');
end

po_eff = cellfun(@(r) r.metrics.efficiency_po, all_results);
nn_eff = cellfun(@(r) r.metrics.efficiency_nn, all_results);
po_err = cellfun(@(r) r.metrics.error_po, all_results);
nn_err = cellfun(@(r) r.metrics.error_nn, all_results);

fprintf('═════════════════════════════════════════\n');
fprintf('=== ЗАГАЛЬНЕ ПОРІВНЯННЯ ===\n');
fprintf('═════════════════════════════════════════\n\n');

fprintf('Середня ефективність P&O:   %.3f%%\n', mean(po_eff));
if has_po_pyr
    po_pyr_eff = cellfun(@(r) r.metrics.efficiency_po_pyr, all_results);
    fprintf('Середня ефективність P&O+Pyr: %.3f%%\n', mean(po_pyr_eff));
end
fprintf('Середня ефективність NN-GT: %.3f%%\n', mean(nn_eff));
if has_vi_pure
    vi_p_eff = cellfun(@(r) r.metrics.efficiency_nn_vi_pure, all_results);
    fprintf('Середня ефективність NN-VI Pure:   %.3f%%\n', mean(vi_p_eff));
end
if has_vi_hybrid
    vi_h_eff = cellfun(@(r) r.metrics.efficiency_nn_vi, all_results);
    fprintf('Середня ефективність NN-VI Hybrid: %.3f%%\n', mean(vi_h_eff));
end

fprintf('\nСередня MAE P&O:   %.3f V\n', mean(po_err));
if has_po_pyr
    po_pyr_err = cellfun(@(r) r.metrics.error_po_pyr, all_results);
    fprintf('Середня MAE P&O+Pyr: %.3f V\n', mean(po_pyr_err));
end
fprintf('Середня MAE NN-GT: %.3f V\n', mean(nn_err));
if has_vi_pure
    vi_p_err = cellfun(@(r) r.metrics.error_nn_vi_pure, all_results);
    fprintf('Середня MAE NN-VI Pure:   %.3f V\n', mean(vi_p_err));
end
if has_vi_hybrid
    vi_h_err = cellfun(@(r) r.metrics.error_nn_vi, all_results);
    fprintf('Середня MAE NN-VI Hybrid: %.3f V\n', mean(vi_h_err));
end

report_file = fullfile(analysis_dir, 'analysis_report.txt');
fid = fopen(report_file, 'w');

fprintf(fid, 'ЗВІТ АНАЛІЗУ MPPT АЛГОРИТМІВ\n');
fprintf(fid, '============================\n\n');
fprintf(fid, 'Дата: %s\n\n', datestr(now));

for i = 1:N
    r = all_results{i};
    fprintf(fid, '%s\n', r.scenario_name);
    fprintf(fid, '  P&O:   %.2f Wh (%.2f%%), MAE=%.3f V\n', r.metrics.energy_po, r.metrics.efficiency_po, r.metrics.error_po);
    if has_po_pyr
        fprintf(fid, '  P&O+Pyr: %.2f Wh (%.2f%%), MAE=%.3f V\n', r.metrics.energy_po_pyr, r.metrics.efficiency_po_pyr, r.metrics.error_po_pyr);
    end
    fprintf(fid, '  NN-GT: %.2f Wh (%.2f%%), MAE=%.3f V\n', r.metrics.energy_nn, r.metrics.efficiency_nn, r.metrics.error_nn);
    if has_vi_pure
        fprintf(fid, '  NN-VI Pure:   %.2f Wh (%.2f%%), MAE=%.3f V\n', r.metrics.energy_nn_vi_pure, r.metrics.efficiency_nn_vi_pure, r.metrics.error_nn_vi_pure);
    end
    if has_vi_hybrid
        fprintf(fid, '  NN-VI Hybrid: %.2f Wh (%.2f%%), MAE=%.3f V\n', r.metrics.energy_nn_vi, r.metrics.efficiency_nn_vi, r.metrics.error_nn_vi);
    end
    fprintf(fid, '  Оптимум: %.2f Wh\n\n', r.metrics.energy_optimal);
end

fprintf(fid, 'СЕРЕДНІ ЗНАЧЕННЯ\n');
fprintf(fid, 'P&O eff: %.3f%% | MAE: %.3f V\n', mean(po_eff), mean(po_err));
if has_po_pyr
    fprintf(fid, 'P&O+Pyr eff: %.3f%% | MAE: %.3f V\n', mean(po_pyr_eff), mean(po_pyr_err));
end
fprintf(fid, 'NN-GT eff: %.3f%% | MAE: %.3f V\n', mean(nn_eff), mean(nn_err));
if has_vi_pure
    fprintf(fid, 'NN-VI Pure eff: %.3f%% | MAE: %.3f V\n', mean(vi_p_eff), mean(vi_p_err));
end
if has_vi_hybrid
    fprintf(fid, 'NN-VI Hybrid eff: %.3f%% | MAE: %.3f V\n', mean(vi_h_eff), mean(vi_h_err));
end

fclose(fid);

fprintf('\n✓ Звіт збережено: analysis/analysis_report.txt\n');
fprintf('=== АНАЛІЗ ЗАВЕРШЕНО ===\n');
