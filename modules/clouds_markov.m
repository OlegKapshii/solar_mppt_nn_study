function cloud_factor = clouds_markov(t_hours, cfg)
%CLOUDS_MARKOV  Хмарний фактор як двостанова марковська модель.
%
%   cloud_factor = clouds_markov(t_hours, cfg)
%
%   Повертає вектор множників [0..1] для масштабування G_POA.
%   Значення 1 — ясно, <1 — хмара.
%
%   Модель:
%     - Два стани: «ясно» (cloud_factor=1) і «хмарно».
%     - У хмарному стані множник випадково вибирається з діапазону
%       cfg.clouds.attenuation_range, наприклад [0.2, 0.7].
%     - Переходи між станами на кожному кроці з імовірностями
%       p_clear_to_cloudy та p_cloudy_to_clear.
%     - Ці ймовірності додатково масштабуються так, щоб середня
%       хмарність наближалася до avg_cloudiness_pct у стаціонарному режимі.
%     - На межах станів — згладжування, щоб уникнути ступінчастих стрибків.
%     - Поза active_hours хмарність вимкнена (ніч, ранок, пізній вечір).
%
%   Аргументи:
%     t_hours — вектор часу [год]
%     cfg     — struct з config()

    if nargin < 2, cfg = config(); end

    rng(cfg.clouds.seed);

    n = numel(t_hours);
    cloud_factor = ones(1, n);

    % Імовірності переходу, скалеровані під задану середню хмарність.
    % Стаціонарна ймовірність хмарного стану:
    %   pi_cloudy = p_c2c / (p_c2c + p_cl2c)
    % Щоб отримати avg_cloudiness_pct — масштабуємо p_clear_to_cloudy.
    target_frac = max(0, min(0.95, cfg.clouds.avg_cloudiness_pct / 100));
    base_p_cl2c = cfg.clouds.p_clear_to_cloudy;
    base_p_c2c  = cfg.clouds.p_cloudy_to_clear;
    if target_frac > 0
        p_cl2c = target_frac * base_p_c2c / max(1 - target_frac, 1e-6);
        p_cl2c = min(p_cl2c, 0.5);
    else
        p_cl2c = 0;
    end
    p_c2c = base_p_c2c;

    % Поточний стан (0=ясно, 1=хмарно) і цільовий множник
    state = 0;
    target_att = 1;
    smooth_N = max(1, round(cfg.clouds.transition_steps));
    attn_lo = cfg.clouds.attenuation_range(1);
    attn_hi = cfg.clouds.attenuation_range(2);

    active_lo = cfg.clouds.active_hours(1);
    active_hi = cfg.clouds.active_hours(2);

    raw = ones(1, n);
    for i = 1:n
        t = t_hours(i);
        in_window = (t >= active_lo && t <= active_hi);

        if ~in_window
            state = 0;
            target_att = 1;
            raw(i) = 1;
            continue;
        end

        if state == 0
            if rand() < p_cl2c
                state = 1;
                target_att = attn_lo + (attn_hi - attn_lo) * rand();
            end
        else
            if rand() < p_c2c
                state = 0;
                target_att = 1;
            end
        end
        raw(i) = target_att;
    end

    % Згладжування — ковзне середнє шириною smooth_N, щоб прибрати
    % різкі ступені між станами (імітуємо плавність краю хмари).
    if smooth_N > 1
        kernel = ones(1, smooth_N) / smooth_N;
        cloud_factor = conv(raw, kernel, 'same');
    else
        cloud_factor = raw;
    end

    cloud_factor = max(0, min(1, cloud_factor));
end
