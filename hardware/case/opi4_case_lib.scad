// =============================================================================
//  Orange Pi 4 — общий код корпуса (основание + крышка с вентилятором)
// =============================================================================
//  Подключается из case_30.scad и case_40.scad. Сам по себе ничего не рисует.
//
//  Конструкция:
//    * ОСНОВАНИЕ: дно со щелями, 4 стойки под отверстия платы, стенки до уровня
//      верхней поверхности платы и тонкий бортик (замок) над ними. Плата
//      кладётся сверху — разъёмы с вылетом за кромку проходят над стенками.
//    * КРЫШКА: верх с вентилятором + стенки с U-вырезами под разъёмы (открыты
//      вниз). Сзади над гребёнкой 40 pin — сквозной проём (верх + стенка):
//      крышку можно снять, не отключая Dupont-провода UART и вентилятора.
//    * Две колонны крышки (диагональ: перед-лево и зад-право) прижимают плату;
//      длинные винты M2.5 идут через колонну, плату и в стойку основания.
//  Все координаты — в системе платы (см. opi4_board.scad), Z=0 — низ платы.
// =============================================================================

/* [Корпус: общие] */
WALL     = 2.0;    // толщина стенок
FLOOR    = 2.0;    // толщина дна
LID_T    = 2.0;    // толщина верха крышки
GAP      = 0.5;    // зазор плата ↔ внутренняя стенка
CLR      = 0.3;    // зазор посадок (замок, отверстия)
CASE_R   = 3.0;    // радиус наружных углов
STANDOFF_H = 5.0;  // высота стоек (зазор под платой). ≥ BOTTOM_PARTS_H + 1,5
STANDOFF_D = 6.0;
HS_CLEAR = 2.5;    // зазор между верхом радиатора и крышкой
LIP_H    = 2.0;    // высота бортика-замка основания
LID_SEAM = 0.2;    // зазор шва, чтобы колонны гарантированно прижимали плату

/* [Винты] */
INSERTS  = false;  // true — стойки под латунные вставки M2.5 (Ø3,6 × 5)
PILOT_D  = 2.2;    // отверстие под саморез/винт M2.5 в пластик
M25_CLEAR = 2.8;   // проход M2.5
M25_HEAD_D = 5.0;  // головка M2.5 (DIN912 Ø4,5) + зазор
LID_SCREW_L = 25;  // длина винтов крышки M2.5, мм (25 или 30)
SCREW_ENGAGE = 5;  // на сколько винт входит в стойку
PILLAR_D = 5.5;    // колонна крышки
LID_PILLAR_HOLES = [0, 3];       // индексы отверстий платы с колоннами крышки

/* [Вентилятор: общие] */
FAN_THICK = 10;    // толщина вентилятора (только для превью)
M3_CLEAR = 3.3;    // отверстия под винты вентилятора
M3_NUT_AF = 5.5;   // гайка M3 «под ключ»
NUT_TRAPS = true;  // шестигранные карманы под гайки M3 снизу крышки
FAN_GRILLE = true; // защитная решётка в отверстии вентилятора

/* [Разъёмы] */
CONN_M = 0.8;      // запас выреза вокруг разъёма (сбоку и сверху)
MERGE_R = true;    // одно общее окно под USB/Ethernet/USB на правой стенке
// дополнительное расширение выреза снаружи под корпус штекера
function plug_relief(name) =
    name == "hdmi" ? 3.0 : name == "usbc" ? 2.0 : name == "audio" ? 1.5 :
    name == "dc" ? 1.0 : 0;

