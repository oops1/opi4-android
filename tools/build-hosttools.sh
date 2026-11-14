#!/bin/bash -e
# Builds the x86_64 host tools that Mesa >= 25 needs to cross-build Panfrost for Android:
#   mesa_clc, vtn_bindgen2 (OpenCL C -> SPIR-V -> NIR) and panfrost_compile (libpan precomp).
# They are built from the SAME Mesa tree as the Android build (glodroid/vendor/mesa3d) and
# installed to ~/opi4/hosttools/bin; env.sh puts that dir on PATH, BoardConfig.mk passes
# -Dmesa-clc=system -Dprecomp-compiler=system so the Android-side Mesa build needs no LLVM.
#
# Needs (Ubuntu 22.04): llvm-15-dev libclang-15-dev libclc-15-dev libllvmspirvlib-15-dev libdrm-dev
# SPIRV-Tools >= 2024.1 is built here from the AOSP tree (Ubuntu 22.04 ships 2022.1).
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
AOSP=${AOSP:-$HOME/aosp}
HT=${HT:-$HOME/opi4/hosttools}
W=$HT/work
mkdir -p $HT/bin $W

echo "== SPIRV-Tools from $AOSP/external/SPIRV-Tools"
if [ ! -f $HT/lib/pkgconfig/SPIRV-Tools.pc ]; then
  cmake -S $AOSP/external/SPIRV-Tools -B $W/spirv-tools -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$HT \
    -DSPIRV-Headers_SOURCE_DIR=$AOSP/external/SPIRV-Headers \
    -DSPIRV_SKIP_TESTS=ON -DSPIRV_WERROR=OFF -DSPIRV_TOOLS_BUILD_STATIC=ON > $W/spirv-tools.log
  ninja -C $W/spirv-tools install >> $W/spirv-tools.log
fi
ls $HT/lib/pkgconfig/

echo "== Mesa host tools from $AOSP/glodroid/vendor/mesa3d"
cat > $W/native.ini <<EOF
[binaries]
llvm-config = '/usr/bin/llvm-config-15'
EOF
rm -rf $W/mesa
PKG_CONFIG_PATH=$HT/lib/pkgconfig:$HT/lib64/pkgconfig meson setup $W/mesa $AOSP/glodroid/vendor/mesa3d \
  --native-file $W/native.ini --buildtype=release \
  -Dplatforms= -Dglx=disabled -Degl=disabled -Dgbm=disabled -Dgles1=disabled -Dgles2=disabled \
  -Dgallium-drivers=panfrost -Dvulkan-drivers= -Dllvm=enabled -Dshared-llvm=enabled \
  -Dmesa-clc=enabled -Dinstall-mesa-clc=true -Dprecomp-compiler=enabled -Dinstall-precomp-compiler=true \
  -Dvalgrind=disabled -Dlibunwind=disabled -Dlmsensors=disabled -Dzstd=disabled > $W/mesa-setup.log 2>&1 \
  || { tail -30 $W/mesa-setup.log; exit 1; }
ninja -C $W/mesa src/compiler/clc/mesa_clc src/compiler/spirv/vtn_bindgen2 src/panfrost/clc/panfrost_compile > $W/mesa-build.log 2>&1 \
  || { grep -E 'error|FAILED' $W/mesa-build.log | head -30; exit 1; }
cp $W/mesa/src/compiler/clc/mesa_clc $W/mesa/src/compiler/spirv/vtn_bindgen2 $W/mesa/src/panfrost/clc/panfrost_compile $HT/bin/
ls -la $HT/bin
$HT/bin/mesa_clc --help 2>&1 | head -3 || true
echo "== done: host tools in $HT/bin"
