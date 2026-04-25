% Розрахунок сонячної радіації
% Спрощена clear-sky модель для навчальної симуляції
% Вихід: глобальна радіація на горизонтальній площині [W/m^2]

function irradiance = get_solar_irradiance(year_day, hour, minute)
    % Входи:
    %   year_day - день року (1-365)
    %   hour - година (0-23)
    %   minute - хвилина (0-59)
    %
    % Вихід:
    %   irradiance - глобальна сонячна радіація [W/m²]
    
    latitude = 49.84;
    longitude = 24.03;

    % Спрощене врахування переходу на літній час
    if year_day >= 80 && year_day <= 300
        timezone = 3;
    else
        timezone = 2;
    end

    lstm = timezone * 15; % локальний стандартний меридіан

    t_local = hour + minute / 60;

    B = 360 * (year_day - 81) / 364;
    eot = 9.87 * sind(2 * B) - 7.53 * cosd(B) - 1.5 * sind(B); % хвилини

    time_correction = eot + 4 * (longitude - lstm); % хвилини
    solar_time = t_local + time_correction / 60;

    declination = 23.45 * sind(360 * (284 + year_day) / 365);
    hour_angle = 15 * (solar_time - 12);

    sin_altitude = sind(latitude) * sind(declination) + ...
                   cosd(latitude) * cosd(declination) * cosd(hour_angle);

    if sin_altitude <= 0
        irradiance = 0;
        return;
    end

    G0 = 1367 * (1 + 0.033 * cosd(360 * year_day / 365));
    air_mass = 1 / max(sin_altitude, 0.05);

    tau_b = 0.75;
    dni = G0 * (tau_b ^ air_mass);
    dhi = 0.12 * G0 * sin_altitude;

    irradiance = dni * sin_altitude + dhi;
    irradiance = max(0, min(1000, irradiance));
end