/* [Опции] */
FLOOR_VENTS = true;
SIDE_VENTS  = true;    // щели в левой и задней стенках
FRONT_VENTS = true;    // щели в передней стенке над низкими разъёмами
BUTTON_HOLES = true;   // отверстия в дне к кнопкам Reset / Recovery (скрепкой)
IR_ENABLE   = false;   // окно под ИК-приёмник (на OPi4 v1.3 штатного нет)
ANT_HOLE    = false;   // отверстие Ø6,5 под SMA-антенну в левой стенке
KEY_BOARD   = true;    // стойки под плату ключа ШИМ (транзистор) под крышкой
KEY_POSTS   = [[63.5, 30.5], [74.5, 43.5]];   // центры стоек (M2 саморез)
KEY_POST_L  = 4.0;     // длина стоек от низа крышки
WIRE_CHANNEL = true;   // канавка для проводов вентилятора к пинам 4/6

/* [Заглушка гребёнки GPIO] */
GPIO_COVER  = true;    // карманы и бобышки в крышке под винты заглушки
GC_CABLE    = true;    // окно в заглушке для проводов (UART, вентилятор, ШИМ)
GC_CABLE_PINS = 14;    // окно открывает пины 1…GC_CABLE_PINS
GC_EAR      = 5.0;     // «ушки» заглушки, лежат в карманах верха крышки
GC_EAR_T    = 1.2;
GC_SCREW_PILOT = 1.7;  // саморез M2
GC_VENTS    = true;    // щели в задней стенке заглушки

// -----------------------------------------------------------------------------
//  Производные размеры
// -----------------------------------------------------------------------------
function max_conn_h() = max([for (c = CONNECTORS) c[4]]);
Z_BOT    = -(STANDOFF_H + FLOOR);            // низ корпуса
Z_SPLIT  = PCB_T;                            // шов основание/крышка = верх платы
Z_IN_TOP = PCB_T + max(hs_top() + HS_CLEAR, max_conn_h() + 1.5);  // низ верха крышки
Z_TOP    = Z_IN_TOP + LID_T;                 // верх крышки
IN_X0 = -GAP;            IN_X1 = PCB_L + GAP;
IN_Y0 = -GAP;            IN_Y1 = PCB_W + GAP;
OUT_X0 = IN_X0 - WALL;   OUT_X1 = IN_X1 + WALL;
OUT_Y0 = IN_Y0 - WALL;   OUT_Y1 = IN_Y1 + WALL;
LIP_T = (WALL - CLR) / 2;                    // бортик основания и юбка крышки

// проём над гребёнкой (+ светодиоды)
SLOT_X0 = HDR_X0 - 1.5;
SLOT_X1 = HDR_X1 + 1.5;
SLOT_Y0 = min(HDR_Y0 - 1.5, LED_Y - 1.2);

// заглушка: ушки и винты
GC_EAR_Y0 = (SLOT_Y0 + IN_Y1) / 2 - GC_EAR / 2 + 0.4;
GC_EARS = [[SLOT_X0 - GC_EAR, SLOT_X0], [SLOT_X1, SLOT_X1 + GC_EAR]];   // [x0, x1]
GC_SCREWS = [[SLOT_X0 - GC_EAR / 2, GC_EAR_Y0 + GC_EAR / 2],
             [SLOT_X1 + GC_EAR / 2, GC_EAR_Y0 + GC_EAR / 2]];

// глубина цековки под головку винта крышки
H_THROUGH = Z_TOP;                           // от низа платы до верха крышки
CB_DEPTH = max(0, H_THROUGH - LID_SCREW_L + SCREW_ENGAGE);

module case_outer(z0, z1) {
    translate([OUT_X0, OUT_Y0, z0]) rrect(OUT_X1 - OUT_X0, OUT_Y1 - OUT_Y0, z1 - z0, CASE_R);
}
module case_inner(z0, z1, grow = 0) {
    translate([IN_X0 - grow, IN_Y0 - grow, z0])
        rrect(IN_X1 - IN_X0 + 2 * grow, IN_Y1 - IN_Y0 + 2 * grow, z1 - z0, PCB_R + GAP + grow);
}

