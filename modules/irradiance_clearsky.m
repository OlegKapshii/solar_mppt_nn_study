function [G_POA, info] = irradiance_clearsky(t_hours, cfg)
%IRRADIANCE_CLEARSKY  Клір-скай модель освітленості на нахиленій панелі.
%
%   [G_POA, info] = irradiance_clearsky(t_hours, cfg)
%
%   Повертає:
%     G_POA  — освітленість у площині панелі [Вт/м²], вектор
%     info   — struct з допоміжними величинами (DNI, DHI, mu, alt_deg)
%
%   Модель:
%     1. Позиція сонця: декліна-ція, часовий кут, рівняння часу (EoT).
%     2. Air Mass — формула Kasten-Young (1989).
%     3. DNI через Beer-Lambert з турбідністю τ.
%     4. DHI = f_diff * DNI (ізотропне наближення).
%     5. POA з геометрії падіння на нахилену площину + дифузна від неба
%        (Liu-Jordan F_sky) + відбита від землі (альбедо).
%
%   Формули відповідають Duffie & Beckman, «Solar Engineering of Thermal
%   Processes», а також draft_solar.txt з початкових матеріалів.

    if nargin < 2, cfg = config(); end

    % ------ Розпаковка параметрів ------
    lat  = cfg.geo.latitude_deg;
    lon  = cfg.geo.longitude_deg;
    tilt = cfg.geo.tilt_deg;
    az   = cfg.geo.azimuth_deg;
    rho  = cfg.geo.albedo;
    n    = cfg.time.day_of_year;
    tau  = cfg.atm.turbidity;
    fdif = cfg.atm.diffuse_frac;
    Isc_solar = cfg.atm.solar_const;

    d2r  = pi/180;
    latr = lat*d2r; tiltr = tilt*d2r; azr = az*d2r;

    % ------ Часовий кут і декліна-ція ------
    % t_hours трактуємо як ЛОКАЛЬНИЙ СОНЯЧНИЙ час
    % (t=12 → сонячний полудень, пік освітленості).
    % Довгота і рівняння часу залишені в інформаційних полях info.
    E0 = 1 + 0.033*cos(2*pi*n/365);        % поправка на відстань Земля-Сонце
    I0n = Isc_solar .* E0;                 % позаатмосферна DNI

    B = 2*pi*(n - 81)/364;
    EoT_min = 9.87*sin(2*B) - 7.53*cos(B) - 1.5*sin(B);

    H = d2r * 15 * (t_hours - 12);         % часовий кут [рад] від сонячного часу

    delta = d2r * (23.45*sin(d2r*(360*(284 + n)/365)));

    % ------ Вектор сонця в локальній системі (ENU) ------
    x = cos(delta).*sin(H);
    y = cos(latr).*sin(delta) - sin(latr).*cos(delta).*cos(H);
    z = sin(latr).*sin(delta) + cos(latr).*cos(delta).*cos(H);

    z = min(1, max(-1, z));
    mu = z;
    mu(mu < 0) = 0;                        % нижче горизонту — сонця нема

    alt = asin(z);
    alt_deg = alt / d2r;
    theta_z_deg = 90 - alt_deg;
    theta_z_deg(mu == 0) = 90;

    % ------ Air Mass (Kasten-Young 1989) ------
    AM = zeros(size(mu));
    day_mask = (mu > 0);
    AM(day_mask) = 1 ./ (mu(day_mask) + ...
                         0.50572 .* (96.07995 - theta_z_deg(day_mask)).^(-1.6364));
    AM(~day_mask) = Inf;

    % ------ Clear-sky DNI / DHI / GHI ------
    DNI = I0n .* exp(-tau .* AM);
    DNI(~day_mask) = 0;
    DHI = fdif .* DNI;
    GHI = DNI .* mu + DHI;

    % ------ Геометрія падіння на панель ------
    nx = sin(tiltr)*sin(azr);
    ny = sin(tiltr)*cos(azr);
    nz = cos(tiltr);
    cosInc = x.*nx + y.*ny + z.*nz;
    cosInc = max(0, cosInc);               % задня сторона не приймає пряме

    F_sky = (1 + cos(tiltr))/2;
    G_ground = GHI .* rho .* (1 - cos(tiltr))/2;

    G_POA = DNI .* cosInc + DHI .* F_sky + G_ground;
    G_POA = max(0, G_POA);

    info = struct();
    info.DNI     = DNI;
    info.DHI     = DHI;
    info.GHI     = GHI;
    info.mu      = mu;
    info.alt_deg = alt_deg;
    info.cosInc  = cosInc;
    info.EoT_min = EoT_min;
    info.I0n     = I0n;
end
