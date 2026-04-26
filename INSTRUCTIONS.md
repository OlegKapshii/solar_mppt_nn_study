# Інструкції

## Вступ

Проєкт порівнює MPPT-алгоритми для масиву 10s x 2p (KC200GT):

1. P&O (базовий)
2. P&O+Pyr (адаптивний)
3. NN-GT (G,T -> Vopt)
4. NN-VI Pure (V,V_prev,I,P,dV,dP -> deltaV)
5. NN-VI Hybrid (NN-VI + локальна P&O логіка)

Мета: коректно порівняти алгоритми у базових і stress-режимах та сформулювати межі їх застосовності.

## Швидкий старт

```matlab
START
```

У меню START є 5 кроків:

1. `generate_training_data()`
2. `run_full_simulation`
3. `compare_algorithms`
4. `analyze_results`
5. `nn_advantage_experiments`

Крок 5 запускає окремий stress-run, де можна явно побачити режими, у яких NN перемагає.

## Що запускає кожний крок

### Крок 1: Генерація train-data

- Формує дані для NN-GT.
- Для NN-VI v5 дані будуть створені автоматично у кроках 2/3 за потреби.

### Крок 2: Одна повна симуляція

- Виконує базовий робочий прогін системи.
- Перевіряє сумісність і за потреби перенавчає NN моделі.

### Крок 3: Базове порівняння

- Порівнює всі алгоритми на стандартному наборі сценаріїв.
- Формує `simulation/comparison_results.mat`.

### Крок 4: Аналіз результатів

- Створює текстовий звіт `analysis/analysis_report.txt`.

### Крок 5: NN advantage demo

- Окремий stress-бенчмарк із повільним оновленням, шумом і затримкою.
- Формує `analysis/nn_advantage_report.txt`.

## Базові висновки, які треба перевірити

1. У стандартних сценаріях класичні алгоритми залишаються найсильнішими.
2. NN-VI Pure після v5 є працездатною, але зазвичай слабшою за Hybrid.
3. У degraded-feedback режимах NN-GT або NN-VI Hybrid можуть вигравати.

## Дослідження

### Дослідження 1: Чутливість P&O до кроку

1. Змінити `dV_step` у `mppt_classical/mppt_po.m` (0.2, 0.5, 1.0, 2.0).
2. Повторити кроки START 2-4.
3. Порівняти енергію, ефективність і MAE.

### Дослідження 2: Чутливість NN-VI до параметрів тренування

1. Змінити параметри у `neural_network/nn_init_vi.m` (наприклад `learning_rate`, `num_epochs`).
2. Повторити кроки START 3-4.
3. Окремо порівняти Pure vs Hybrid.

### Дослідження 3: Де NN перемагає

1. Запустити START крок 5.
2. Зафіксувати сценарії-переможці з `analysis/nn_advantage_report.txt`.
3. Пояснити, який фактор дав виграш (slow update, noise, delay).

### Дослідження 4: Межі валідності висновків

1. Порівняти висновки з `analysis/analysis_report.txt` і `analysis/nn_advantage_report.txt`.
2. Окремо вказати, що `partial shade surrogate` є наближенням, а не повною multi-peak фізичною моделлю.

## Актуальні файли результатів

- `neural_network/trained_network.mat`
- `neural_network/trained_network_vi_v5.mat`
- `data_generation/training_data.mat`
- `data_generation/training_data_vi_v5.mat`
- `simulation/comparison_results.mat`
- `analysis/analysis_report.txt`
- `analysis/nn_advantage_report.txt`

## FAQ

### Чому NN не завжди краща за P&O?

Бо у базових умовах класика дуже сильна. Перевага NN з'являється переважно у складних режимах із поганим feedback.

### Чи правда, що P&O може втрачати до 10%?

Так, але тільки у специфічних stress-режимах. Це не універсальна оцінка для нормального режиму.

### Де змінювати локацію/радіацію?

У `solar_model/get_solar_irradiance.m`.

### Де змінювати часове вікно симуляції?

У відповідному simulation-скрипті (`run_full_simulation.m` або `compare_algorithms.m`) через `start_hour`, `end_hour`.