// Прямоугольный вырез в стенке edge: вдоль кромки [a,b], по высоте [z0,z1].
// d_out — насколько вырез уходит наружу от внутренней грани стенки,
// d_in  — насколько внутрь корпуса (может быть отрицательным: вырез начинается
//         в толще стенки, используется для расширения снаружи).
module wall_cut(edge, a, b, z0, z1, d_out, d_in) {
    if (edge == "F") translate([a, IN_Y0 - d_out, z0]) cube([b - a, d_out + d_in, z1 - z0]);
    if (edge == "B") translate([a, IN_Y1 - d_in,  z0]) cube([b - a, d_out + d_in, z1 - z0]);
    if (edge == "L") translate([IN_X0 - d_out, a, z0]) cube([d_out + d_in, b - a, z1 - z0]);
    if (edge == "R") translate([IN_X1 - d_in,  a, z0]) cube([d_out + d_in, b - a, z1 - z0]);
}

// Все проёмы в стенках крышки (они же режут бортик основания)
module lid_wall_openings() {
    // правая кромка: USB-стек, Ethernet и USB2 стоят почти вплотную — перемычки
    // между вырезами вышли бы 1,7 мм × 17 мм и ломались бы, поэтому одно окно
    if (MERGE_R) {
        rc = [for (c = CONNECTORS) if (c[1] == "R" && c[4] > 0) c];
        if (len(rc) > 0)
            wall_cut("R", min([for (c = rc) c[2]]) - CONN_M, max([for (c = rc) c[3]]) + CONN_M,
                     Z_SPLIT - 0.4, PCB_T + max([for (c = rc) c[4]]) + CONN_M, WALL + 1, 0.3);
    }
    for (c = CONNECTORS) if (c[4] > 0 && !(MERGE_R && c[1] == "R")) {
        zt = PCB_T + c[4] + CONN_M;
        wall_cut(c[1], c[2] - CONN_M, c[3] + CONN_M, Z_SPLIT - 0.4, zt, WALL + 1, 0.3);
        r = plug_relief(c[0]);
        if (r > 0) {
            rd = min(WALL, max(0.6, WALL + GAP - c[5]));   // до лицевой грани разъёма
            wall_cut(c[1], c[2] - CONN_M - r, c[3] + CONN_M + r, Z_SPLIT - 0.4, zt + r,
                     WALL + 1, -(WALL - rd));
        }
    }
    // задний проём над гребёнкой — на всю высоту
    wall_cut("B", SLOT_X0, SLOT_X1, Z_SPLIT - 0.4, Z_TOP + 1, WALL + 1, 0.3);
}

