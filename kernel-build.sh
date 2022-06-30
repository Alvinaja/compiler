#!/usr/bin/bash
# Written by: cyberknight777
# YAKB v1.0
# Copyright (c) 2022-2023 Cyber Knight <cyberknight755@gmail.com>
#
#			GNU GENERAL PUBLIC LICENSE
#			 Version 3, 29 June 2007
#
# Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
# Everyone is permitted to copy and distribute verbatim copies
# of this license document, but changing it is not allowed.

# Some Placeholders: [!] [*] [✓] [✗]

# A function to send message(s) via Telegram's BOT api.
tg() {
    curl -sX POST https://api.telegram.org/bot"${TG_TOKEN}"/sendMessage \
        -d chat_id="$TG_CHAT_ID" \
        -d parse_mode=html \
        -d disable_web_page_preview=true \
        -d text="$1"
}

tgs() {
    SHA1=$(sha1sum "$1" | cut -d' ' -f1)
    curl -fsSL -X POST -F document=@"$1" https://api.telegram.org/bot"${TG_TOKEN}"/sendDocument \
        -F "chat_id=$TG_CHAT_ID" \
        -F "parse_mode=Markdown" \
        -F "caption=$2"
}

tgf() {
    SHA1=$(sha1sum "$1" | cut -d' ' -f1)
    curl -fsSL -X POST -F document=@"$1" https://api.telegram.org/bot"${TG_TOKEN}"/sendDocument \
        -F "chat_id=$TG_CHAT_ID" \
        -F "parse_mode=Markdown" \
        -F "caption=$2"
}

# Default defconfig to use for builds.
CONFIG="merlin_defconfig"

# Default directory where kernel is located in.
KDIR=$(pwd)

# Kernel Name
KNAME=$(cat "arch/arm64/configs/$CONFIG" | grep "CONFIG_LOCALVERSION=" | sed 's/CONFIG_LOCALVERSION="-*//g' | sed 's/"*//g' )

# Device and codename.
DEVICE="Redmi Note 9"
CODENAME="merlin"

# User and Host name
BUILDER=Himemori
HOST=XZI-TEAM

# Number of jobs to run.
PROCS=$(nproc --all)

# Another stuff
DATE=$(date +"%m%d")
HEAD="$(git log --pretty=format:'%h' -n1)"
KERVER=$(make kernelversion)

Ai1() {

    echo -e "\n\e[1;93m[*] Cloning toolchain for build! \e[0m"
    git clone https://github.com/mvaisakh/gcc-arm64 -b gcc-master  --depth=1 "${KDIR}"/gcc64
    git clone https://github.com/mvaisakh/gcc-arm -b gcc-master --depth=1 "${KDIR}"/gcc32
    git clone https://github.com/Himemoria/AnyKernel3 -b merlin --depth=1 "${KDIR}"/anykernel3
    echo -e "\n\e[1;32m[✓] Successful cloning all toolchain! \e[0m"

    LLD_VER=$("${KDIR}"/gcc64/bin/aarch64-elf-ld.lld -v | head -n1 | sed 's/(compatible with [^)]*)//' |
            head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
    KBUILD_COMPILER_STRING=$("${KDIR}"/gcc64/bin/aarch64-elf-gcc --version | head -n 1)
    export KBUILD_COMPILER_STRING
    export PATH="${KDIR}"/gcc64/bin/:"${KDIR}"/gcc32/bin/:/usr/bin:$PATH
    MAKE+=(
        ARCH=arm64
        O=out
        CROSS_COMPILE=aarch64-elf-
        CROSS_COMPILE_ARM32=arm-eabi-
        LD=aarch64-elf-ld.lld
        AR=llvm-ar
        NM=llvm-nm
        OBJDUMP=llvm-objdump
        OBJCOPY=llvm-objcopy
        OBJSIZE=llvm-objsize
        STRIP=llvm-strip
        HOSTAR=llvm-ar
        HOSTCC=gcc
        HOSTCXX=aarch64-elf-g++
        CC=aarch64-elf-gcc
        CONFIG_SECTION_MISMATCH_WARN_ONLY=y
        CONFIG_DEBUG_SECTION_MISMATCH=y
    )

    export KBUILD_BUILD_VERSION=$GITHUB_RUN_NUMBER
    export KBUILD_BUILD_HOST=$HOST
    export KBUILD_BUILD_USER=$BUILDER
    zipn=[$DATE][$KERVER]$KNAME[$CODENAME][R-OSS]-$HEAD


#    echo -e "\n\e[1;93m[*] Regenerating defconfig! \e[0m"
#    make "${MAKE[@]}" $CONFIG
#    cp -rf "${KDIR}"/out/.config "${KDIR}"/arch/arm64/configs/xiaomi/$CONFIG
#    echo -e "\n\e[1;32m[✓] Defconfig regenerated! \e[0m"


tg "
<b>Date</b>: <code>$(date)</code>
<b>Device</b>: <code>${DEVICE}</code>
<b>Kernel Version</b>: <code>$(make kernelversion 2>/dev/null)</code>
<b>Zip Name</b>: <code>${zipn}</code>
<b>Compiler</b>: <code>${KBUILD_COMPILER_STRING}</code>
<b>Linker</b>: <code>${LLD_VER}</code>
"


    echo -e "\n\e[1;93m[*] Building Kernel! \e[0m"
    BUILD_START=$(date +"%s")
    time make -j"$PROCS" "$CONFIG" "${MAKE[@]}" Image.gz dtbo.img 2>&1 | tee log.txt
    BUILD_END=$(date +"%s")
    DIFF=$((BUILD_END - BUILD_START))
    if [ -f "${KDIR}/out/arch/arm64/boot/Image.gz" ]; then
        echo -e "\n\e[1;32m[✓] Kernel built after $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)! \e[0m"
    else
            tgf "log.txt" "*❌ Build failed after*: $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s) "
        echo -e "\n\e[1;31m[✗] Build Failed! \e[0m"
        exit 1
    fi

    echo -e "\n\e[1;93m[*] Building DTBS! \e[0m"
    time make -j"$PROCS" "${MAKE[@]}" dtbs dtbo.img
    echo -e "\n\e[1;32m[✓] Built DTBS! \e[0m"

        tg "<b>Building zip!</b>"
    echo -e "\n\e[1;93m[*] Building zip! \e[0m"
    mv "${KDIR}"/out/arch/arm64/boot/dtbo.img "${KDIR}"/anykernel3
    mv "${KDIR}"/out/arch/arm64/boot/dts/mediatek/mt6768.dtb "${KDIR}"/anykernel3/dtb
    mv "${KDIR}"/out/arch/arm64/boot/Image.gz "${KDIR}"/anykernel3
    cd "${KDIR}"/anykernel3 || exit 1
    zip -r9 "$zipn".zip . -x ".git*" -x "README.md" -x "LICENSE" -x "*.zip"

    echo -e "\n\e[1;93m[*] Push zip into channel! \e[0m"
        tgs "$zipn.zip" "*✅ Build success after*: $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
}
Ai1
