#!/bin/bash
#  Automatic build script for json-c
#  for iPhoneOS and iPhoneSimulator
#
LIBNAME="json-c"
MINIOSVERSION="7.0"

# variables
ARCHS="i386 x86_64 armv7 armv7s arm64"

DEVELOPER=`xcode-select -print-path`
SDKVERSION=`xcrun -sdk iphoneos --show-sdk-version`

REPOROOT=$(pwd)

DEPSDIR="${REPOROOT}/dependencies"
mkdir -p ${DEPSDIR}

BUILDDIR="${REPOROOT}/build"
INTERDIR="${BUILDDIR}/built"
mkdir -p $BUILDDIR
mkdir -p $INTERDIR

LOG=${REPOROOT}/log.txt

# download
set -e
if [ ! -e "${LIBNAME}" ]; then
echo "Downloading ${LIBNAME}"
git clone https://github.com/json-c/json-c.git ${LIBNAME}
fi
echo "Using ${LIBNAME} from github"
cd ${LIBNAME}
set +e

# bootstrap
echo "Bootstrapping..."
sh autogen.sh >> ${LOG} 2>&1

# start compiling
for ARCH in ${ARCHS} ;do
if [ "${ARCH}" == "i386" ] || [ "${ARCH}" == "x86_64" ] ; then
PLATFORM="iPhoneSimulator"
EXTRA_CONFIG="--host ${ARCH}-apple-darwin"
EXTRA_CFLAGS=""
EXTRA_LDFLAGS=""
else
PLATFORM="iPhoneOS"
EXTRA_CONFIG="--host arm-apple-darwin"
EXTRA_CFLAGS=""
EXTRA_LDFLAGS=""
fi

mkdir -p "${INTERDIR}/${PLATFORM}${SDKVERSION}-${ARCH}.sdk"
echo "Configuring ${PLATFORM}${SDKVERSION}-${ARCH}..."
./configure \
    --disable-shared \
    ${EXTRA_CONFIG} \
    --prefix="${INTERDIR}/${PLATFORM}${SDKVERSION}-${ARCH}.sdk" \
    CC="${DEVELOPER}/usr/bin/gcc -Wno-macro-redefined" \
    LDFLAGS="$LDFLAGS ${EXTRA_LDFLAGS} -arch ${ARCH} -fPIE -miphoneos-version-min=${MINIOSVERSION}" \
    CFLAGS="$CFLAGS ${EXTRA_CFLAGS} -g -O0 -D__APPLE_USE_RFC_3542 -arch ${ARCH} -fPIE -miphoneos-version-min=${MINIOSVERSION} -isysroot ${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer/SDKs/${PLATFORM}${SDKVERSION}.sdk" \
    >> ${LOG} 2>&1

echo "Compiling ${PLATFORM}${SDKVERSION}-${ARCH}..."
make -j 4 >> ${LOG} 2>&1
echo $"Installing ${PLATFORM}${SDKVERSION}-${ARCH}..."
make -j 4 install >> ${LOG} 2>&1

make clean >/dev/null
done

echo "Compiling is done."

########################################
# archive files

function lipo_fat() {
    LIPO_ARGS=" -create "
    for ARCH in ${ARCHS} ;do

    if [ "${ARCH}" == "i386" ] || [ "${ARCH}" == "x86_64" ]; then
    PLATFORM="iPhoneSimulator"
    else
    PLATFORM="iPhoneOS"
    fi

    INPUT_ARCH_LIB="${INTERDIR}/${PLATFORM}${SDKVERSION}-${ARCH}.sdk/$1"
    LIPO_ARGS="${LIPO_ARGS} -arch ${ARCH} ${INPUT_ARCH_LIB} "

    done

    LIPO_ARGS="${LIPO_ARGS} -output ${TARGET}/$1"
    lipo ${LIPO_ARGS}
}

function copy_file() {
    cp -R ${INTERDIR}/iPhoneOS${SDKVERSION}-arm64.sdk/$1 ${TARGET}/$1
}

function copy_dir() {
    cp -R ${INTERDIR}/iPhoneOS${SDKVERSION}-arm64.sdk/$1 ${TARGET}/
}

echo "Archiving..."
TARGET=${REPOROOT}/target
mkdir -p ${TARGET}
mkdir -p ${TARGET}/lib
mkdir -p ${TARGET}/include

lipo_fat "lib/libjson-c.a"
copy_dir "include"

echo "Cleaning up..."
rm -rf ${BUILDDIR}
rm -rf ${DEPSDIR}
rm -rf ${REPOROOT}/${LIBNAME}
echo "Done."
echo "Built here: "${TARGET}
