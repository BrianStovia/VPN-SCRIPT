#!/usr/bin/env bash
{
# Clear SUDO_USER to bypass acme.sh warnings under sudo
export SUDO_USER=""

# Define Colors
green="\e[1;32m"
red="\e[1;31m"
blue="\e[1;34m"
NC="\e[0m"

# Check if run as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${red}Error: Silakan jalankan script ini sebagai root (sudo bash update)${NC}"
    exit 1
fi

# =========================================================================
# KONFIGURASI LISENSI & PERMISSION SERVER (ANTI-BAJAK)
# =========================================================================
PERMISSION_URL="https://raw.githubusercontent.com/BrianStovia/permission/main/ip"
PERMISSION_FALLBACK_URL="https://raw.githubusercontent.com/BrianStovia/VPN-SCRIPT/main/permission.txt"
ADMIN_TELEGRAM="@BrianStovia"

check_permission() {
    local my_ip=""
    my_ip=$(curl -sS --max-time 5 https://ipv4.icanhazip.com 2>/dev/null | tr -d '[:space:]')
    [ -z "$my_ip" ] && my_ip=$(curl -sS --max-time 5 http://checkip.amazonaws.com 2>/dev/null | tr -d '[:space:]')
    [ -z "$my_ip" ] && my_ip=$(curl -sS --max-time 5 https://api.ipify.org 2>/dev/null | tr -d '[:space:]')

    if [ -z "$my_ip" ]; then
        echo -e "${red}[ERROR] Gagal mendeteksi IP publik VPS.${NC}"
        exit 1
    fi

    local cache_buster="?v=$(date +%s)"
    local raw_data=""
    raw_data=$(curl -sS --max-time 8 "${PERMISSION_URL}${cache_buster}" 2>/dev/null)
    if [ -z "$raw_data" ] || echo "$raw_data" | grep -qi "404: Not Found"; then
        raw_data=$(curl -sS --max-time 8 "${PERMISSION_FALLBACK_URL}${cache_buster}" 2>/dev/null)
    fi

    if [ -z "$raw_data" ] || echo "$raw_data" | grep -qi "404: Not Found"; then
        echo -e "${red}[ERROR] Gagal menghubungi server lisensi.${NC}"
        exit 1
    fi

    local match_line=""
    match_line=$(echo "$raw_data" | grep -E "(^|[[:space:]])${my_ip}([[:space:]]|$)" | head -n 1)

    if [ -z "$match_line" ]; then
        clear
        echo -e "${red}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${red}               AKSES DITOLAK / PERMISSION DENIED             ${NC}"
        echo -e "${red}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e " IP VPS ${my_ip} tidak terdaftar dalam izin resmi."
        echo -e " Hubungi Admin: ${ADMIN_TELEGRAM}"
        echo -e "${red}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        exit 1
    fi

    local exp_date="2099-12-31"
    if echo "$match_line" | grep -q "^###"; then
        exp_date=$(echo "$match_line" | awk '{print $3}')
    else
        if [ "$(echo "$match_line" | awk '{print $1}')" = "$my_ip" ]; then
            exp_date=$(echo "$match_line" | awk '{print $2}')
        fi
    fi

    local today=$(date +%Y-%m-%d)
    local today_sec=$(date -d "$today" +%s 2>/dev/null || date +%s)
    local exp_sec=$(date -d "$exp_date" +%s 2>/dev/null || echo 0)

    if [ "$exp_sec" -ne 0 ] && [ "$exp_sec" -lt "$today_sec" ]; then
        echo -e "${red}[ERROR] Masa aktif lisensi Anda telah habis (${exp_date}).${NC}"
        exit 1
    fi
}

check_permission

# Define Hosting
hosting="https://raw.githubusercontent.com/BrianStovia/VPN-SCRIPT/main"

# Get directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to get file from hosting atomically (prevents Text file busy ETXTBSY on running binaries)
get_file() {
    local source_name="$1"
    local dest_path="$2"
    local cache_buster="?v=$(date +%s)"
    local tmp_path="${dest_path}.tmp_dl"

    rm -f "${tmp_path}"
    wget -q -O "${tmp_path}" "${hosting}/${source_name}${cache_buster}"
    if [ $? -ne 0 ] || [ ! -s "${tmp_path}" ]; then
        wget -q -O "${tmp_path}" "${hosting}/file/${source_name}${cache_buster}"
        if [ $? -ne 0 ] || [ ! -s "${tmp_path}" ]; then
            rm -f "${tmp_path}"
            echo -e "${red}Error: Gagal mengunduh ${source_name} dari hosting!${NC}"
            return 1
        fi
    fi
    chmod 755 "${tmp_path}" 2>/dev/null || true
    mv -f "${tmp_path}" "${dest_path}"
    return 0
}

clear
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "$green              Updating Autoscript VPS/VPN               	$NC"
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

# 1. Auto Backup V2Ray Configuration
if [ -f "/usr/local/etc/v2ray/config.json" ]; then
    echo -e "${blue}[1/7] Mencadangkan akun V2Ray otomatis...${NC}"
    cp /usr/local/etc/v2ray/config.json /root/v2ray_backup_before_update.json
    echo -e "${green}Backup disimpan di /root/v2ray_backup_before_update.json${NC}"
else
    echo -e "${blue}[1/7] Tidak ada konfigurasi V2Ray untuk dicadangkan.${NC}"
fi

# 2. Update install.sh and uninstall.sh
echo -e "${blue}[2/7] Mengunduh script installer & uninstaller baru...${NC}"
get_file "install.sh" "/usr/local/sbin/install.sh"
chmod +x /usr/local/sbin/install.sh
get_file "uninstall.sh" "/usr/local/sbin/uninstall"
chmod +x /usr/local/sbin/uninstall
ln -sf /usr/local/sbin/uninstall /usr/bin/uninstall

# 3. Update Menu Scripts
echo -e "${blue}[3/7] Memperbarui menu sbin...${NC}"
mkdir -p /usr/local/sbin
cd /usr/local/sbin
wget -q -O m.zip "${hosting}/main.zip"
if [ $? -eq 0 ]; then
    unzip -o m.zip &>/dev/null
    chmod +x *
    rm -f m.zip

    # Proteksi Anti-Bajak: Kompilasi script shell ke binary ELF stripped menggunakan SHC
    if command -v shc &>/dev/null; then
        echo -e "${blue}Mengamankan script sbin dengan SHC...${NC}"
        for s_file in /usr/local/sbin/* /usr/local/sbin/api/*; do
            if [ -f "$s_file" ] && [ ! -L "$s_file" ]; then
                case "$s_file" in
                    *.py|*.json|*.toml|*.conf|*.txt|*.key|*.crt|*.pub) continue ;;
                esac
                if file "$s_file" 2>/dev/null | grep -qi "shell script"; then
                    shc -r -f "$s_file" -o "${s_file}.bin" 2>/dev/null
                    if [ -f "${s_file}.bin" ]; then
                        strip "${s_file}.bin" 2>/dev/null || true
                        mv -f "${s_file}.bin" "$s_file"
                        rm -f "${s_file}.x.c" 2>/dev/null
                        chmod 755 "$s_file"
                    fi
                fi
            fi
        done
    fi

    # Symlink custom scripts to /usr/bin
    for file in /usr/local/sbin/*; do
        if [ -f "$file" ]; then
            ln -sf "$file" "/usr/bin/$(basename "$file")"
        fi
    done
fi
cd

# 4. Update Binaries and Helper Scripts (Go binaries)
echo -e "${blue}[4/7] Memperbarui binari sistem (Go)...${NC}"
systemctl stop proxy server 2>/dev/null || true
get_file "bin/server" "/usr/bin/server"
chmod +x /usr/bin/server
get_file "bin/proxy" "/usr/local/bin/proxy"
chmod +x /usr/local/bin/proxy
get_file "bin/ssh-limit" "/usr/local/sbin/ssh-limit"
chmod +x /usr/local/sbin/ssh-limit
ln -sf /usr/local/sbin/ssh-limit /usr/bin/ssh-limit
systemctl restart proxy server 2>/dev/null || true

# 5. Update Configuration Files while preserving Reality Keys
echo -e "${blue}[5/7] Memperbarui file konfigurasi...${NC}"

# Update UDP Custom configuration
get_file "udp.json" "/etc/udp/config.json"
chmod 644 /etc/udp/config.json

# Update SSH Banner
get_file "issue.net" "/etc/issue.net"

# Update SSLH configuration for high performance TLS routing
get_file "sslh" "/etc/default/sslh"
chmod 755 /etc/default/sslh

# Install speedtest-cli if missing
if ! command -v speedtest-cli &> /dev/null && ! command -v speedtest &> /dev/null; then
    echo -e "${blue}Menginstal speedtest-cli...${NC}"
    apt-get update &>/dev/null
    apt-get install -y speedtest-cli &>/dev/null
fi

# Disable Netdata if installed
if command -v netdata &> /dev/null; then
    echo -e "${blue}Menonaktifkan Netdata Web Dashboard...${NC}"
    systemctl stop netdata &>/dev/null
    systemctl disable netdata &>/dev/null
fi

# Update Nginx configuration while preserving server name (domain)
if [ -f "/etc/nginx/nginx.conf" ]; then
    if [ -f "/usr/local/etc/v2ray/domain" ]; then
        domain=$(cat /usr/local/etc/v2ray/domain)
    else
        domain="domain"
    fi
    get_file "nginx.conf" "/etc/nginx/nginx.conf"
    sed -i "s|server_name .*;|server_name $domain;|" /etc/nginx/nginx.conf
    # Remove IPv6 listen directives if VPS kernel does not support IPv6
    if [ ! -f /proc/net/if_inet6 ]; then
        sed -i '/listen \[::\]/d' /etc/nginx/nginx.conf 2>/dev/null || true
    fi
fi

# Ensure web root exists
mkdir -p /var/www/html /etc/nginx

# Ensure Netdata Basic Auth password file exists
if [ ! -f "/etc/nginx/.htpasswd" ]; then
    if [ -f "/usr/local/etc/v2ray/domain" ]; then
        domain=$(cat /usr/local/etc/v2ray/domain)
    else
        domain="domain"
    fi
    netdata_pass="admin$(echo "$domain" | tr -d '.')"
    pass_hash=$(openssl passwd -1 "$netdata_pass")
    echo "admin:$pass_hash" > /etc/nginx/.htpasswd
fi

# Verify SSL certificate integrity for Nginx/V2Ray (prevent Nginx crash if cert is empty/corrupt)
if [ ! -s "/usr/local/etc/v2ray/v2ray.crt" ] || [ ! -s "/usr/local/etc/v2ray/v2ray.key" ] || ! grep -q "BEGIN CERTIFICATE" /usr/local/etc/v2ray/v2ray.crt 2>/dev/null; then
    echo -e "${blue}Sertifikat SSL kosong/rusak. Membuat sertifikat pemulihan...${NC}"
    mkdir -p /usr/local/etc/v2ray
    rm -f /usr/local/etc/v2ray/v2ray.key /usr/local/etc/v2ray/v2ray.crt
    openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
        -subj "/C=ID/ST=Jakarta/L=Jakarta/O=FNProject/CN=${domain:-domain}" \
        -keyout /usr/local/etc/v2ray/v2ray.key \
        -out /usr/local/etc/v2ray/v2ray.crt &>/dev/null
    chmod 644 /usr/local/etc/v2ray/v2ray.crt 2>/dev/null || true
    chmod 600 /usr/local/etc/v2ray/v2ray.key 2>/dev/null || true
fi

# Update Xray config.json
if [ -f "/usr/local/etc/v2ray/config.json" ]; then
    # Backup existing config
    cp /usr/local/etc/v2ray/config.json /usr/local/etc/v2ray/config.json.bak
    
    # Check if WARP SOCKS5 proxy was enabled in backup config
    warp_enabled=0
    if grep -q -E '"port"\s*:\s*40000' /usr/local/etc/v2ray/config.json.bak 2>/dev/null; then
        warp_enabled=1
    fi
    
    # Download clean config.json
    get_file "config.json" "/usr/local/etc/v2ray/config.json"
    
    # Run merge script to preserve existing accounts
    if [ -f "/usr/local/sbin/merge_config.py" ]; then
        python3 /usr/local/sbin/merge_config.py
    fi
    
    # Restore WARP SOCKS5 proxy if it was enabled
    if [ "$warp_enabled" -eq 1 ]; then
        echo "Restoring Cloudflare WARP proxy outbound..."
        python3 /usr/local/sbin/toggle_warp.py enable
    fi
    
    # Verify configuration syntax
    if [ -f "/usr/local/bin/xray" ]; then
        /usr/local/bin/xray -test -config /usr/local/etc/v2ray/config.json &>/dev/null
        if [ $? -ne 0 ]; then
            echo -e "${red}Error: Konfigurasi baru V2Ray tidak valid! Mengembalikan ke konfigurasi sebelumnya...${NC}"
            cp /usr/local/etc/v2ray/config.json.bak /usr/local/etc/v2ray/config.json
        fi
    fi
fi

# 6. Reload services
echo -e "${blue}[6/7] Memulai ulang layanan & optimasi jaringan...${NC}"
# Fix missing systemd users and ensure systemd-networkd is enabled
systemd-sysusers 2>/dev/null || true
chmod 644 /etc/passwd /etc/group 2>/dev/null || true

# Pastikan systemd-networkd config untuk interface ens masih ada (anti-drop saat restart)
primary_interface=$(ip route | grep default | awk '{print $5}')
if [ -n "$primary_interface" ] && [ ! -f "/etc/systemd/network/10-${primary_interface}.network" ]; then
    echo -e "${blue}Membuat konfigurasi systemd-networkd untuk ${primary_interface}...${NC}"
    mkdir -p /etc/systemd/network
    cat > /etc/systemd/network/10-${primary_interface}.network << EOF
[Match]
Name=${primary_interface}

[Network]
DHCP=yes
IPv6AcceptRA=no

[DHCP]
UseDNS=yes
RouteMetric=100
SendHostname=yes

[Link]
KeepConfiguration=dhcp-on-stop
RequiredForOnline=yes
ActivationPolicy=always-up
EOF
fi

# Pastikan net-watchdog timer berjalan
if [ -f "/etc/systemd/system/net-watchdog.timer" ]; then
    systemctl enable net-watchdog.timer &>/dev/null
    systemctl start net-watchdog.timer &>/dev/null
fi

systemctl enable systemd-networkd 2>/dev/null || true
systemctl enable systemd-networkd-wait-online 2>/dev/null || true
systemctl start systemd-networkd 2>/dev/null || true

# Apply network kernel optimization for low latency gaming & bufferbloat control
mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/99-vpn.conf << EOF
fs.file-max = 2097152
net.core.default_qdisc = fq_codel
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.rmem_default = 33554432
net.core.wmem_default = 33554432
net.core.optmem_max = 2048576
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 1440000
net.ipv4.tcp_tw_reuse = 1
net.core.netdev_max_backlog = 10000
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384
net.core.somaxconn = 32768
net.ipv4.udp_mem = 114112 152152 228224
EOF
sysctl --system &>/dev/null || true

# Update BadVPN MTU to 1380 to prevent packet fragmentation & lag spikes for gaming
sed -i 's/--udp-mtu 9000/--udp-mtu 1380/g' /etc/systemd/system/badvpn*.service 2>/dev/null || true

systemctl daemon-reload
systemctl restart udp-custom &>/dev/null
systemctl restart badvpn-7100 &>/dev/null
systemctl restart badvpn-7200 &>/dev/null
systemctl restart badvpn-7300 &>/dev/null
systemctl restart badvpn &>/dev/null
systemctl restart v2ray &>/dev/null
# Check if V2Ray running successfully, if not auto rollback to pre-update backup
sleep 1.5
if ! systemctl is-active --quiet v2ray; then
    echo -e "${red}Error: Layanan V2Ray gagal berjalan dengan konfigurasi baru!${NC}"
    if [ -f "/root/v2ray_backup_before_update.json" ]; then
        echo -e "${blue}Mengembalikan konfigurasi cadangan secara otomatis...${NC}"
        cp /root/v2ray_backup_before_update.json /usr/local/etc/v2ray/config.json
        systemctl restart v2ray &>/dev/null
        if systemctl is-active --quiet v2ray; then
            echo -e "${green}Berhasil memulihkan layanan V2Ray menggunakan cadangan sebelum update!${NC}"
        else
            echo -e "${red}Fatal: V2Ray tetap gagal berjalan bahkan setelah memulihkan cadangan!${NC}"
        fi
    fi
fi
systemctl restart nginx &>/dev/null
systemctl restart sslh &>/dev/null
systemctl restart proxy &>/dev/null
systemctl restart server &>/dev/null
systemctl restart cron &>/dev/null

# Update Telegram bot if installed
if [ -f "/etc/systemd/system/vpn-bot.service" ]; then
    echo -e "${blue}Memperbarui & me-restart Telegram Bot Panel...${NC}"
    systemctl restart vpn-bot &>/dev/null
fi

# 7. Self Update update.sh
echo -e "${blue}[7/7] Memperbarui script update...${NC}"
get_file "update.sh" "/usr/local/sbin/update.tmp"
chmod +x /usr/local/sbin/update.tmp
mv -f /usr/local/sbin/update.tmp /usr/local/sbin/update
ln -sf /usr/local/sbin/update /usr/bin/update

echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "$green               Update Berhasil Selesai!               	$NC"
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
exit 0
}
