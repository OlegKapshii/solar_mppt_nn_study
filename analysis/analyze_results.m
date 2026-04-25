% Аналіз результатів симуляції та статистичні розрахунки

clear; close all; clc;

analysis_dir = fileparts(mfilename('fullpath'));
project_dir = fileparts(analysis_dir);

addpath(fullfile(project_dir, 'simulation'));

fprintf('=== АНАЛІЗ РЕЗУЛЬТАТІВ MPPT ===\n\n');

comparison_file = fullfile(project_dir, 'simulation', 'comparison_results.mat');
if ~exist(comparison_file, 'file')
    fprintf('Файл порівняльних результатів не знайдений!\n');
    fprintf('Спочатку запустіть compare_algorithms\n');
    return;
end

loaded = load(comparison_file);
all_results = loaded.all_results;
fprintf('✓ Результати завантажені\n\n');

fprintf('=== ДЕТАЛЬНИЙ АНАЛІЗ ПО СЦЕНАРІЯХ ===\n\n');

for i = 1:length(all_results)
    result = all_results{i};

    fprintf('─────────────────────────────────────────\n');
    fprintf('Сценарій: %s\n', result.scenario_name);
    fprintf('─────────────────────────────────────────\n');

    fprintf('\n1. ЕНЕРГІЯ І ЕФЕКТИВНІСТЬ:\n');
    fprintf('   P&O MPPT:    %.2f Wh (%.2f%%)\n', result.metrics.energy_po, result.metrics.efficiency_po);
    fprintf('   NN-GT MPPT:  %.2f Wh (%.2f%%)  [входи: G, T]\n', result.metrics.energy_nn, result.metrics.efficiency_nn);
    if isfield(result.metrics, 'energy_nn_vi')
        fprintf('   NN-VI Hybrid: %.2f Wh (%.2f%%)  [NN + локальна P&O корекція]\n', result.metrics.energy_nn_vi, result.metrics.efficiency_nn_vi);
    end
    fprintf('   Оптимум:     %.2f Wh\n', result.metrics.energy_optimal);

    energy_diff_gt = result.metrics.energy_nn - result.metrics.energy_po;
    fprintf('   Перевага NN-GT над P&O: %.2f Wh (%.2f%%)\n', energy_diff_gt, ...
        100 * energy_diff_gt / max(result.metrics.energy_po, eps));
    if isfield(result.metrics, 'energy_nn_vi')
        energy_diff_vi = result.metrics.energy_nn_vi - result.metrics.energy_po;
        fprintf('   Перевага NN-VI Hybrid над P&O: %.2f Wh (%.2f%%)\n', energy_diff_vi, ...
            100 * energy_diff_vi / max(result.metrics.energy_po, eps));
    end

    fprintf('\n2. ТОЧНІСТЬ (помилка напруги):\n');
    fprintf('   P&O:    %.3f V\n', result.metrics.error_po);
    fprintf('   NN-GT:  %.3f V\n', result.metrics.error_nn);
    if isfield(result.metrics, 'error_nn_vi')
        fprintf('   NN-VI Hybrid: %.3f V\n', result.metrics.error_nn_vi);
    end

    fprintf('\n3. СТАБІЛЬНІСТЬ (std(dV)):\n');
    fprintf('   P&O:    %.4f V\n', result.metrics.oscill_po);
    fprintf('   NN-GT:  %.4f V\n', result.metrics.oscill_nn);
    if isfield(result.metrics, 'oscill_nn_vi')
        fprintf('   NN-VI Hybrid: %.4f V\n', result.metrics.oscill_nn_vi);
    end

    dG = diff(result.irradiance_cloudy);
    locs = find(abs(dG) > 50);
    fprintf('\n4. РАПТОВІ ЗМІНИ ОСВІТЛЕНОСТІ: %d подій\n', numel(locs));

    fprintf('\n');
end

fprintf('═════════════════════════════════════════\n');
fprintf('=== ЗАГАЛЬНЕ ПОРІВНЯННЯ ===\n');
fprintf('═════════════════════════════════════════\n\n');

N = length(all_results);
po_eff  = zeros(1, N);
nn_eff  = zeros(1, N);
po_err  = zeros(1, N);
nn_err  = zeros(1, N);
has_vi  = isfield(all_results{1}.metrics, 'efficiency_nn_vi');
nn_vi_eff = zeros(1, N);
nn_vi_err = zeros(1, N);

