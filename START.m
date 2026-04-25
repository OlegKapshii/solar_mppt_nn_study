clear; close all; clc;

this_dir = fileparts(mfilename('fullpath'));
if isempty(this_dir)
    this_dir = pwd;
end

if isfolder(fullfile(this_dir, 'solar_model'))
    project_dir = this_dir;
else
    project_dir = fullfile(this_dir, 'full_system');
end

addpath(fullfile(project_dir, 'solar_model'));
addpath(fullfile(project_dir, 'cloud_model'));
addpath(fullfile(project_dir, 'mppt_classical'));
addpath(fullfile(project_dir, 'neural_network'));
addpath(fullfile(project_dir, 'data_generation'));
addpath(fullfile(project_dir, 'simulation'));
addpath(fullfile(project_dir, 'analysis'));

fprintf('╔════════════════════════════════════════════════════════════════╗\n');
fprintf('║  Симуляція MPPT систем: P&O vs NN-GT vs NN-VI                ║\n');
fprintf('║  Порівняння ефективності та інженерної коректності            ║\n');
fprintf('╚════════════════════════════════════════════════════════════════╝\n\n');

fprintf('Доступні опції:\n\n');
fprintf('1. generate_training_data()      - Генерація даних для NN-GT (G,T -> Vopt)\n');
fprintf('2. run_full_simulation           - Запуск симуляції P&O, NN-GT, NN-VI\n');
fprintf('3. compare_algorithms            - Порівняння трьох алгоритмів на 6 сценаріях\n');
fprintf('4. analyze_results               - Аналіз результатів порівняння\n\n');

fprintf('РЕКОМЕНДОВАНА ПОСЛІДОВНІСТЬ:\n');
fprintf('├─ 1. Запустіть: generate_training_data()\n');
fprintf('├─ 2. Запустіть: run_full_simulation\n');
fprintf('├─ 3. Запустіть: compare_algorithms\n');
fprintf('└─ 4. Запустіть: analyze_results\n\n');

fprintf('ПОЧАТКОВІ СЦЕНАРІЇ АНАЛІЗУ:\n');
fprintf('├─ Аналіз параметрів P&O:\n');
fprintf('│  └─ Змініть dV_step у mppt_po.m (0.2, 0.5, 1.0, 2.0 V)\n');
fprintf('│     та спостерігайте як це впливає на енергію\n\n');
fprintf('├─ Аналіз архітектури NN:\n');
fprintf('│  └─ Змініть розміри шарів у nn_init.m або nn_init_vi.m\n');
fprintf('│     та проаналізуйте вплив на точність\n\n');
fprintf('├─ Аналіз різних погодніх сценаріїв:\n');
fprintf('│  └─ Змінюйте ''cloud'' параметр: clear, gradual, sudden, frequent, mixed\n\n');

fprintf('├─ Аналіз впливу температури:\n');
fprintf('│  └─ Змініть T_panel діапазон у run_full_simulation.m\n\n');

fprintf('ФАЙЛИ ДЛЯ ЧИТАННЯ:\n');
fprintf('├─ docs/README.md              - Загальний опис проекту\n');
fprintf('├─ docs/architecture.md        - Архітектура системи\n');
fprintf('├─ docs/classical_mppt.md      - Опис P&O алгоритму\n');
fprintf('└─ docs/neural_network_mppt.md - Опис нейромережевого MPPT\n\n');

fprintf('СТРУКТУРА РЕЗУЛЬТАТІВ:\n');
fprintf('├─ neural_network/trained_network.mat    - Натренована мережа NN-GT\n');
fprintf('├─ neural_network/trained_network_vi_v2.mat - Натренована мережа NN-VI\n');
fprintf('├─ data_generation/training_data.mat     - Дані для тренування NN-GT\n');
fprintf('├─ data_generation/training_data_vi_v2.mat  - Дані для тренування NN-VI\n');
fprintf('├─ simulation/simulation_results.mat     - Результати однієї симуляції\n');
fprintf('├─ simulation/comparison_results.mat     - Результати порівняння\n');
fprintf('└─ analysis/analysis_report.txt          - Текстовий звіт\n\n');

fprintf('═══════════════════════════════════════════════════════════════\n\n');

fprintf('Введіть номер опції (1-4) або натисніть Enter для завершення:\n');
choice = input('> ', 's');

switch choice
    case '1'
        generate_training_data(200);
    case '2'
        run_full_simulation;
    case '3'
        compare_algorithms;
    case '4'
        analyze_results;
    otherwise
        fprintf('Завершено.\n');
end
