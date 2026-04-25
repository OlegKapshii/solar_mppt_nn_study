% smoke_pipeline.m — інтеграційний тест: повний день з P&O і ідеальним.
%
% Запуск:
%   octave-cli --no-gui --eval "run('smoke_pipeline.m')"

addpath('modules'); addpath('trackers'); addpath('sim'); addpath('utils');

cfg = config();

fprintf('=== P&O — повний день ===\n');
tic;
r_po = run_simulation('full_day', @mppt_po, cfg);
fprintf('Виконано за %.2f с (%d кроків)\n', toc, r_po.N);

E_po  = integrate_energy(r_po.P, r_po.dt_s);
E_max = integrate_energy(r_po.P_mpp, r_po.dt_s);
fprintf('Енергія P&O:        %.3f кВт·год\n', E_po);
fprintf('Теоретич. максимум: %.3f кВт·год\n', E_max);
fprintf('Ефективність:       %.1f%%\n', 100*E_po/E_max);

fprintf('\n=== Ідеальний трекер (верхня межа) ===\n');
r_ideal = run_simulation('full_day', @mppt_ideal, cfg);
E_ideal = integrate_energy(r_ideal.P, r_ideal.dt_s);
fprintf('Енергія ідеал:      %.3f кВт·год\n', E_ideal);
fprintf('Співпадіння з P_mpp: %.2f%% (має бути ~100)\n', 100*E_ideal/E_max);

% Перевірка санітетs: ідеал і теоретичний максимум повинні майже збігатися
assert(abs(E_ideal - E_max)/E_max < 0.02, 'Ideal tracker must match P_mpp');
% P&O має бути нижчим за ідеал, але розумно високим
assert(E_po < E_ideal, 'P&O must be <= ideal');
assert(E_po > 0.7 * E_ideal, 'P&O too low (<70%% of ideal) — щось не так');

fprintf('\n=== Pipeline smoke test OK ===\n');
