#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONAN_HOME="${CONAN_HOME:-/tmp/flutter_midi_pro_conan_home}"
BUILD_ROOT="${BUILD_ROOT:-/tmp/flutter_midi_pro_fluidsynth_build}"
FLUIDSYNTH_VERSION="${FLUIDSYNTH_VERSION:-v2.5.4}"
ANDROID_NDK="${ANDROID_NDK:-/home/tpnsvo/Android/SDK/ndk/30.0.14904198}"
ANDROID_ABI="${ANDROID_ABI:-arm64-v8a}"

case "${ANDROID_ABI}" in
  arm64-v8a)
    CONAN_HOST_PROFILE="android-arm64"
    ANDROID_LIBCXX_DIR="aarch64-linux-android"
    BUILD_SUFFIX="arm64"
    ;;
  x86_64)
    CONAN_HOST_PROFILE="android-x86_64"
    ANDROID_LIBCXX_DIR="x86_64-linux-android"
    BUILD_SUFFIX="x86_64"
    ;;
  *)
    echo "Unsupported ANDROID_ABI='${ANDROID_ABI}'. Supported: arm64-v8a, x86_64" >&2
    exit 2
    ;;
esac

if [[ "${1:-}" == "--help" ]]; then
  echo "Build FluidSynth for Android and copy it into this plugin."
  echo
  echo "Optional environment variables:"
  echo "  CONAN_HOME=${CONAN_HOME}"
  echo "  BUILD_ROOT=${BUILD_ROOT}"
  echo "  FLUIDSYNTH_VERSION=${FLUIDSYNTH_VERSION}"
  echo "  ANDROID_NDK=${ANDROID_NDK}"
  echo "  ANDROID_ABI=${ANDROID_ABI}  # arm64-v8a or x86_64"
  exit 0
fi

SOURCE_DIR="${BUILD_ROOT}/fluidsynth-${FLUIDSYNTH_VERSION}"
BUILD_DIR="${BUILD_ROOT}/build-${BUILD_SUFFIX}"
INSTALL_DIR="${BUILD_ROOT}/install-${BUILD_SUFFIX}"
CONAN_OUT="${BUILD_ROOT}/conan-${BUILD_SUFFIX}"

mkdir -p "${BUILD_ROOT}"

if [[ ! -d "${SOURCE_DIR}/.git" ]]; then
  git clone --depth 1 --branch "${FLUIDSYNTH_VERSION}" \
    https://github.com/FluidSynth/fluidsynth.git "${SOURCE_DIR}"
fi

git -C "${SOURCE_DIR}" submodule update --init --depth 1 gcem

CONAN_HOME="${CONAN_HOME}" conan install "${ROOT_DIR}/tools/conan/deps_probe" \
  --profile:host="${ROOT_DIR}/tools/conan/profiles/${CONAN_HOST_PROFILE}" \
  --profile:build="${ROOT_DIR}/tools/conan/profiles/linux-build" \
  --build=missing \
  -r=conancenter \
  -of="${CONAN_OUT}"

cmake -S "${SOURCE_DIR}" -B "${BUILD_DIR}" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="${CONAN_OUT}/conan_toolchain.cmake" \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON \
  -DSndFile_WITH_EXTERNAL_LIBS=ON \
  -Dosal=cpp11 \
  -Denable-libsndfile=ON \
  -Denable-libinstpatch=OFF \
  -Denable-native-dls=OFF \
  -Denable-opensles=ON \
  -Denable-oboe=OFF \
  -Denable-openmp=OFF \
  -Denable-threads=ON \
  -Denable-alsa=OFF \
  -Denable-pulseaudio=OFF \
  -Denable-pipewire=OFF \
  -Denable-jack=OFF \
  -Denable-portaudio=OFF \
  -Denable-sdl3=OFF \
  -Denable-oss=OFF \
  -Denable-dbus=OFF \
  -Denable-ladspa=OFF \
  -Denable-readline=OFF \
  -Denable-network=OFF \
  -Denable-ipv6=OFF \
  -Denable-aufile=OFF \
  -Denable-midishare=OFF \
  -Denable-floats=ON \
  -DCMAKE_SHARED_LINKER_FLAGS="-Wl,-z,max-page-size=16384"

cmake --build "${BUILD_DIR}" --target install -- -j"$(nproc)"

cp "${INSTALL_DIR}/lib/libfluidsynth.so" \
  "${ROOT_DIR}/android/src/main/cpp/fluidsynth/lib/${ANDROID_ABI}/libfluidsynth.so"
cp "${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/${ANDROID_LIBCXX_DIR}/libc++_shared.so" \
  "${ROOT_DIR}/android/src/main/cpp/fluidsynth/lib/${ANDROID_ABI}/libc++_shared.so"
cp -R "${INSTALL_DIR}/include/." "${ROOT_DIR}/android/src/main/cpp/fluidsynth/include/"

readelf -lW "${ROOT_DIR}/android/src/main/cpp/fluidsynth/lib/${ANDROID_ABI}/libfluidsynth.so" \
  | awk '$1 == "LOAD" && $NF != "0x4000" { bad = 1 } END { exit bad }'
readelf -lW "${ROOT_DIR}/android/src/main/cpp/fluidsynth/lib/${ANDROID_ABI}/libc++_shared.so" \
  | awk '$1 == "LOAD" && $NF != "0x4000" { bad = 1 } END { exit bad }'

echo "FluidSynth ${FLUIDSYNTH_VERSION} ${ANDROID_ABI} rebuild complete."
