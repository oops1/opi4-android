# Переходник вентилятора 30×30 на радиатор 20×20×17 (Orange Pi 4 / RK3399)

Надевается сверху на игольчатый радиатор, приклеенный к SoC. Вентилятор дует вниз, в рёбра, а воздух выходит в стороны под гильзой.

Размер детали 30×30×15.5 мм, вес ~4 г.

## Файлы
| Файл | Зазор на сторону | Когда брать |
|------|------------------|-------------|
| `fan_mount_fit_tight.stl`  | 0.10 мм | принтер печатает «в размер», нужна плотная посадка |
| `fan_mount_fit_normal.stl` | 0.20 мм | **начать с него** |
| `fan_mount_fit_loose.stl`  | 0.35 мм | если normal не налезает |

Посадку держат прорези в гильзе. Если деталь болтается, поставьте каплю термоклея на угол или возьмите вариант tight.

## Печать
- Ориентация: **площадкой вентилятора на стол**, как лежит в STL. Поддержки не нужны.
- Пластик: **PETG или ABS/ASA**. PLA рядом с радиатором 60–80 °C может размягчиться.
- Слой 0.2 мм, 3 периметра, заполнение 30–40 %.

## Сборка
1. Надеть переходник на радиатор до упора: внутренний бортик ляжет на крайний ряд игл.
2. Вентилятор 30×30 (3007 или 3010, 5 В) прикрутить **наклейкой вниз**, чтобы он дул в радиатор. Винты самонарезающие M3 (или M2.5) длиной 10–12 мм для вентилятора 3007 и 14–16 мм для 3010.
3. Питание вентилятора: пины 5V и GND на 40-pin гребёнке Orange Pi 4 (пин 4 = 5V, пин 6 = GND).

## Изменение размеров
Все размеры заданы параметрами в начале `fan_mount.py`: радиатор, глубина гильзы, отверстия, вентилятор. После правки запустите:
```
pip install manifold3d numpy
python fan_mount.py
```
`preview.html` — 3D-просмотр варианта normal в браузере.

Полный корпус под вентилятор 30 или 40 мм — в [../case](../case).

---

## English

A 30×30 fan adapter that slips onto the 20×20×17 pin heatsink glued to the SoC. The fan blows
down into the pins, the air leaves sideways under the sleeve. Part size 30×30×15.5 mm, ~4 g.

* **Files:** `fan_mount_fit_normal.stl` (0.20 mm clearance per side) — **start with it**;
  `_tight` (0.10 mm) if your printer prints true to size; `_loose` (0.35 mm) if normal does not fit.
  The slots in the sleeve hold it; if it wobbles, add a drop of hot glue on a corner.
* **Printing:** fan pad on the bed (as in the STL), no supports. **PETG or ABS/ASA** — PLA may
  soften next to a 60–80 °C heatsink. 0.2 mm layers, 3 perimeters, 30–40 % infill.
* **Assembly:** push the adapter onto the heatsink all the way; screw a 5 V 30×30 fan (3007 or
  3010) on **label side down** so it blows into the heatsink, with M3 (or M2.5) self-tapping
  screws, 10–12 mm for a 3007 fan and 14–16 mm for a 3010. Power: header pin 4 = 5 V,
  pin 6 = GND (connect with the power off; pin 1 next to it is 3.3 V).
* **Changing dimensions:** parameters at the top of `fan_mount.py`, then
  `pip install manifold3d numpy` and `python fan_mount.py`. `preview.html` is a 3D preview of
  the normal variant in the browser.

For a full case with a 30 or 40 mm fan see [../case](../case/README.en.md).
