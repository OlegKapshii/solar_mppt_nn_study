# Архітектура системи

## Загальна схема

```
Сонячна геометрія (Львів, day-of-year)
        ↓
Хмарність + stress-модифікації освітленості
        ↓
PV модель (one-diode, масив 10s x 2p)
        ↓
┌───────────────────────────────────────────────────────┐
│  P&O | P&O+Pyr | NN-GT | NN-VI Pure | NN-VI Hybrid   │
└───────────────────────────────────────────────────────┘
        ↓
Порівняння та аналіз метрик
        ↓
Звіти: analysis_report.txt, nn_advantage_report.txt
```

## Модулі системи

### 1. Модель сонячної панелі (solar_model)

Основне:
- KC200GT параметри
- масштабування на масив 10s x 2p
- фізично коректні межі напруги/струму

Ключовий розрахунок:
- calculate_panel_output.m
- повертає Vopt, Popt та I за заданих G,T та робочої V

Геометрія сонця:
- get_solar_irradiance.m

### 2. Модель хмар (cloud_model)

Ключовий файл:
- apply_cloud_variation.m

Режими:
- clear, gradual, sudden, frequent, mixed
- stress-додатки в simulation скриптах (storm_front, fast_flicker, shade_mismatch surrogate)

### 3. Класичні алгоритми (mppt_classical)

Файли:
- mppt_po.m (базовий P&O)
- mppt_po_adaptive.m (P&O+Pyr)

**Алгоритм**:
```
if P(t) > P(t-1):
    if V(t) > V(t-1):
        V(t+1) = V(t) + dV  # Крок в тому ж напрямку
    else:
        V(t+1) = V(t) - dV  # Крок в іншому напрямку
else:
    if V(t) > V(t-1):
        V(t+1) = V(t) - dV  # Розворот
    else:
        V(t+1) = V(t) + dV  # Розворот
```

### 4. Нейромережеві алгоритми (neural_network)

NN-GT гілка:
- nn_init.m, nn_train.m, nn_forward.m
- задача: G,T -> Vopt

NN-VI гілка:
- nn_init_vi.m, nn_train_vi.m, nn_forward_vi.m
- задача: V,V_prev,I,P,dV,dP -> deltaV
- поточна версія: v5
- режими використання: Pure та Hybrid

### 5. Генерація даних (data_generation)

Файли:
- generate_training_data.m (для NN-GT)
- generate_training_data_vi.m (для NN-VI v5, recovery-oriented policy)

Артефакти:
- data_generation/training_data.mat
- data_generation/training_data_vi_v5.mat

### 6. Основні симулятори (simulation)

Ключові:
- run_full_simulation.m
- compare_algorithms.m
- nn_advantage_experiments.m

Що важливо:
- є перевірки сумісності train/model артефактів
- для NN-VI використовується v5
- окремий stress-run для демонстрації переваги NN у degraded-feedback

### 7. Аналіз результатів (analysis)

Файли:
- analyze_results.m
- analysis_report.txt
- nn_advantage_report.txt
- coursework_results_section.md

## Типові сценарії тестування

Базові:
- clear
- sudden
- frequent
- mixed
- winter
- gradual
- storm_front
- fast_flicker

NN-advantage (окремо):
- fast_flicker + slow P&O
- fast_flicker + slow/noisy
- storm_front + slow/noisy
- partial shade surrogate (наближення)

## Що робить START

Скрипт START надає покрокове меню 1..5:
1. Генерація data
2. Повна симуляція
3. Базове порівняння
4. Аналіз
5. Демо, де NN може явно виграти

## Завдання

1. Запустити START кроки 1..4 та перевірити відтворюваність звіту.
2. Запустити крок 5 та пояснити, чому переможець змінюється.
3. Порівняти Pure vs Hybrid у NN-VI та інтерпретувати різницю.
4. Вказати, що partial shade surrogate не є повною multi-peak фізичною моделлю.
5. Запропонувати наступний експеримент для підсилення валідності висновків.

## Дані, які записуються

```
На кожному кроці зберігаються Time/G/T та траєкторії V,P для всіх активних алгоритмів,
а також еталонні Vopt/Popt для обчислення ефективності.
```

## Вхідні параметри для варіювання

Можна змінювати:

1. В P&O/P&O+Pyr:
    - dV step
    - update period
    - рівень шуму і затримки каналу потужності (у stress-скриптах)

2. В нейромережах:
    - архітектура GT/VI
    - learning rate та epochs
    - policy генерації VI data

3. У сценаріях:
    - cloud pattern
    - stress profile
    - параметри partial shade surrogate

## Очікувані висновки

1. Класичні алгоритми є еталоном для штатних режимів.
2. NN не є універсально кращою, але має перевагу у degraded-feedback сценаріях.
3. Hybrid-підхід є практично корисним компромісом.