// -----------------------------------------------------------------------------
//  ОСНОВАНИЕ
// -----------------------------------------------------------------------------
module case_base() {
    difference() {
        union() {
            difference() {
                case_outer(Z_BOT, Z_SPLIT);
                case_inner(Z_BOT + FLOOR, Z_SPLIT + 1);
            }
            // бортик-замок
            difference() {
                case_inner(Z_SPLIT - 0.01, Z_SPLIT + LIP_H, LIP_T);
                case_inner(Z_SPLIT - 1, Z_SPLIT + LIP_H + 1);
            }
            // стойки
            for (h = opi4_holes()) translate([h[0], h[1], Z_BOT + FLOOR - 0.01])
                cylinder(d = INSERTS ? 7 : STANDOFF_D, h = STANDOFF_H + 0.01);
        }
        // проёмы разъёмов (снимают бортик и 0,4 мм стенки под вылетом разъёмов)
        lid_wall_openings();
        // microSD (снизу платы, задняя кромка) + выемка под ноготь
        for (c = CONNECTORS) if (c[4] < 0) {
            wall_cut(c[1], c[2] - 1.5, c[3] + 1.5, -abs(c[4]) - 1.5, Z_SPLIT + LIP_H + 1, WALL + 1, 0.3);
            wall_cut(c[1], (c[2] + c[3]) / 2 - 6, (c[2] + c[3]) / 2 + 6, -abs(c[4]) - 3.5,
                     Z_SPLIT + 1, WALL + 1, -(WALL - 1.0));
        }
        // отверстия в стойках
        for (h = opi4_holes()) translate([h[0], h[1], Z_BOT + 0.8])
            cylinder(d = INSERTS ? 3.6 : PILOT_D, h = STANDOFF_H + FLOOR);
        // щели в дне
        if (FLOOR_VENTS) translate([0, 0, Z_BOT - 1]) difference() {
            for (x = [14 : 4.5 : 78]) translate([x, 9, 0]) hull() {
                cylinder(d = 2, h = FLOOR + 2);
                translate([0, 37, 0]) cylinder(d = 2, h = FLOOR + 2);
            }
            for (b = [BTN_RESET, BTN_RECOVER]) translate([b[0], b[1], -1]) cylinder(d = 7, h = FLOOR + 4);
            for (h = opi4_holes()) translate([h[0], h[1], -1]) cylinder(d = 9, h = FLOOR + 4);
        }
        // доступ к кнопкам снизу (скрепкой) + подписи на дне
        if (BUTTON_HOLES) {
            for (b = [BTN_RESET, BTN_RECOVER]) translate([b[0], b[1], Z_BOT - 1]) {
                cylinder(d = 3.0, h = FLOOR + 2);
                cylinder(d1 = 5.0, d2 = 3.0, h = 2.0);      // фаска снаружи
            }
            for (t = [[BTN_RESET, "RST"], [BTN_RECOVER, "REC"]])
                translate([t[0][0], t[0][1] - 5.5, Z_BOT - 0.01]) mirror([1, 0, 0])
                    linear_extrude(0.5) text(t[1], size = 3, halign = "center", valign = "center",
                                              font = "Liberation Sans:style=Bold");
        }
        // щели в стенках ниже платы: левая и задняя
        if (SIDE_VENTS) {
            for (y = [8 : 4 : 46]) wall_cut("L", y, y + 2, Z_BOT + FLOOR + 0.8, -1.0, WALL + 1, 0.3);
            for (x = [77 : 4 : 85]) wall_cut("B", x, x + 2, Z_BOT + FLOOR + 0.8, -1.0, WALL + 1, 0.3);
        }
    }
}

// -----------------------------------------------------------------------------
//  КРЫШКА (fan_size: 30 или 40; центр вентилятора fan_cx, fan_cy)
// -----------------------------------------------------------------------------
// Рисунок решётки (кольца, спицы, центр) толщиной t; его вычитают из выреза
module fan_grille_pattern(open_d, hub_d, t) {
    w = 1.2;
    for (r = [hub_d / 2 + 0.8, (hub_d / 2 + open_d / 2) / 2 + 0.6])
        difference() { cylinder(r = r + w / 2, h = t); translate([0, 0, -1]) cylinder(r = r - w / 2, h = t + 2); }
    for (a = [45 : 90 : 359]) rotate(a) translate([0, -w / 2, 0]) cube([open_d / 2 + 1, w, t]);
    cylinder(d = hub_d * 0.6, h = t);
}

