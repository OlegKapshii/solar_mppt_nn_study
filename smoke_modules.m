% smoke_modules.m — швидка перевірка всіх фізичних модулів.
% Запуск:  octave-cli --no-gui --eval "run('smoke_modules.m')"

addpath('modules');

cfg = config();

fprintf('=== Smoke test модулів ===\n');

% --- ambient ---
t = 0:0.5:24;
T = ambient(t, cfg);
fprintf('Ambient T: min=%.1f max=%.1f @ t_max=%.1f h\n', ...
        min(T), max(T), t(find(T==max(T),1)));
assert(max(T) > cfg.ambient.T_mean_C);
assert(min(T) < cfg.ambient.T_mean_C);

% --- irradiance ---
[G, info] = irradiance_clearsky(t, cfg);
fprintf('Irradiance: max=%.1f W/m^2 @ t=%.1f h\n', max(G), t(find(G==max(G),1)));
assert(max(G) > 500 && max(G) < 1400, 'Max G out of sane range');
assert(G(1) == 0 && G(end) == 0, 'Night irradiance must be 0');

% --- clouds ---
cf = clouds_markov(t, cfg);
fprintf('Cloud factor: mean=%.2f, min=%.2f, max=%.2f\n', mean(cf), min(cf), max(cf));
assert(all(cf >= 0) && all(cf <= 1.001));

% --- pv_panel @ STC ---
cfg_stc = cfg;
Voc_arr = cfg.panel.Voc_stc * cfg.array.Ns_panels;
V = linspace(0, Voc_arr, 200);
[I, P] = pv_panel(V, 1000, 25, cfg);
[Pmax, imax] = max(P);
fprintf('Panel @ STC: Voc=%.1f V, Isc=%.2f A, Vmpp=%.1f V, Pmpp=%.0f W\n', ...
        Voc_arr, I(1), V(imax), Pmax);
fprintf('  Expected: Voc=329, Vmpp=263, Pmpp~=4000 W for 10x2 array\n');

% --- pv_mpp ---
[Vm, Im, Pm] = pv_mpp(1000, 25, cfg);
fprintf('MPP @ STC: V=%.2f I=%.2f P=%.1f\n', Vm, Im, Pm);

[Vm_cloudy, Im_cloudy, Pm_cloudy] = pv_mpp(300, 25, cfg);
fprintf('MPP @ 300 W/m^2: V=%.2f I=%.2f P=%.1f (should be ~30%% of STC)\n', ...
        Vm_cloudy, Im_cloudy, Pm_cloudy);

[Vm_hot, Im_hot, Pm_hot] = pv_mpp(1000, 60, cfg);
fprintf('MPP @ 60C: V=%.2f (lower than STC due to -Voc/T), P=%.1f\n', Vm_hot, Pm_hot);

fprintf('=== All assertions passed ===\n');
