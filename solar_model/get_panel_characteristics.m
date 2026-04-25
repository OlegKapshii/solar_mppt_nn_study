% KC200GT - Параметри сонячної панелі
% Це функція повертає параметри панелі в стандартних умовах тестування (STC)

function panel = get_panel_characteristics()
    % STC умови: 1000 W/m², 25°C, AM1.5
    
    % Номіналі панелі KC200GT (від datasheet)
    panel.P_max_stc = 200;           % Максимальна потужність при STC [W]
    panel.V_oc_stc = 32.9;           % Напруга холостого ходу [V]
    panel.V_mp_stc = 26.3;           % Напруга в точці максимальної потужності [V]
    panel.I_sc_stc = 8.55;           % Струм короткого замикання [A]
    panel.I_mp_stc = 7.61;           % Струм в точці максимальної потужності [A]
    panel.efficiency_stc = 0.1675;   % Ефективність при STC
    
    % Розміри панелі
    panel.area = 1.23 * 1.626;       % Площа в м² (приблизно для 200W панелі)
    
    % Температурні коефіцієнти (для розрахунку при іншій температурі)
    panel.alpha_I = 0.0032;          % Коефіцієнт для Isc [A/°C]
    panel.beta_V = -0.123;           % Коефіцієнт для Voc [V/°C]
    panel.gamma_P = -0.0041;         % Коефіцієнт для Pmax [1/°C]
    
    % Виробник
    panel.name = 'KC200GT';
    panel.manufacturer = 'Kyocera';
    panel.type = 'Monocrystalline';
    
    % Облік: 10x2 масив панелей (20 панелей)
    % Конфігурація: 10 паралельно, 2 послідовно
    panel.series = 2;                % Панелі послідовно
    panel.parallel = 10;             % Панелі паралельно
    
    % Параметри масиву
    panel.array_P_max = panel.P_max_stc * panel.series * panel.parallel;  % 4000 W
    panel.array_V_mp = panel.V_mp_stc * panel.series;   % 52.6 V
    panel.array_I_mp = panel.I_mp_stc * panel.parallel;  % 76.1 A
    
end
