# MPPT Система: Класичні та Нейромережеві Підходи

## Загальний опис

Проєкт моделює MPPT для фотоелектричного масиву 10s x 2p (на базі KC200GT) і порівнює 5 алгоритмів:

1. P&O (базовий)
2. P&O+Pyr (адаптивний P&O з використанням освітленості)
3. NN-GT (мережа G,T -> Vopt)
4. NN-VI Pure (мережа V,V_prev,I,P,dV,dP -> deltaV)
5. NN-VI Hybrid (комбінація NN-VI та локальної P&O логіки)

Окремо додано stress-експерименти, де нейромережі можуть мати явну перевагу.

## Структура проекту

```
full_system/
├── docs/
├── solar_model/
├── cloud_model/
├── mppt_classical/
├── neural_network/
├── data_generation/
├── simulation/
└── analysis/
```

## Поточний стан моделі

- Модель панелі: one-diode, масив 10s x 2p
- Локація: Львів
- Діапазони: G = 0..1000 W/m^2, T = 15..60 C
- Типовий STC-орієнтир у моделі: Vopt близько 275 V, Popt близько 4.05 kW

## Швидкий запуск

```matlab
cd full_system
START
```

У меню START доступний окремий крок 5 для демонстрації режимів, де NN перемагають.

## Рекомендована послідовність

1. generate_training_data()
2. run_full_simulation
3. compare_algorithms
4. analyze_results
5. nn_advantage_experiments

## Основні результати (на момент поточної версії)

- Базові сценарії: класичні методи залишаються найкращими у середньому.
- NN-VI Pure робоча (без деградації в нуль), але не краща за класичні.
- NN-VI Hybrid близька до класики.
- У degrade-режимах (рідке оновлення, шум, затримка вимірювання) NN-GT/NN-VI Hybrid можуть вигравати.

Джерела:
- analysis/analysis_report.txt
- analysis/nn_advantage_report.txt

## Важлива інтерпретація

Твердження про втрати P&O на рівні 10% справедливе лише для спеціальних stress-режимів, а не для типового режиму.

## Актуальні артефакти

- neural_network/trained_network.mat
- neural_network/trained_network_vi_v5.mat
- data_generation/training_data.mat
- data_generation/training_data_vi_v5.mat
- simulation/comparison_results.mat
- analysis/analysis_report.txt
- analysis/nn_advantage_report.txt

## Завдання

1. Відтворити базові результати через кроки 1-4 у START.
2. Запустити крок 5 і пояснити, чому NN виграє у stress-режимах.
3. Порівняти P&O і P&O+Pyr за MAE та ефективністю в зимовому та fast_flicker сценаріях.
4. Оцінити різницю між NN-VI Pure та NN-VI Hybrid.
5. Сформулювати обмеження моделі partial shade surrogate у висновках.

## Додатково

- [Архітектура системи](architecture.md)
- [Класичний MPPT](classical_mppt.md)
- [Нейромережевий MPPT](neural_network_mppt.md)
