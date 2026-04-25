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
    fprintf('   P&O MPPT: %.2f Wh (%.2f%%)\n', result.metrics.energy_po, result.metrics.efficiency_po);
    fprintf('   NN MPPT:  %.2f Wh (%.2f%%)\n', result.metrics.energy_nn, result.metrics.efficiency_nn);
    fprintf('   Оптимум:  %.2f Wh\n', result.metrics.energy_optimal);

    energy_diff = result.metrics.energy_nn - result.metrics.energy_po;
    energy_diff_pct = 100 * energy_diff / max(result.metrics.energy_po, eps);
    fprintf('   Перевага NN: %.2f Wh (%.2f%%)\n', energy_diff, energy_diff_pct);

    fprintf('\n2. ТОЧНІСТЬ (помилка напруги):\n');
    fprintf('   P&O: %.3f V\n', result.metrics.error_po);
    fprintf('   NN:  %.3f V\n', result.metrics.error_nn);
    fprintf('   Відносне покращення NN: %.1f%%\n', 100 * (result.metrics.error_po - result.metrics.error_nn) / max(result.metrics.error_po, eps));

    fprintf('\n3. СТАБІЛЬНІСТЬ (std(dV)):\n');
    fprintf('   P&O: %.4f V\n', result.metrics.oscill_po);
    fprintf('   NN:  %.4f V\n', result.metrics.oscill_nn);

    dG = diff(result.irradiance_cloudy);
    locs = find(abs(dG) > 50);
    fprintf('\n4. РАПТОВІ ЗМІНИ ОСВІТЛЕНОСТІ: %d подій\n', numel(locs));

    fprintf('\n');
end

fprintf('═════════════════════════════════════════\n');
fprintf('=== ЗАГАЛЬНЕ ПОРІВНЯННЯ ===\n');
fprintf('═════════════════════════════════════════\n\n');

N = length(all_results);
po_eff = zeros(1, N);
nn_eff = zeros(1, N);
po_err = zeros(1, N);
nn_err = zeros(1, N);

for i = 1:N
    po_eff(i) = all_results{i}.metrics.efficiency_po;
    nn_eff(i) = all_results{i}.metrics.efficiency_nn;
    po_err(i) = all_results{i}.metrics.error_po;
    nn_err(i) = all_results{i}.metrics.error_nn;
end

fprintf('На основі %d сценаріїв:\n\n', N);
fprintf('Середня ефективність P&O: %.2f%%\n', mean(po_eff));
fprintf('Середня ефективність NN:  %.2f%%\n', mean(nn_eff));
fprintf('Приріст NN: +%.2f%%\n\n', mean(nn_eff) - mean(po_eff));

fprintf('Середня помилка P&O: %.3f V\n', mean(po_err));
fprintf('Середня помилка NN:  %.3f V\n', mean(nn_err));
fprintf('Зниження помилки NN: %.1f%%\n\n', 100 * (mean(po_err) - mean(nn_err)) / max(mean(po_err), eps));

fprintf('═════════════════════════════════════════\n');
fprintf('=== ВИСНОВКИ ===\n');
fprintf('═════════════════════════════════════════\n\n');
fprintf('1. Алгоритм NN в середньому краще відслідковує MPP у змінній освітленості.\n');
fprintf('2. На швидких змінах хмарності P&O частіше втрачає енергію через запізнення.\n');
fprintf('3. P&O простіший, але має коливання навколо робочої точки.\n');

report_file = fullfile(analysis_dir, 'analysis_report.txt');
fid = fopen(report_file, 'w');

fprintf(fid, 'ЗВІТ АНАЛІЗУ MPPT АЛГОРИТМІВ\n');
fprintf(fid, '============================\n\n');
fprintf(fid, 'ДАТА АНАЛІЗУ: %s\n\n', datestr(now));

for i = 1:N
    r = all_results{i};
    fprintf(fid, '%s\n', r.scenario_name);
    fprintf(fid, '  P&O: %.2f Wh (%.2f%%), error=%.3f V\n', ...
        r.metrics.energy_po, r.metrics.efficiency_po, r.metrics.error_po);
    fprintf(fid, '  NN:  %.2f Wh (%.2f%%), error=%.3f V\n\n', ...
        r.metrics.energy_nn, r.metrics.efficiency_nn, r.metrics.error_nn);
end

fprintf(fid, 'СЕРЕДНІ МЕТРИКИ\n');
fprintf(fid, 'P&O ефективність: %.2f%%\n', mean(po_eff));
fprintf(fid, 'NN  ефективність: %.2f%%\n', mean(nn_eff));
fprintf(fid, 'P&O помилка: %.3f V\n', mean(po_err));
fprintf(fid, 'NN  помилка: %.3f V\n', mean(nn_err));

fclose(fid);

fprintf('✓ Результати експортовані в analysis/analysis_report.txt\n\n');
fprintf('=== АНАЛІЗ ЗАВЕРШЕНО ===\n');
