% Збережи цей файл як solar_sim.m і запусти
clear all; clc;

% --- 1. ПАРАМЕТРИ СИСТЕМИ ---
lat = 49.8;     lon = 24.0;     % Координати (напр. Львів)
tilt = 35.0;    az = 180.0;     % Нахил панелі та азимут (південь)
A_mod = 1.6;    eta_ref = 0.18; % Площа і базовий ККД панелі
gammaT = -0.004; NOCT = 45.0;   % Температурні характеристики
T_ref = 25.0;   rho_g = 0.2;    % Базова температура та альбедо землі
tau = 0.15;     f_diff = 0.10;  % Прозорість неба та розсіяне світло
dayOfYear = 172;                % Літнє сонцестояння

% --- 2. ГЕНЕРАЦІЯ ЧАСУ ТА ПОГОДИ ---
t_hours = 0 : (5/60) : 24;      % Від 0 до 24 годин з кроком 5 хвилин
t_sec = t_hours * 3600;
Tamb = 25 + 10*sin(2*pi*t_hours/24 - pi/2); % Температура повітря

% --- 3. ВЕКТОРИЗОВАНА СИМУЛЯЦІЯ (без функцій і циклів) ---
I_sc = 1367;
deg2rad = pi/180;
latr = lat*deg2rad; tiltr = tilt*deg2rad; azr = az*deg2rad;

E0 = 1 + 0.033*cos(2*pi*dayOfYear/365);
I0n = I_sc * E0;
B = 2*pi*(dayOfYear - 81)/364;
EoT_min = 9.87*sin(2*B) - 7.53*cos(B) - 1.5*sin(B);

h_utc = t_sec/3600;
solar_minutes = h_utc*60 + lon*4 + EoT_min;
solar_hours = solar_minutes/60;
H = deg2rad * (15*(solar_hours - 12));

delta = deg2rad * (23.45*sin(deg2rad*(360*(284 + dayOfYear)/365)));

x = cos(delta).*sin(H);
y = cos(latr).*sin(delta) - sin(latr).*cos(delta).*cos(H);
z = sin(latr).*sin(delta) + cos(latr).*cos(delta).*cos(H);

z(z > 1) = 1; z(z < -1) = -1; % Захист від математичних похибок

mu = z;
mu(mu < 0) = 0; % Вночі сонця немає

alt_deg = asin(z)/deg2rad;
theta_z_deg = 90 - alt_deg;
theta_z_deg(mu == 0) = 90;

% Розрахунок Air Mass (з уникненням ділення на нуль вночі)
AM = zeros(size(mu));
idx = (mu > 0);
AM(idx) = 1 ./ (mu(idx) + 0.50572 .* ((96.07995 - theta_z_deg(idx)).^(-1.6364)));
AM(~idx) = inf;

DNI = I0n .* exp(-tau .* AM);
DNI(~idx) = 0;

DHI = f_diff .* DNI;
GHI = DNI .* mu + DHI;

nx = sin(tiltr)*sin(azr);
ny = sin(tiltr)*cos(azr);
nz = cos(tiltr);

cosInc = x.*nx + y.*ny + z.*nz;
cosInc(cosInc < 0) = 0;

F_sky = (1 + cos(tiltr))/2;
G_ground = GHI .* rho_g .* (1 - cos(tiltr))/2;
G_POA = DNI .* cosInc + DHI .* F_sky + G_ground;

Tcell = Tamb + (NOCT - 20)/800 .* G_POA;
eta = eta_ref .* (1 + gammaT .* (Tcell - T_ref));
eta(eta < 0) = 0;

P = G_POA .* A_mod .* eta;

% --- 4. ПОБУДОВА ГРАФІКІВ ---
figure(1);
subplot(2,1,1);
plot(t_hours, G_POA, 'b', 'LineWidth', 2);
grid on;
title('Освітленість панелі протягом дня (G_{POA})');
xlabel('Час (години)'); ylabel('Освітленість (W/m^2)');
xlim([0 24]);

subplot(2,1,2);
plot(t_hours, P, 'r', 'LineWidth', 2);
grid on;
title('Базова вироблена потужність');
xlabel('Час (години)'); ylabel('Потужність (W)');
xlim([0 24]);
