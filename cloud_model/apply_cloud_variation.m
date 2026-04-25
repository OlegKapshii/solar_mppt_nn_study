% Застосування варіацій хмар до освітленості
% Модель генерує синтетичні зміни хмар на основі вибраного сценарію

function irradiance_cloudy = apply_cloud_variation(irradiance_clear, scenario, time_seconds)
    % Входи:
    %   irradiance_clear - чиста радіація без хмар [W/m²] (скаляр або вектор часу)
    %   scenario - тип сценарію хмар:
    %            'clear' - без хмар
    %            'gradual' - плавна зміна хмарності
    %            'sudden' - раптові зміни хмарності
    %            'frequent' - часті, короткі хмари
    %            'mixed' - комбінація раптових та плавних
    %   time_seconds - час в секундах від початку дня (скаляр або вектор)
    %
    % Вихід:
    %   irradiance_cloudy - радіація з урахуванням хмар [W/m²]
    
    if nargin < 2
        scenario = 'clear';
    end
    
    if nargin < 3 || isempty(time_seconds)
        if isscalar(irradiance_clear)
            time_seconds = 0;
        else
            time_seconds = 0:(numel(irradiance_clear)-1);
        end
    end

    time_vec = time_seconds(:)';

    if isscalar(irradiance_clear)
        irr_clear_vec = irradiance_clear * ones(size(time_vec));
    else
        irr_clear_vec = irradiance_clear(:)';
        if numel(irr_clear_vec) ~= numel(time_vec)
            error('Розміри irradiance_clear і time_seconds мають збігатися.');
        end
    end

    cloud_factor = ones(size(time_vec));
    % string() належить до пакета datatypes (не завантажений за замовч.).
    % Працюємо з char-масивом — у switch порівняння однаково коректне.
    if ischar(scenario) || (exist('isstring','builtin') && isstring(scenario))
        scenario = lower(char(scenario));
    end

    % Детермінований шум для відтворюваних експериментів
    rng(2026, 'twister');
    
    switch scenario
        case "clear"
            % Без хмар - коефіцієнт = 1.0 (без змін)
            cloud_factor = ones(size(time_vec));
            
        case "gradual"
            % Плавна зміна хмарності протягом дня
            cloud_factor = 0.72 + 0.22 * sin(2 * pi * time_vec / (2.5 * 3600));
            cloud_factor = max(0.45, min(1.0, cloud_factor));
            
        case "sudden"
            % Раптові зміни хмарності (стрибки)
            block = floor(time_vec / (10 * 60)) + 1;
            n_blocks = max(block);
            block_levels = 0.25 + 0.7 * rand(1, n_blocks);
            cloud_factor = block_levels(block);
            
        case "frequent"
            % Часті, короткі хмари (2-5 хв кожна)
            pulse = sign(sin(2 * pi * time_vec / (180)));
            cloud_factor = 0.75 - 0.25 * (pulse > 0) - 0.08 * (pulse <= 0);
            cloud_factor = movmean(cloud_factor, 7);
            
        case "mixed"
            % Комбінація раптових змін та плавних коливань
            smooth = 0.68 + 0.22 * sin(2 * pi * time_vec / (3.5 * 3600));
            block = floor(time_vec / (12 * 60)) + 1;
            n_blocks = max(block);
            block_levels = 0.30 + 0.65 * rand(1, n_blocks);
            sudden = block_levels(block);
            cloud_factor = 0.65 * smooth + 0.35 * sudden;
            cloud_factor = movmean(cloud_factor, 5);
            
        otherwise
            warning('Unknown scenario: %s. Using clear sky.', scenario);
            cloud_factor = ones(size(time_vec));
    end
    
    % Застосуємо хмарний коефіцієнт до радіації
    cloud_factor = max(0.2, min(1.0, cloud_factor));
    irradiance_cloudy = irr_clear_vec .* cloud_factor;
    
    % Обмеження максимальної радіації
    irradiance_cloudy = min(irradiance_cloudy, 1000);

    if isscalar(irradiance_clear)
        irradiance_cloudy = irradiance_cloudy(1);
    else
        irradiance_cloudy = reshape(irradiance_cloudy, size(irradiance_clear));
    end
    
end