module case_lid(fan_size, fan_cx, fan_cy) {
    open_d = fan_size - 3;
    pitch = fan_pitch(fan_size);
    boss_h = 3.0;
    difference() {
        union() {
            // верх + стенки
            difference() {
                case_outer(Z_SPLIT + LID_SEAM, Z_TOP);
                case_inner(Z_SPLIT, Z_IN_TOP);
                // паз под бортик основания: внутренняя половина стенки снизу
                case_inner(Z_SPLIT, Z_SPLIT + LIP_H + CLR, LIP_T + CLR);
            }
            // колонны, прижимающие плату (+ ребро к углу корпуса)
            for (i = LID_PILLAR_HOLES) {
                h = opi4_holes()[i];
                translate([h[0], h[1], PCB_T]) cylinder(d = PILLAR_D, h = Z_IN_TOP - PCB_T + 0.01);
                // утолщение под цековку
                if (CB_DEPTH > LID_T) translate([h[0], h[1], Z_TOP - CB_DEPTH - 1.5])
                    cylinder(d = M25_HEAD_D + 2.4, h = CB_DEPTH + 1.5 - LID_T + 0.01);
                // ребро к углу (выше платы)
                cx = h[0] < PCB_L / 2 ? IN_X0 : IN_X1;
                cy = h[1] < PCB_W / 2 ? IN_Y0 : IN_Y1;
                intersection() {
                    hull() {
                        translate([h[0], h[1], PCB_T + 1.0]) cylinder(d = PILLAR_D, h = Z_IN_TOP - PCB_T - 1);
                        translate([cx - 0.5, cy - 0.5, PCB_T + 1.0]) cube([1, 1, Z_IN_TOP - PCB_T - 1]);
                    }
                    case_inner(PCB_T + 1.0, Z_IN_TOP + 0.01);
                }
            }
            // бобышки под гайки вентилятора
            if (NUT_TRAPS) for (sx = [-1, 1], sy = [-1, 1])
                translate([fan_cx + sx * pitch / 2, fan_cy + sy * pitch / 2, Z_IN_TOP - boss_h])
                    cylinder(d = 8.5, h = boss_h + 0.01);
            // стойки под плату ключа ШИМ
            if (KEY_BOARD) for (p = KEY_POSTS) translate([p[0], p[1], Z_IN_TOP - KEY_POST_L])
                cylinder(d = 5, h = KEY_POST_L + 0.01);
            // бобышки под винты заглушки гребёнки (сливаются со стенкой)
            if (GPIO_COVER) intersection() {
                for (s = GC_SCREWS) translate([s[0], s[1], Z_IN_TOP - 4]) cylinder(d = 5.5, h = 4.01);
                case_inner(Z_IN_TOP - 5, Z_IN_TOP + 0.01);
            }
        }
        // проёмы разъёмов и задний проём гребёнки
        lid_wall_openings();
        // проём в верхе над гребёнкой + светодиоды
        translate([SLOT_X0, SLOT_Y0, Z_IN_TOP - 5]) cube([SLOT_X1 - SLOT_X0, OUT_Y1 - SLOT_Y0 + 1, 10]);
        // карманы под ушки заглушки и отверстия под саморезы M2
        if (GPIO_COVER) {
            for (e = GC_EARS) translate([e[0] - CLR, GC_EAR_Y0 - CLR, Z_TOP - GC_EAR_T])
                cube([e[1] - e[0] + 2 * CLR, GC_EAR + 2 * CLR, GC_EAR_T + 1]);
            for (s = GC_SCREWS) translate([s[0], s[1], Z_IN_TOP - 3.5]) cylinder(d = GC_SCREW_PILOT, h = 10);
        }
        // окно к 3-контактному отладочному UART
        translate([DBG_X - 2.3, DBG_Y0 - 2.0, Z_IN_TOP - 5]) cube([4.6, SLOT_Y0 - DBG_Y0 + 2.1, 10]);
        // отверстие вентилятора
        // (решётка — только в наружных 1,2 мм верха, при печати это первые слои)
        translate([fan_cx, fan_cy, 0]) difference() {
            translate([0, 0, Z_IN_TOP - boss_h - 1]) cylinder(d = open_d, h = LID_T + boss_h + 2);
            if (FAN_GRILLE) translate([0, 0, Z_TOP - 1.2]) fan_grille_pattern(open_d, fan_size * 0.35, 1.2);
        }
        // винты вентилятора + карманы под гайки
        for (sx = [-1, 1], sy = [-1, 1]) translate([fan_cx + sx * pitch / 2, fan_cy + sy * pitch / 2, 0]) {
            translate([0, 0, Z_IN_TOP - boss_h - 1]) cylinder(d = M3_CLEAR, h = 20);
            if (NUT_TRAPS) translate([0, 0, Z_IN_TOP - boss_h - 1]) hexagon(M3_NUT_AF + CLR, 2.6 + 1);
        }
        // винты крышки: проход + цековка
        for (i = LID_PILLAR_HOLES) {
            h = opi4_holes()[i];
            translate([h[0], h[1], PCB_T - 1]) cylinder(d = M25_CLEAR, h = Z_TOP);
            if (CB_DEPTH > 0) translate([h[0], h[1], Z_TOP - CB_DEPTH]) cylinder(d = M25_HEAD_D, h = CB_DEPTH + 1);
        }
        // отверстия M2 в стойках платы ключа
        if (KEY_BOARD) for (p = KEY_POSTS) translate([p[0], p[1], Z_IN_TOP - KEY_POST_L - 1])
            cylinder(d = 1.7, h = KEY_POST_L + 0.5);
        // канавка для проводов: от заднего правого угла вентилятора к проёму у пинов 4/6
        if (WIRE_CHANNEL) {
            p0 = [fan_cx + fan_size / 2 - 4, fan_cy + fan_size / 2 - 4];
            p1 = [hdr_pin(5)[0], SLOT_Y0 + 1];
            translate([0, 0, Z_TOP - 1.4]) hull() {
                translate(p0) cylinder(d = 3, h = 2);
                translate(p1) cylinder(d = 3, h = 2);
            }
        }
        // щели: левая стенка, задняя стенка справа от гребёнки, передняя над разъёмами
        if (SIDE_VENTS) {
            for (y = [8 : 4.5 : 46]) wall_cut("L", y, y + 2, Z_SPLIT + 3, Z_IN_TOP - 2, WALL + 1, 0.3);
            for (x = [61 : 4.5 : 82]) wall_cut("B", x, x + 2, Z_SPLIT + 4, Z_IN_TOP - 2, WALL + 1, 0.3);
        }
        if (FRONT_VENTS) {
            for (x = [48 : 4.5 : 57]) wall_cut("F", x, x + 2, Z_SPLIT + 6, Z_IN_TOP - 2, WALL + 1, 0.3);
            for (x = [73 : 4.5 : 86]) wall_cut("F", x, x + 2, Z_SPLIT + 6, Z_IN_TOP - 2, WALL + 1, 0.3);
            for (x = [17 : 4.5 : 42]) wall_cut("F", x, x + 2, PCB_T + 10.5, Z_IN_TOP - 2, WALL + 1, 0.3);
        }
        if (IR_ENABLE) translate([IR_X, IN_Y0 - WALL - 1, PCB_T + 3]) rotate([-90, 0, 0]) cylinder(d = 5, h = WALL + 2);
        if (ANT_HOLE) translate([IN_X0 - WALL - 1, 28, (Z_SPLIT + Z_IN_TOP) / 2]) rotate([0, 90, 0])
            cylinder(d = 6.5, h = WALL + 2);
    }
}

