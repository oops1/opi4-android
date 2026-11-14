# Source this before building:  . ~/opi4/opi4-android/tools/env.sh [opi4|opi4_tv]
# Strips Windows paths that WSL appends to PATH (spaces/parentheses break parts of the build).
export PATH=$HOME/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
cd ${AOSP:-$HOME/aosp}
. build/envsetup.sh >/dev/null
lunch ${1:-opi4}-trunk_staging-userdebug
