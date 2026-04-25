function T_amb = ambient(t_hours, cfg)
%AMBIENT  Температура повітря як синусоїда з максимумом о T_peak_h.
%
%   T_amb = ambient(t_hours, cfg)
%
%   Синусоїдальна модель:
%       T_amb(t) = T_mean + T_ampl * sin(2π(t - T_peak + 6)/24)
%
%   За рахунок зсуву на 6 годин максимум припадає саме на T_peak_h
%   (типово 15:00), а мінімум — близько 3:00 ранку.

    if nargin < 2, cfg = config(); end

    Tm   = cfg.ambient.T_mean_C;
    Ta   = cfg.ambient.T_ampl_C;
    Tpk  = cfg.ambient.T_peak_h;

    T_amb = Tm + Ta * sin(2*pi*(t_hours - Tpk + 6)/24);
end