// -----------------------------------------------------------------------------
//  Сборка / раскладка для печати
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
//  Шаблон для проверки размеров (~10 мин печати): рамка по контуру платы,
//  стойки со штырями в крепёжные отверстия и язычки напротив каждого разъёма.
//  Плата кладётся сверху штырями в отверстия; язычки должны совпасть с разъёмами.
// -----------------------------------------------------------------------------
module pcb2d(off = 0) offset(r = off) offset(r = PCB_R) offset(delta = -PCB_R) square([PCB_L, PCB_W]);

module fit_template() {
    t = 1.2;
    so = STANDOFF_H - 1;
    tab = 5;
    linear_extrude(t) {
        difference() { pcb2d(0); pcb2d(-6); }
        for (c = CONNECTORS) {
            a = c[2]; b = c[3];
            if (c[1] == "F") translate([a, -tab]) square([b - a, tab + 3]);
            if (c[1] == "B") translate([a, PCB_W - 3]) square([b - a, tab + 3]);
            if (c[1] == "R") translate([PCB_L - 3, a]) square([tab + 3, b - a]);
            if (c[1] == "L") translate([-tab, a]) square([tab + 3, b - a]);
        }
        // метка пина 1 гребёнки и центр SoC (перемычки к рамке)
        translate([hdr_pin(1)[0] - 1, PCB_W - 6]) polygon([[0, 0], [2, 0], [1, 3]]);
        translate([HS_X - 1, 0]) square([2, PCB_W]);
        translate([0, HS_Y - 1]) square([PCB_L, 2]);
        translate([HS_X, HS_Y]) rotate(HS_ROT) difference() { square(HS_SIZE + 2, center = true); square(HS_SIZE, center = true); }
    }
    for (h = opi4_holes()) translate([h[0], h[1], 0]) {
        cylinder(d = STANDOFF_D, h = t + so);
        cylinder(d = HOLE_D - 0.4, h = t + so + PCB_T + 1);
    }
}

