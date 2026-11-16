// =============================================================================
//  Крепление вентилятора 40×40 над RK3399 (Orange Pi 4 без корпуса)
// =============================================================================
//  Два варианта (VARIANT):
//   "heatsink" — воронка-переходник, надевается на игольчатый радиатор 20×20
//                (как прежний переходник 30 мм из ../fan-mount). Винтов к плате
//                нет, весь поток идёт в радиатор. По умолчанию.
//   "bridge"   — мостик на двух крепёжных отверстиях платы (перед-лево и
//                зад-право, по диагонали); вентилятор висит в 3 мм над
//                радиатором и обдувает ещё память, PMU и Wi-Fi.
//  PART: "print" — деталь в положении для печати; "assembly" — на плате.
//  Экспорт:
//    openscad -o stl/fan_mount_40_heatsink.stl -D 'VARIANT="heatsink"' -D 'PART="print"' fan_mount_40.scad
//    openscad -o stl/fan_mount_40_bridge.stl   -D 'VARIANT="bridge"'   -D 'PART="print"' fan_mount_40.scad
// =============================================================================
include <opi4_board.scad>
OPI4_STANDALONE = false;

VARIANT = "heatsink";   // [heatsink, bridge]
PART    = "assembly";   // [assembly, print, check]

FAN = 40;
FAN_THICK = 10;
FAN_OPEN_D = 37;        // отверстие под крыльчатку
PLATE_T = 3.0;          // толщина площадки вентилятора
CORNER_R = 2.5;
M3_CLEAR = 3.3;         // под винт M3 (с гайкой)
FAN_SELF_TAP_D = 2.7;   // под саморез M3 прямо в пластик (вариант heatsink)
M3_NUT_AF = 5.5;
CLR = 0.3;
// Смещение вентилятора от центра SoC: −4,5 мм по Y уводит рамку от гребёнки,
// чтобы торчащие вверх провода Dupont не упирались в вентилятор.
FAN_DX = 0;
FAN_DY = -4.5;

// --- вариант heatsink -------------------------------------------------------
FIT = 0.20;             // зазор на сторону по радиатору (0,10 туго … 0,35 свободно)
GRIP = 5.0;             // насколько гильза охватывает верх радиатора
SLEEVE_WALL = 1.6;
LEDGE = 0.9;            // внутренний упор на крайний ряд игл
FUNNEL_H = 12.0;        // высота воронки 20 → 40 (угол стенок ≤ 47°)
SLIT_W = 1.2;  SLIT_H = 3.5;   // пружинящие прорези в гильзе

// --- вариант bridge ---------------------------------------------------------
BRIDGE_HOLES = [0, 3];  // индексы отверстий платы (см. opi4_holes())
BRIDGE_GAP = 3.0;       // зазор между радиатором и низом площадки
COLUMN_D = 6.5;         // колонна; у отверстия 0 рядом аудиоразъём, у 3 — USB
ARM_W = 6.0;
PILOT_D = 2.2;          // под саморез/винт M2.5 снизу через плату
PILOT_DEPTH = 10;
BOSS_H = 3.0;           // бобышки под гайки M3 под площадкой

$fn = 64;
EPS = 0.01;

module rsq(s, h, r = CORNER_R) translate([-s / 2, -s / 2, 0]) rrect(s, s, h, r);
module slab_sq(s, z) translate([-s / 2, -s / 2, z]) cube([s, s, EPS]);

// =============================================================================
//  Вариант 1: воронка на радиатор. z = 0 — верх радиатора, центр — центр радиатора.
// =============================================================================
module mount_heatsink() {
    s_in = HS_SIZE + 2 * FIT;
    s_out = s_in + 2 * SLEEVE_WALL;
    pitch = fan_pitch(FAN);
    difference() {
        union() {
            // гильза повёрнута вместе с радиатором (HS_ROT), площадка — по краям платы
            rotate(HS_ROT) translate([-s_out / 2, -s_out / 2, -GRIP]) cube([s_out, s_out, GRIP]);
            hull() {                                         // воронка (наружная) + площадка
                rotate(HS_ROT) translate([-s_out / 2, -s_out / 2, -0.5]) cube([s_out, s_out, 0.5]);
                translate([FAN_DX, FAN_DY, FUNNEL_H]) rsq(FAN, PLATE_T);
            }
        }
        // полость гильзы
        rotate(HS_ROT) translate([-s_in / 2, -s_in / 2, -GRIP - 1]) cube([s_in, s_in, GRIP + 1]);
        // полость воронки: от упора (квадрат HS − 2·LEDGE) к кругу крыльчатки
        hull() {
            rotate(HS_ROT) slab_sq(HS_SIZE - 2 * LEDGE, -EPS);
            translate([FAN_DX, FAN_DY, FUNNEL_H]) cylinder(d = FAN_OPEN_D, h = PLATE_T + 1);
        }
        // отверстия вентилятора (саморез M3): площадка + 4 мм угла воронки
        for (sx = [-1, 1], sy = [-1, 1])
            translate([FAN_DX + sx * pitch / 2, FAN_DY + sy * pitch / 2, FUNNEL_H - 4])
                cylinder(d = FAN_SELF_TAP_D, h = PLATE_T + 5);
        // пружинящие прорези в середине каждой стороны гильзы
        for (a = [0 : 90 : 270]) rotate(a + HS_ROT)
            translate([s_in / 2 - 0.5, -SLIT_W / 2, -GRIP - 1]) cube([SLEEVE_WALL + 1, SLIT_W, SLIT_H + 1]);
    }
}

