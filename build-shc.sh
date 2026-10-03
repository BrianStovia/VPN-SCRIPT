#!/usr/bin/env bash
# ==============================================================================
# SHC COMPILER TOOL - SWS-GO AUTOSCRIPT
# Mengompilasi skrip Bash menjadi binary ELF executable (Anti-Bajak / Anti-Intip)
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
NC='\e[0m'

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}       SWS-GO AUTOSCRIPT - SHC SCRIPT COMPILER & ENCRYPTOR   ${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Cek dependensi sistem
if ! command -v shc &>/dev/null || ! command -v gcc &>/dev/null; then
    echo -e "${BLUE}Menginstall dependensi (shc, gcc, make, zip, file)...${NC}"
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -y
        sudo apt-get install -y shc build-essential zip unzip file binutils
    else
        echo -e "${RED}[ERROR] shc atau gcc tidak ditemukan. Silakan pasang terlebih dahulu.${NC}"
        exit 1
    fi
fi

TARGET_DIR="main_zip_extracted"

if [ ! -d "$TARGET_DIR" ]; then
    if [ -f "main.zip" ]; then
        echo -e "${BLUE}Mengekstrak main.zip ke ${TARGET_DIR}...${NC}"
        unzip -q main.zip -d "$TARGET_DIR"
    else
        echo -e "${RED}[ERROR] Direktori ${TARGET_DIR} atau file main.zip tidak ditemukan!${NC}"
        exit 1
    fi
fi

compile_file() {
    local src="$1"
    if [ -f "$src" ] && [ ! -L "$src" ]; then
        case "$src" in
            *.py|*.json|*.toml|*.conf|*.txt|*.key|*.crt|*.pub)
                # Lewati file non-shell
                return 0
                ;;
        esac

        # Periksa apakah file adalah shell script
        if file "$src" 2>/dev/null | grep -qi "shell script"; then
            echo -e "  - Mengompilasi: ${YELLOW}${src}${NC}"
            shc -r -f "$src" -o "${src}.bin"
            if [ -f "${src}.bin" ]; then
                strip "${src}.bin" 2>/dev/null || true
                rm -f "$src" "${src}.x.c"
                mv -f "${src}.bin" "$src"
                chmod 755 "$src"
            else
                echo -e "    ${RED}Gagal mengompilasi ${src}${NC}"
            fi
        fi
    fi
}

echo -e "${BLUE}[1/3] Mengompilasi semua script di ${TARGET_DIR}...${NC}"
for file in "$TARGET_DIR"/*; do
    if [ -d "$file" ]; then
        for subfile in "$file"/*; do
            compile_file "$subfile"
        done
    else
        compile_file "$file"
    fi
done

echo -e "${BLUE}[2/3] Mengemas ulang main.zip dengan binary ELF yang sudah terkompilasi...${NC}"
cd "$TARGET_DIR"
rm -f ../main.zip
zip -q -r ../main.zip ./*
cd ..

echo -e "${BLUE}[3/3] Selesai! Ukuran main.zip baru: $(du -h main.zip 2>/dev/null | cut -f1 || ls -lh main.zip | awk '{print $5}')${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN} Semua script di main.zip sekarang adalah binary ELF stripped!${NC}"
echo -e "${GREEN} Source code bash tidak bisa dibaca/diedit oleh orang lain.    ${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
