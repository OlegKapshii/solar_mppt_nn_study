# full_system — Симуляція MPPT-трекерів (класичний P&O vs нейромережа)

Модульний Octave-каркас для курсової роботи **«Порівняння ефективності та обчислювальної складності класичних і нейромережевих алгоритмів MPPT в умовах мінливої освітленості»**.

## Структура

```
full_system/
├── config.m                — центральні параметри
├── README.md               — цей файл
│
├── modules/                — фізика
│   ├── irradiance_clearsky.m  — освітленість на нахиленій панелі
│   ├── clouds_markov.m        — хмари як марковська модель
│   ├── pv_panel.m             — однодіодна модель KC200GT
│   ├── pv_mpp.m               — пошук «справжньої» MPP
│   └── ambient.m              — температура повітря
│
├── trackers/               — алгоритми MPPT
│   ├── mppt_po.m              — класичний Perturb & Observe
│   ├── mppt_nn.m              — нейромережевий трекер
│   └── mppt_ideal.m           — оракул (теоретична межа)
│
├── nn/                     — нейромережа
│   ├── nn_init.m              — Xavier-ініціалізація
│   ├── nn_forward.m           — прямий прохід
│   ├── nn_backward.m          — backpropagation
│   ├── nn_generate_dataset.m  — генерація навчальних даних
│   ├── nn_train.m             — головний скрипт тренування
│   └── nn_weights.mat         — навчені ваги
│
├── sim/                    — симулятор
│   ├── run_simulation.m       — головна функція пайплайну
│   └── integrate_energy.m     — інтегрування потужності → кВт·год
│
├── experiments/            — готові сценарії
│   ├── exp1_full_day.m        — повний день з хмарністю
│   ├── exp2_transient.m       — швидкий хмарний перехід (drift P&O)
│   ├── exp3_sweep_cloudiness.m — свіп по хмарності
│   ├── exp4_sweep_po_step.m   — свіп V_step для P&O
│   ├── exp5_compute_cost.m    — обчислювальна складність
│   └── exp6_po_vs_nn.m        — зведене порівняння
│
├── utils/                  — допоміжне
│   ├── make_figure.m
│   ├── save_fig.m
│   └── setup_paths.m
│
├── results/                — графіки і CSV (створюється автоматично)
│
├── docs/                   — описи алгоритмів і висновки
│   ├── algorithm_po.md
│   ├── algorithm_nn.md
│   └── findings.md
│
├── smoke_modules.m         — швидкі тести фізичних модулів
├── smoke_pipeline.m        — інтеграційний тест
└── smoke_nn.m              — тест навчання NN
```

## Швидкий старт

### 1. Тренування нейромережі (один раз)

```
cd full_system
octave-cli --no-gui --eval "addpath('modules'); addpath('nn'); addpath('utils'); cfg = config(); nn_train(cfg);"
```

Після завершення з'являється файл `nn/nn_weights.mat`.

### 2. Запуск експериментів

```
octave-cli --no-gui --eval "run('experiments/exp1_full_day.m')"
octave-cli --no-gui --eval "run('experiments/exp2_transient.m')"
octave-cli --no-gui --eval "run('experiments/exp3_sweep_cloudiness.m')"
octave-cli --no-gui --eval "run('experiments/exp4_sweep_po_step.m')"
octave-cli --no-gui --eval "run('experiments/exp5_compute_cost.m')"
octave-cli --no-gui --eval "run('experiments/exp6_po_vs_nn.m')"
```

Графіки PNG потрапляють у `results/`. Часові ряди — у `results/exp*_timeseries.csv`.

### 3. Дослідження

Для дослідження параметра — копіюємо експеримент і змінюємо одну змінну в циклі. Приклад: «як хмарність впливає на ефективність» — це готовий **exp3**. Для свого свіпу:

```matlab
cfg = config();
cfg.po.V_step = 2.0;   % своє значення
result = run_simulation('full_day', @mppt_po, cfg);
E = integrate_energy(result.P, result.dt_s);
```

## Найважливіші параметри (з `config.m`)

| Поле | Опис |
|------|------|
| `cfg.geo.tilt_deg` | Нахил панелі |
| `cfg.time.day_of_year` | День (1..365) |
| `cfg.clouds.avg_cloudiness_pct` | Середня хмарність [%] |
| `cfg.po.V_step` | Крок збурення P&O [В] |
| `cfg.array.Ns_panels`, `Np_panels` | Конфігурація масиву |
| `cfg.nn.layers` | Архітектура мережі |
| `cfg.nn.epochs` | Кількість епох тренування |

## Опис алгоритмів

- [docs/algorithm_po.md](docs/algorithm_po.md) — класичний P&O
- [docs/algorithm_nn.md](docs/algorithm_nn.md) — нейромережа
- [docs/findings.md](docs/findings.md) — підсумкові висновки і числа

## Технічні нотатки

- Симуляція виконується з кроком 1 с (повний день = 86400 кроків).
- P&O оновлюється на кожному кроці (1 Гц) — реалістично для трекера в інверторі.
- NN зберігає ваги у `.mat`. Для перетренування — видалити файл або запустити `nn_train`.
- Ідеальний трекер дає верхню межу — те, чого ніколи не досягти реальним алгоритмом.
- Параметри панелі — KC200GT (200 Вт), масив 10×2 = 4 кВт.

## Залежності

- Octave 9.x або новіше
- Жодних зовнішніх пакетів не потрібно.