// -----------------------------------------------------------------------------
//  Заглушка проёма гребёнки GPIO (в собранном положении, координаты платы).
//  Закрывает проём сверху и сзади, держится двумя саморезами M2 через «ушки»,
//  которые лежат в карманах верха крышки заподлицо. В верху — окно для
//  проводов на пины 1…GC_CABLE_PINS (Dupont-разъём проходит насквозь),
//  вырез под провод вентилятора (из канавки) и вырез над светодиодами.
// -----------------------------------------------------------------------------
module gpio_cover() {
    x0 = SLOT_X0 + CLR;  x1 = SLOT_X1 - CLR;
    yf = SLOT_Y0 + CLR;
    zb = Z_SPLIT - 0.4 + LID_SEAM;            // низ: на стенке основания
    cx0 = hdr_pin(GC_CABLE_PINS)[0] - 1.6;
    difference() {
        union() {
            translate([x0, yf, Z_IN_TOP]) cube([x1 - x0, OUT_Y1 - yf, LID_T]);       // верх
            translate([x0, IN_Y1, zb]) cube([x1 - x0, WALL, Z_TOP - zb]);            // задняя стенка
            for (e = GC_EARS) {                                                       // ушки
                ex0 = e[0] < x0 ? e[0] : x1 - 1;
                ex1 = e[0] < x0 ? x0 + 1 : e[1];
                translate([ex0, GC_EAR_Y0, Z_TOP - GC_EAR_T]) cube([ex1 - ex0, GC_EAR, GC_EAR_T]);
            }
        }
        for (s = GC_SCREWS) translate([s[0], s[1], Z_IN_TOP]) cylinder(d = 2.3, h = 5);
        if (GC_CABLE)                                                                 // окно проводов
            translate([cx0, HDR_Y0 - 0.6, Z_IN_TOP - 5]) cube([x1 - 1.0 - cx0, IN_Y1 - HDR_Y0 + 0.6, 10]);
        // вырез под провод вентилятора — напротив конца канавки крышки
        translate([hdr_pin(5)[0] - 1.75, yf - 1, Z_IN_TOP - 5]) cube([3.5, HDR_Y0 - yf + 1, 10]);
        // вырез над светодиодами
        translate([LED_X - 2.5, yf - 1, Z_IN_TOP - 5]) cube([5, LED_Y + 1.2 - yf + 1, 10]);
        // щели на выдув в задней стенке
        if (GC_VENTS) for (x = [x0 + 4 : 4.5 : x1 - 5])
            translate([x, IN_Y1 - 2, Z_SPLIT + 3]) cube([2, WALL + 3, Z_IN_TOP - 2 - Z_SPLIT - 3]);
    }
}

// Винт для картинок: головка сверху на z = 0, стержень вниз
module screw_model(d, l, head_d, head_h) color([0.6, 0.6, 0.65]) {
    cylinder(d = head_d, h = head_h);
    translate([0, 0, -l]) cylinder(d = d, h = l);
}

