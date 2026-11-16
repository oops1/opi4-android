#!/usr/bin/env bash
# Экспорт STL и PNG-превью. Запуск: bash render.sh [путь к openscad]
# Без аргумента берёт openscad из PATH.
set -e
cd "$(dirname "$0")"
OS="${1:-openscad}"
mkdir -p stl png
png() {  # файл.png  файл.scad  камера(eye x,y,z,center x,y,z)  -D...
  local out=$1 src=$2 cam=$3; shift 3
  "$OS" -o "png/$out" --imgsize=1400,1000 --camera="$cam" --colorscheme=Tomorrow "$@" "$src"
}
if [ "${SKIP_STL:-0}" != 1 ]; then
  "$OS" -o stl/fit_template.stl -D 'PART="template"' case_40.scad
  "$OS" -o stl/case_base.stl  -D 'PART="base"' case_40.scad
  "$OS" -o stl/case40_lid.stl -D 'PART="lid"'  case_40.scad
  "$OS" -o stl/case30_lid.stl -D 'PART="lid"'  case_30.scad
  "$OS" -o stl/gpio_cover.stl -D 'PART="print"' gpio_cover.scad
  "$OS" -o stl/gpio_cover_solid.stl -D 'PART="print"' -D 'GC_CABLE=false' gpio_cover.scad
  "$OS" -o stl/fan_mount_40_heatsink.stl -D 'VARIANT="heatsink"' -D 'PART="print"' fan_mount_40.scad
  "$OS" -o stl/fan_mount_40_heatsink_loose.stl -D 'VARIANT="heatsink"' -D 'FIT=0.35' -D 'PART="print"' fan_mount_40.scad
  "$OS" -o stl/fan_mount_40_heatsink_rot45.stl -D 'VARIANT="heatsink"' -D 'HS_ROT=45' -D 'PART="print"' fan_mount_40.scad
  "$OS" -o stl/fan_mount_40_heatsink_rot45_loose.stl -D 'VARIANT="heatsink"' -D 'HS_ROT=45' -D 'FIT=0.35' -D 'PART="print"' fan_mount_40.scad
  "$OS" -o stl/fan_mount_40_bridge.stl   -D 'VARIANT="bridge"'   -D 'PART="print"' fan_mount_40.scad
fi
FRONT="-55,-120,120,46,28,12"     # спереди-слева (HDMI, аудио, USB-C, DC)
BACK="150,175,120,46,28,12"       # сзади-справа (гребёнка, USB, Ethernet)
png case40_front.png    case_40.scad "$FRONT" -D 'PART="assembly"'
png case40_back.png     case_40.scad "$BACK"  -D 'PART="assembly"'
png case40_exploded.png case_40.scad "-95,-200,230,46,28,32" -D 'PART="exploded"'
png case40_cut.png      case_40.scad "46,-140,20,46,28,12" -D 'PART="cut"'
png case30_front.png    case_30.scad "$FRONT" -D 'PART="assembly"'
png case30_back.png     case_30.scad "$BACK"  -D 'PART="assembly"'
png case_base_print.png case_40.scad "-40,-100,140,46,28,0" -D 'PART="base"'
png case40_lid_print.png case_40.scad "-40,-100,120,46,28,0" -D 'PART="lid"'
png case30_lid_print.png case_30.scad "-40,-100,120,46,28,0" -D 'PART="lid"'
png fan_mount_40_heatsink.png fan_mount_40.scad "-40,-110,130,40,30,15" -D 'VARIANT="heatsink"'
png fan_mount_40_bridge.png   fan_mount_40.scad "-40,-110,130,46,28,12" -D 'VARIANT="bridge"'
png board.png opi4_board.scad "-40,-100,110,46,28,0"
png fit_template.png case_40.scad "-40,-100,110,46,28,0" -D 'PART="template"'
png fan_mount_40_heatsink_rot45.png fan_mount_40.scad "-40,-110,130,40,30,15" -D 'VARIANT="heatsink"' -D 'HS_ROT=45'
png gpio_cover_print.png gpio_cover.scad "5,-75,85,31,3,6" -D 'PART="print"'
png gpio_cover_back.png case_40.scad "150,190,110,40,40,12" -D 'PART="assembly"'
# пошаговая сборка (корпус 40 мм)
png assembly_step1.png case_40.scad "-60,-130,130,46,28,0"   -D 'PART="step1"'
png assembly_step2.png case_40.scad "-60,-140,150,46,28,8"   -D 'PART="step2"'
png assembly_step3.png case_40.scad "-60,-140,150,46,28,30"  -D 'PART="step3"'
png assembly_step4.png case_40.scad "-75,-170,190,46,28,25"  -D 'PART="step4"'
png assembly_step5.png case_40.scad "150,200,150,40,40,18"   -D 'PART="step5"'
png assembly_step6.png case_40.scad "150,190,120,46,28,12"   -D 'PART="step6"'
