// Проверка: пересекаются ли детали с моделью платы.
// Рендер (F6) должен дать ПУСТОЙ результат («Current top level object is empty»)
// или только плоские «плёнки» в местах касания (стойки, колонны).
// CHECK: "base", "lid30", "lid40", "cover" (заглушка ↔ плата с Dupont),
//        "cover_lid" (заглушка ↔ крышка).  Для крепления: fan_mount_40.scad, PART="check".
include <opi4_board.scad>
include <opi4_case_lib.scad>
OPI4_STANDALONE = false;
CHECK = "lid40";
$fn = 24;

module board_solid() opi4_board(with_heatsink = true, with_dupont = CHECK == "cover");

if (CHECK == "cover_lid")
    intersection() { gpio_cover(); case_lid(40, SOC_X, SOC_Y - 4.5); }
else intersection() {
    board_solid();
    if (CHECK == "base")  case_base();
    if (CHECK == "lid40") case_lid(40, SOC_X, SOC_Y - 4.5);
    if (CHECK == "lid30") case_lid(30, SOC_X, SOC_Y);
    if (CHECK == "cover") gpio_cover();
}