module opi4_case(part, fan_size, fan_cx, fan_cy) {
    if (part == "gpio_cover") translate([0, PCB_W, Z_TOP]) rotate([180, 0, 0]) gpio_cover();
    if (part == "template") fit_template();
    if (part == "base") translate([0, 0, -Z_BOT]) case_base();
    if (part == "lid")  translate([0, PCB_W, Z_TOP]) rotate([180, 0, 0]) case_lid(fan_size, fan_cx, fan_cy);
    if (part == "assembly" || part == "exploded") {
        e = part == "exploded" ? 25 : 0;
        color([0.85, 0.85, 0.88]) case_base();
        opi4_board();
        color([0.95, 0.55, 0.15]) translate([0, 0, e]) case_lid(fan_size, fan_cx, fan_cy);
        if (GPIO_COVER) color([0.35, 0.35, 0.38]) translate([0, e * 0.6, 1.6 * e]) gpio_cover();
        translate([fan_cx, fan_cy, Z_TOP + 2 * e]) fan_model(fan_size, FAN_THICK);
    }
    // Пошаговая сборка для README: step1 … step6
    if (part == "step1") color([0.85, 0.85, 0.88]) case_base();
    if (part == "step2") {
        color([0.85, 0.85, 0.88]) case_base();
        translate([0, 0, 14]) opi4_board();
    }
    if (part == "step3") {
        color([0.95, 0.55, 0.15]) case_lid(fan_size, fan_cx, fan_cy);
        translate([fan_cx, fan_cy, Z_TOP + 12]) fan_model(fan_size, FAN_THICK);
        p = fan_pitch(fan_size);
        for (sx = [-1, 1], sy = [-1, 1]) translate([fan_cx + sx * p / 2, fan_cy + sy * p / 2, 0]) {
            translate([0, 0, Z_TOP + 12 + FAN_THICK + 10]) screw_model(3, 16, 5.5, 3);
            color([0.7, 0.7, 0.72]) translate([0, 0, Z_IN_TOP - 3 - 10]) difference() {
                hexagon(M3_NUT_AF, 2.4); translate([0, 0, -1]) cylinder(d = 3, h = 5);
            }
        }
    }
    if (part == "step4") {
        color([0.85, 0.85, 0.88]) case_base();
        opi4_board();
        translate([0, 0, 18]) {
            color([0.95, 0.55, 0.15]) case_lid(fan_size, fan_cx, fan_cy);
            translate([fan_cx, fan_cy, Z_TOP]) fan_model(fan_size, FAN_THICK);
        }
        for (i = LID_PILLAR_HOLES) translate([opi4_holes()[i][0], opi4_holes()[i][1], Z_TOP + 30])
            screw_model(2.5, LID_SCREW_L, 4.5, 2.5);
    }
    if (part == "step5" || part == "step6") {
        e = part == "step5" ? 14 : 0;
        color([0.85, 0.85, 0.88]) case_base();
        opi4_board();
        color([0.95, 0.55, 0.15]) case_lid(fan_size, fan_cx, fan_cy);
        translate([fan_cx, fan_cy, Z_TOP]) fan_model(fan_size, FAN_THICK);
        color([0.35, 0.35, 0.38]) translate([0, 0, e]) gpio_cover();
        // провода Dupont от пинов 4, 6, 8, 10 вверх через окно заглушки
        color([0.85, 0.15, 0.15]) for (n = [4, 6, 8, 10])
            translate([hdr_pin(n)[0], hdr_pin(n)[1], PCB_T + 16]) cylinder(d = 1.3, h = 22, $fn = 8);
        if (e > 0) for (s = GC_SCREWS) translate([s[0], s[1], Z_TOP + e + 10]) screw_model(2, 6, 3.8, 1.6);
    }
    if (part == "cut") {        // разрез по центру вентилятора для проверки зазоров
        intersection() {
            union() {
                color([0.85, 0.85, 0.88]) case_base();
                opi4_board();
                color([0.95, 0.55, 0.15]) case_lid(fan_size, fan_cx, fan_cy);
                translate([fan_cx, fan_cy, Z_TOP]) fan_model(fan_size, FAN_THICK);
            }
            translate([-20, fan_cy, -50]) cube([200, 100, 200]);
        }
    }
}