for i = 1:N
    po_eff(i) = all_results{i}.metrics.efficiency_po;
    nn_eff(i) = all_results{i}.metrics.efficiency_nn;
    po_err(i) = all_results{i}.metrics.error_po;
    nn_err(i) = all_results{i}.metrics.error_nn;
    if has_vi
        nn_vi_eff(i) = all_results{i}.metrics.efficiency_nn_vi;
        nn_vi_err(i) = all_results{i}.metrics.error_nn_vi;
    end
end

fprintf('На основі %d сценаріїв:\n\n', N);
fprintf('Середня ефективність P&O:    %.2f%%\n', mean(po_eff));
fprintf('Середня ефективність NN-GT:  %.2f%%  (входи: G, T)\n', mean(nn_eff));
if has_vi
    fprintf('Середня ефективність NN-VI Hybrid:  %.2f%%\n', mean(nn_vi_eff));
end
fprintf('\nПриріст NN-GT над P&O: +%.2f%%\n', mean(nn_eff) - mean(po_eff));
if has_vi
    fprintf('Приріст NN-VI Hybrid над P&O: +%.2f%%\n', mean(nn_vi_eff) - mean(po_eff));
end

fprintf('\nСередня помилка P&O:    %.3f V\n', mean(po_err));
fprintf('Середня помилка NN-GT:  %.3f V\n', mean(nn_err));
if has_vi
    fprintf('Середня помилка NN-VI Hybrid:  %.3f V\n', mean(nn_vi_err));
end

fprintf('═════════════════════════════════════════\n');
fprintf('=== ВИСНОВКИ ===\n');
fprintf('═════════════════════════════════════════\n\n');
fprintf('1. Алгоритм NN-GT використовує освітленість G та температуру T —\n');
fprintf('   неприпустимо в реальній системі без окремого піранометра.\n');
    fprintf('2. Алгоритм NN-VI Hybrid використовує прогноз NN, але коригує його\n');
    fprintf('   локальною P&O логікою, якщо крок призводить до втрати потужності.\n');
fprintf('3. P&O простий і надійний, але має осциляції навколо робочої точки.\n');
fprintf('4. На швидких змінах хмарності P&O втрачає більше енергії через запізнення.\n');

report_file = fullfile(analysis_dir, 'analysis_report.txt');
fid = fopen(report_file, 'w');

fprintf(fid, 'ЗВІТ АНАЛІЗУ MPPT АЛГОРИТМІВ\n');
fprintf(fid, '============================\n\n');
fprintf(fid, 'ДАТА АНАЛІЗУ: %s\n\n', datestr(now));

for i = 1:N
    r = all_results{i};
    fprintf(fid, '%s\n', r.scenario_name);
    fprintf(fid, '  P&O:   %.2f Wh (%.2f%%), error=%.3f V\n', ...
        r.metrics.energy_po, r.metrics.efficiency_po, r.metrics.error_po);
    fprintf(fid, '  NN-GT: %.2f Wh (%.2f%%), error=%.3f V  [входи: G, T]\n', ...
        r.metrics.energy_nn, r.metrics.efficiency_nn, r.metrics.error_nn);
    if isfield(r.metrics, 'energy_nn_vi')
        fprintf(fid, '  NN-VI Hybrid: %.2f Wh (%.2f%%), error=%.3f V  [NN + локальна P&O корекція]\n', ...
            r.metrics.energy_nn_vi, r.metrics.efficiency_nn_vi, r.metrics.error_nn_vi);
    end
    fprintf(fid, '\n');
end

fprintf(fid, 'СЕРЕДНІ МЕТРИКИ\n');
fprintf(fid, 'P&O   ефективність: %.2f%%\n', mean(po_eff));
fprintf(fid, 'NN-GT ефективність: %.2f%%\n', mean(nn_eff));
if has_vi
    fprintf(fid, 'NN-VI Hybrid ефективність: %.2f%%\n', mean(nn_vi_eff));
end
fprintf(fid, 'P&O   помилка: %.3f V\n', mean(po_err));
fprintf(fid, 'NN-GT помилка: %.3f V\n', mean(nn_err));
if has_vi
    fprintf(fid, 'NN-VI Hybrid помилка: %.3f V\n', mean(nn_vi_err));
end

fclose(fid);

fprintf('✓ Результати експортовані в analysis/analysis_report.txt\n\n');
fprintf('=== АНАЛІЗ ЗАВЕРШЕНО ===\n');
