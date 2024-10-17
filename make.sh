#!/bin/bash

# Script version
SCRIPT_VERSION="1.2"

set -e

# Define global variables
SRC="$(pwd)"
KBUILD_BUILD_USER="Itachi"
KBUILD_BUILD_HOST="Konoha"
ANYKERNEL3_DIR=AK
FINAL_KERNEL_ZIP=""
BUILD_START=""
DEVICE=A225G
VERSION=$(git rev-parse --abbrev-ref HEAD)  # Get the current branch name
KERNEL_DEFCONFIG=a22x_defconfig
LOG_FILE="${SRC}/build.log"
COMPILATION_LOG="${SRC}/compilation.log"
KERNEL_DIR=$(pwd)

# Define architecture
ARCH=arm64
ANDROID_MAJOR_VERSION=r

# Remove old kernel zip files
rm -rf *.zip
rm -rf AK/Image
rm -rf AK/*.zip

# Color definitions
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
cyan='\033[0;36m'
nocol='\033[0m'

# Function to log messages
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Function to check required tools
check_tools() {
    local tools=("git" "curl" "wget" "make" "zip")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log "$red Tool $tool is required but not installed. Aborting... $nocol"
            exit 1
        fi
    done
}

# Function to check for Telegram credentials
check_telegram_credentials() {
    if [[ -z "${CHAT_ID}" || -z "${BOT_TOKEN}" ]]; then
        if [[ -f "${SRC}/SEND_TO_TG.txt" ]]; then
            log "$yellow Using Telegram credentials from SEND_TO_TG.txt $nocol"
            CHAT_ID=$(grep 'CHAT_ID' "${SRC}/SEND_TO_TG.txt" | cut -d '=' -f2)
            BOT_TOKEN=$(grep 'BOT_TOKEN' "${SRC}/SEND_TO_TG.txt" | cut -d '=' -f2)

            # Check if credentials are still empty
            if [[ -z "${CHAT_ID}" || -z "${BOT_TOKEN}" ]]; then
                prompt_for_telegram_credentials
            fi
        else
            log "$red CHAT_ID and BOT_TOKEN are not set and SEND_TO_TG.txt is missing. $nocol"
            prompt_for_telegram_credentials
        fi
    else
        log "$green Telegram credentials found in environment variables. $nocol"
    fi
}

# Function to set up toolchain
set_toolchain() {
    # Toolchain directory
    TOOLCHAIN_DIR="/home/itachi/toolchain"

    # Check if toolchain exists, if not clone it
    if [ ! -d "${TOOLCHAIN_DIR}" ]; then
        log "Toolchain not found in ${TOOLCHAIN_DIR}, cloning..."
        git clone --depth=1 https://gitlab.com/neel0210/toolchain.git "${TOOLCHAIN_DIR}"
    else
        log "Toolchain found at ${TOOLCHAIN_DIR}"
    fi

    # Set GCC, Clang, and Clang Triple paths
    GCC64_PATH="${TOOLCHAIN_DIR}/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-"
    CLANG_PATH="${TOOLCHAIN_DIR}/clang/host/linux-x86/clang-r383902/bin/clang"
    CLANG_TRIPLE_PATH="${TOOLCHAIN_DIR}/clang/host/linux-x86/clang-r383902/bin/aarch64-linux-gnu-"
}

# Function to perform clean build
perform_clean_build() {
    log "$blue Performing clean build... $nocol"
    make clean
    rm -rf *.log
}

# Function to build the kernel
build_kernel() {
    log "$blue **** Kernel defconfig is set to $KERNEL_DEFCONFIG **** $nocol"
    log "$blue ***********************************************"
    log "          BUILDING KAKAROT KERNEL          "
    log "*********************************************** $nocol"
    
    # Set the defconfig
    make -C $(pwd) O=$(pwd)/out KCFLAGS=-w CONFIG_SECTION_MISMATCH_WARN_ONLY=y LLVM=1 LLVM_IAS=1 a22x_defconfig \
    make -C $(pwd) O=$(pwd)/out KCFLAGS=-w CONFIG_SECTION_MISMATCH_WARN_ONLY=y LLVM=1 LLVM_IAS=1 -j8 \
        ARCH="$ARCH" \
        CC="$CLANG_PATH" \
        CLANG_TRIPLE="$CLANG_TRIPLE_PATH" \
        CROSS_COMPILE="$GCC64_PATH" \
        export ARCH=arm64 \
        PLATFORM_VERSION=13 \
        TARGET_SOC=mt6833 \
        KCFLAGS=-w \
        CONFIG_SECTION_MISMATCH_WARN_ONLY=y \
        CONFIG_NO_ERROR_ON_MISMATCH=y
}

# Function to send logs to Telegram and exit
send_logs_and_exit() {
    local caption=$(printf "<b>Branch Name:</b> %s\n<b>Last commit:</b> %s" "$(sanitize_for_telegram "$(git rev-parse --abbrev-ref HEAD)")" "$(sanitize_for_telegram "$(git log -1 --format=%B)")")
    curl -F "document=@$COMPILATION_LOG" --form-string "caption=${caption}" "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument?chat_id=${CHAT_ID}&parse_mode=HTML"
    exit 1
}

# Function to sanitize text for Telegram
sanitize_for_telegram() {
    local input="$1"
    echo "$input" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

# Function to zip kernel files
zip_kernel_files() {
    log "$blue **** Verifying AnyKernel3 Directory **** $nocol"

    if [ ! -d "$SRC/AK" ]; then
        git clone --depth=1 https://github.com/neel0210/AnyKernel3.git -b A22 AK
    else
        log "$blue AnyKernel3 (AK) already present! $nocol"
    fi

    cp "$SRC/out/arch/arm64/boot/Image.gz" "$ANYKERNEL3_DIR/"
    
    log "$cyan ***********************************************"
    log "          Time to zip up!          "
    log "*********************************************** $nocol"
    
    FINAL_KERNEL_ZIP="KKRT-${VERSION}-${DEVICE}-$(date +"%F_%H%M%S").zip"
    cd "$ANYKERNEL3_DIR/" || exit
    zip -r9 "../$FINAL_KERNEL_ZIP" * -x README "$FINAL_KERNEL_ZIP"
}

# Function to upload kernel to Telegram
upload_kernel_to_telegram() {
    log "$red ***********************************************"
    log "         Uploading to telegram         "
    log "*********************************************** $nocol"

    # Change to Kernel source directory for accurate commit info

    # Create the caption text
    cd "$KERNEL_DIR" || exit 1
    caption=$(printf "<b>Branch Name:</b> %s\n<b>Last commit:</b> %s" "$(sanitize_for_telegram "$(git rev-parse --abbrev-ref HEAD)")" "$(sanitize_for_telegram "$(git log -1 --format=%B)")")
    cd "$SRC" || exit 1

    # Change to source directory where ZIP files are located
    cd "$SRC" || exit 1

    # Upload Time!!
    for i in *.zip; do
        if [ ! -f "$i" ]; then
            log "$red File $i does not exist! Skipping upload. $nocol"
            continue
        fi
        
        # Use -s for silent mode and -S to show errors if they occur
        response=$(curl -s -S -F "document=@$i" --form-string "caption=${caption}" "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument?chat_id=${CHAT_ID}&parse_mode=HTML")

        # Log the response if necessary
        log "$green Response from Telegram: $response $nocol"
    done
    
    # Upload log file with branch name and last commit
    if [ -f "$COMPILATION_LOG" ]; then
        response=$(curl -s -S -F "document=@$COMPILATION_LOG" --form-string "caption=${caption}" "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument?chat_id=${CHAT_ID}&parse_mode=HTML")
        log "$green Response from Telegram: $response $nocol"
    else
        log "$red Compilation log file does not exist! Skipping upload. $nocol"
    fi
}



# Function to clean up
clean_up() {
    log "$cyan ***********************************************"
    log "          All done !!!         "
    log "*********************************************** $nocol"
    rm -rf "$ANYKERNEL3_DIR"
}

# Main script execution
check_tools
check_telegram_credentials
set_toolchain
BUILD_START=$(date +"%s")
perform_clean_build
build_kernel
zip_kernel_files

BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))
log "$yellow Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds. $nocol"

upload_kernel_to_telegram
clean_up