// =============================================================================
//  Вариант 2: мостик на отверстиях платы. Координаты платы (Z = 0 — низ платы).
// =============================================================================
BR_CX = SOC_X + FAN_DX;
BR_CY = SOC_Y + FAN_DY;
BR_Z0 = PCB_T + hs_top() + BRIDGE_GAP;         // низ площадки

module mount_bridge() {
    pitch = fan_pitch(FAN);
    difference() {
        union() {
            translate([BR_CX, BR_CY, BR_Z0]) rsq(FAN, PLATE_T);
            for (i = BRIDGE_HOLES) {
                h = opi4_holes()[i];
                // колонна от платы до верха площадки
                translate([h[0], h[1], PCB_T]) cylinder(d = COLUMN_D, h = BR_Z0 + PLATE_T - PCB_T);
                // балка к ближнему углу площадки
                cx = BR_CX + sign(h[0] - BR_CX) * (FAN / 2 - ARM_W / 2);
                cy = BR_CY + sign(h[1] - BR_CY) * (FAN / 2 - ARM_W / 2);
                hull() {
                    translate([h[0], h[1], BR_Z0]) cylinder(d = ARM_W, h = PLATE_T);
                    translate([cx, cy, BR_Z0]) cylinder(d = ARM_W, h = PLATE_T);
                }
                // косынка снизу балки — жёсткость колонны
                hull() {
                    translate([h[0], h[1], BR_Z0 - 8]) cylinder(d = 3, h = 8);
                    translate([h[0] + (cx - h[0]) * 0.35, h[1] + (cy - h[1]) * 0.35, BR_Z0 - 0.5])
                        cylinder(d = 3, h = 0.5);
                }
            }
            for (sx = [-1, 1], sy = [-1, 1])
                translate([BR_CX + sx * pitch / 2, BR_CY + sy * pitch / 2, BR_Z0 - BOSS_H])
                    cylinder(d = 8.5, h = BOSS_H + EPS);
        }
        translate([BR_CX, BR_CY, BR_Z0 - BOSS_H - 1]) cylinder(d = FAN_OPEN_D, h = PLATE_T + BOSS_H + 2);
        for (sx = [-1, 1], sy = [-1, 1]) translate([BR_CX + sx * pitch / 2, BR_CY + sy * pitch / 2, 0]) {
            translate([0, 0, BR_Z0 - BOSS_H - 1]) cylinder(d = M3_CLEAR, h = PLATE_T + BOSS_H + 2);
            translate([0, 0, BR_Z0 - BOSS_H - 1]) hexagon(M3_NUT_AF + CLR, 2.6 + 1);
        }
        for (i = BRIDGE_HOLES) {
            h = opi4_holes()[i];
            translate([h[0], h[1], PCB_T - 1]) cylinder(d = PILOT_D, h = PILOT_DEPTH + 1);
        }
    }
}

// =============================================================================
if (VARIANT == "heatsink") {
    hs_z = PCB_T + SOC_H + HS_TAPE + HS_H;           // верх радиатора
    if (PART == "print")
        translate([0, 0, FUNNEL_H + PLATE_T]) rotate([180, 0, 0]) mount_heatsink();
    else if (PART == "check")   // должно быть пусто, кроме самого радиатора внутри гильзы
        intersection() {
            opi4_board(with_heatsink = false, with_dupont = false);
            translate([HS_X, HS_Y, hs_z]) mount_heatsink();
        }
    else {
        opi4_board();
        color([0.95, 0.55, 0.15]) translate([HS_X, HS_Y, hs_z]) mount_heatsink();
        translate([HS_X + FAN_DX, HS_Y + FAN_DY, hs_z + FUNNEL_H + PLATE_T]) fan_model(FAN, FAN_THICK);
    }
}
if (VARIANT == "bridge") {
    if (PART == "print")
        translate([0, PCB_W, BR_Z0 + PLATE_T]) rotate([180, 0, 0]) mount_bridge();
    else if (PART == "check")   // должно быть пусто
        intersection() { opi4_board(with_dupont = false); mount_bridge(); }
    else {
        opi4_board();
        color([0.95, 0.55, 0.15]) mount_bridge();
        translate([BR_CX, BR_CY, BR_Z0 + PLATE_T]) fan_model(FAN, FAN_THICK);
    }
}
