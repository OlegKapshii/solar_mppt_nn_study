function E_kWh = integrate_energy(P_watts, dt_s)
%INTEGRATE_ENERGY  Інтегрує потужність [Вт] за часом [с] у енергію [кВт·год].
%
%   E_kWh = integrate_energy(P_watts, dt_s)
%
%   Формула: E = (Σ P_i) · dt / 3600 / 1000

    E_kWh = sum(P_watts) * dt_s / 3600 / 1000;
end
