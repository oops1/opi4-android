// =============================================================================
//  Заглушка проёма гребёнки GPIO для корпусов case_30 / case_40
// =============================================================================
//  Закрывает задний проём крышки (сверху и сзади). Держится двумя саморезами
//  M2×6 через «ушки» в карманах верха крышки. Подходит к обеим крышкам.
//  Окно в верху пропускает Dupont-провода на пины 1…GC_CABLE_PINS (UART 6/8/10,
//  вентилятор 4/6, ШИМ 7). Без проводов: GC_CABLE = false — глухая заглушка.
//  PART: "print" — для печати (верхом на стол); "assembly" — на корпусе.
//  Экспорт:
//    openscad -o stl/gpio_cover.stl       -D 'PART="print"' gpio_cover.scad
//    openscad -o stl/gpio_cover_solid.stl -D 'PART="print"' -D 'GC_CABLE=false' gpio_cover.scad
// =============================================================================
include <opi4_board.scad>
include <opi4_case_lib.scad>
OPI4_STANDALONE = false;

PART = "print";     // [print, assembly]

$fn = 48;
if (PART == "print") opi4_case("gpio_cover", 40, SOC_X, SOC_Y - 4.5);
else opi4_case("assembly", 40, SOC_X, SOC_Y - 4.5);
