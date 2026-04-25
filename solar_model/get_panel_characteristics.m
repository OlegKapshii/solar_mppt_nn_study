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
    panel.area = 1.425;              % Площа в м² (1.425 для KC200GT, datasheet)

    % Внутрішня структура модуля
    panel.Ns = 54;                   % Послідовних клітин у модулі (KC200GT)

    % Температурні коефіцієнти (для розрахунку при іншій температурі)
    panel.alpha_I = 0.00318;         % Коефіцієнт для Isc [A/°C] (datasheet)
    panel.beta_V = -0.123;           % Коефіцієнт для Voc [V/°C]
    panel.gamma_P = -0.0041;         % Коефіцієнт для Pmax [1/°C]
    panel.NOCT = 47;                 % Nominal Operating Cell Temperature [°C]
    
    % Виробник
    panel.name = 'KC200GT';
    panel.manufacturer = 'Kyocera';
    panel.type = 'Monocrystalline';
    
    % Конфігурація масиву: 10 послідовно × 2 паралельно (20 панелей).
    % Це реалістичніше за попередні 2×10 — масив 4 кВт працює на ~263 В
    % і ~15 А, що відповідає типовим residential string-інверторам.
    % (Стара конфігурація 2×10 давала 53 В × 76 А — нереалістично великий
    % струм через інвертор, потрібні товсті дроти, низька напруга.)
    panel.series   = 10;             % Панелі послідовно (множить напругу)
    panel.parallel = 2;               % Панелі паралельно (множить струм)

    % Параметри масиву
    panel.array_P_max = panel.P_max_stc * panel.series * panel.parallel;  % 4000 W
    panel.array_V_oc  = panel.V_oc_stc * panel.series;     % 329 V
    panel.array_V_mp  = panel.V_mp_stc * panel.series;     % 263 V
    panel.array_I_sc  = panel.I_sc_stc * panel.parallel;   % 17.1 A
    panel.array_I_mp  = panel.I_mp_stc * panel.parallel;   % 15.22 A

end
