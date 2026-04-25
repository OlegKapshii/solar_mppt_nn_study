function [G_out, fast_info] = apply_fast_cloud_events(t_hours, G_in, mode, seed, event_window)
% APPLY_FAST_CLOUD_EVENTS  Накладає короткі різкі провали від швидких малих хмар.
%
% Синтаксис:
%   [G_out, fast_info] = apply_fast_cloud_events(t_hours, G_in)
%   [G_out, fast_info] = apply_fast_cloud_events(t_hours, G_in, mode, seed, event_window)
%
% Параметри:
%   t_hours      - часовий вектор [год]
%   G_in         - вхідна освітленість [Вт/м^2]
%   mode         - 'off' | 'mild' | 'strong' (за замовчуванням 'mild')
%   seed         - зерно RNG (за замовчуванням 123)
%   event_window - [t_start t_end], години активності швидких хмар (за замовчуванням [10 14])
%
% Вихід:
%   G_out        - освітленість з урахуванням швидких хмар [Вт/м^2]
%   fast_info    - службова структура: фактор, кількість подій, їх центри/тривалості/глибини

    if nargin < 3 || isempty(mode), mode = 'mild'; end
    if nargin < 4 || isempty(seed), seed = 123; end
    if nargin < 5 || isempty(event_window), event_window = [10 14]; end

    G_out = G_in;
    fast_info.factor = ones(size(t_hours));
    fast_info.num_events = 0;
    fast_info.centers = [];
    fast_info.durations_s = [];
    fast_info.depths = [];

    if strcmpi(mode, 'off')
        return;
    end

    rng(seed, 'twister');

    % Типові параметри подій: короткі, різкі, але фізично правдоподібні.
    switch lower(mode)
        case 'mild'
            events_per_hour = 3.0;
            depth_min = 0.10; depth_max = 0.35;
            dur_min_s = 30;   dur_max_s = 120;
        case 'strong'
            events_per_hour = 6.0;
            depth_min = 0.20; depth_max = 0.60;
            dur_min_s = 20;   dur_max_s = 150;
        otherwise
            error('apply_fast_cloud_events:BadMode', 'mode must be off|mild|strong');
    end

    t0 = event_window(1);
    t1 = event_window(2);
    if t1 <= t0
        return;
    end

    window_len_h = t1 - t0;

    % Кількість подій ~ Пуассон.
    lam = events_per_hour * window_len_h;
    num_events = local_poissrnd(lam);
    fast_info.num_events = num_events;

    factor = ones(size(t_hours));

    for k = 1:num_events
        center_h = t0 + window_len_h * rand();
        dur_s = dur_min_s + (dur_max_s - dur_min_s) * rand();
        depth = depth_min + (depth_max - depth_min) * rand();

        dur_h = dur_s / 3600;
        half_w = dur_h / 2;

        % Трикутний провал: швидкий фронт -> мінімум -> швидке відновлення.
        w = max(0, 1 - abs(t_hours - center_h) / max(half_w, eps));
        event_factor = 1 - depth * w;
        factor = factor .* event_factor;

        fast_info.centers(end+1) = center_h; %#ok<AGROW>
        fast_info.durations_s(end+1) = dur_s; %#ok<AGROW>
        fast_info.depths(end+1) = depth; %#ok<AGROW>
    end

    factor = max(0.05, min(1.0, factor));
    factor(G_in < 1.0) = 1.0;

    G_out = G_in .* factor;
    fast_info.factor = factor;
end

function n = local_poissrnd(lambda)
% Простий Poisson sampler без Statistics Toolbox.
    if lambda <= 0
        n = 0;
        return;
    end
    L = exp(-lambda);
    k = 0;
    p = 1;
    while p > L
        k = k + 1;
        p = p * rand();
    end
    n = k - 1;
end
