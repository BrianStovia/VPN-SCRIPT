#!/usr/bin/env bash

# Define Colors
red="\e[1;31m"
green="\e[1;32m"
yellow="\e[1;33m"
blue="\e[1;34m"
NC="\e[0m"

# Check if run as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${red}Error: Silakan jalankan script ini sebagai root (sudo bash uninstall.sh)${NC}"
    exit 1
fi

clear
echo -e "${yellow}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${green}                 Uninstalling Autoscript...                  ${NC}"
echo -e "${yellow}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 1. Stop and Disable Services
services=(
    "vpn-bot"
    "netdata"
    "server"
    "proxy"
    "udp-custom"
    "badvpn"
    "badvpn-7100"
    "badvpn-7200"
    "badvpn-7300"
    "noobzvpns"
    "danted"
    "microsocks"
    "nginx"
    "sslh"
    "v2ray"
    "dropbear"
    "stunnel4"
    "dnstt"
    "client-sldns"
    "warp-svc"
)

echo -e "${blue}[1/8] Menghentikan dan menonaktifkan layanan...${NC}"
for svc in "${services[@]}"; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo -e "  - Menghentikan ${svc}..."
        systemctl stop "$svc" &>/dev/null
    fi
    if systemctl is-enabled --quiet "$svc" 2>/dev/null; then
        echo -e "  - Menonaktifkan ${svc}..."
        systemctl disable "$svc" &>/dev/null
    fi
done

# Kill any lingering processes
pkill -f vpn_telegram_bot.py &>/dev/null
pkill -f server &>/dev/null
pkill -f proxy &>/dev/null
pkill -f udp-custom &>/dev/null
pkill -f badvpn &>/dev/null
pkill -f noobzvpns &>/dev/null
pkill -f sslh &>/dev/null

# 2. Remove Systemd Service Files
echo -e "${blue}[2/8] Menghapus file systemd service...${NC}"
service_files=(
    "/etc/systemd/system/vpn-bot.service"
    "/etc/systemd/system/server.service"
    "/etc/systemd/system/proxy.service"
    "/etc/systemd/system/udp-custom.service"
    "/etc/systemd/system/noobzvpns.service"
    "/etc/systemd/system/badvpn.service"
    "/etc/systemd/system/badvpn-7100.service"
    "/etc/systemd/system/badvpn-7200.service"
    "/etc/systemd/system/badvpn-7300.service"
    "/etc/systemd/system/microsocks.service"
    "/etc/systemd/system/dnstt.service"
    "/etc/systemd/system/client-sldns.service"
)

for file in "${service_files[@]}"; do
    if [ -f "$file" ]; then
        rm -f "$file"
    fi
done
systemctl daemon-reload

# 3. Revert iptables Rules
echo -e "${blue}[3/8] Menghapus aturan iptables...${NC}"
primary_interface=$(ip route | grep default | awk '{print $5}')
if [ -n "$primary_interface" ]; then
    iptables -t nat -D PREROUTING -i $primary_interface -p tcp --dport 443 -j REDIRECT --to-port 2443 2>/dev/null
    iptables -t nat -D PREROUTING -i $primary_interface -p udp --dport 443 -j REDIRECT --to-port 36712 2>/dev/null
    iptables -t nat -D PREROUTING -i $primary_interface -p tcp --dport 80 -j REDIRECT --to-port 2080 2>/dev/null
    iptables -t nat -D PREROUTING -i $primary_interface -p udp --dport 80 -j REDIRECT --to-port 36712 2>/dev/null
    iptables -t nat -D PREROUTING -i $primary_interface -p udp --dport 53 -j REDIRECT --to-port 5300 2>/dev/null
fi
iptables -t nat -D PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 2443 2>/dev/null
iptables -t nat -D PREROUTING -p udp --dport 443 -j REDIRECT --to-port 36712 2>/dev/null
iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 2080 2>/dev/null
iptables -t nat -D PREROUTING -p udp --dport 80 -j REDIRECT --to-port 36712 2>/dev/null
iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-port 5300 2>/dev/null
iptables -D INPUT -p udp --dport 5300 -j ACCEPT 2>/dev/null
if [ -f "/etc/iptables/rules.v4" ]; then
    iptables-save > /etc/iptables/rules.v4
fi

# 4. Remove Symlinks and Commands in PATH
echo -e "${blue}[4/8] Menghapus shortcut menu dan script di /usr/bin/...${NC}"
if [ -d "/usr/local/sbin" ]; then
    for file in /usr/local/sbin/*; do
        if [ -f "$file" ]; then
            name=$(basename "$file")
            rm -f "/usr/bin/$name"
        fi
    done
fi

# 5. Clean profiles and Cron entries
echo -e "${blue}[5/8] Membersihkan profil pengguna dan crontab...${NC}"
# Remove menu from .profile
if [ -f "/root/.profile" ]; then
    sed -i '/menu/d' /root/.profile
fi

# Remove PATH modifications
if [ -f "/etc/profile" ]; then
    sed -i '/PATH.*usr\/local\/sbin/d' /etc/profile
fi
if [ -f "/root/.profile" ]; then
    sed -i '/PATH.*usr\/local\/sbin/d' /root/.profile
fi

# Remove cron jobs
if [ -f "/etc/crontab" ]; then
    sed -i '/access.log/d' /etc/crontab
    sed -i '/xp/d' /etc/crontab
    sed -i '/v2ray-watchdog/d' /etc/crontab
fi
systemctl restart cron 2>/dev/null

# 6. Revert SSHD configurations
echo -e "${blue}[6/8] Memulihkan konfigurasi SSH...${NC}"
if [ -f "/etc/ssh/sshd_config" ]; then
    # Clean custom ports and configs
    sed -i '/Port 3303/d' /etc/ssh/sshd_config
    sed -i '/Port 109/d' /etc/ssh/sshd_config
    sed -i '/UseDNS no/d' /etc/ssh/sshd_config
    sed -i '/GSSAPIAuthentication no/d' /etc/ssh/sshd_config
    sed -i '/Ciphers aes128-gcm/d' /etc/ssh/sshd_config
    sed -i '/MACs hmac-sha2/d' /etc/ssh/sshd_config
    sed -i '/Banner \/etc\/issue.net/d' /etc/ssh/sshd_config
    
    # Restore default SSH configurations
    systemctl restart ssh 2>/dev/null
    systemctl restart sshd 2>/dev/null
fi

# 7. Remove directories and binary files
echo -e "${blue}[7/8] Menghapus file dan folder konfigurasi...${NC}"
folders=(
    "/usr/local/sbin/api"
    "/etc/udp"
    "/usr/local/etc/v2ray"
    "/etc/noobzvpns"
    "/etc/api"
    "/root/.acme.sh"
    "/etc/stunnel"
)

for folder in "${folders[@]}"; do
    if [ -d "$folder" ]; then
        echo "  - Menghapus folder ${folder}..."
        rm -rf "$folder"
    fi
done

# Run Netdata uninstaller if present
if [ -f "/usr/libexec/netdata/netdata-uninstaller.sh" ]; then
    echo "  - Menjalankan Netdata uninstaller..."
    /usr/libexec/netdata/netdata-uninstaller.sh --yes --force &>/dev/null || true
elif [ -f "/etc/netdata/netdata-uninstaller.sh" ]; then
    echo "  - Menjalankan Netdata uninstaller..."
    /etc/netdata/netdata-uninstaller.sh --yes --force &>/dev/null || true
fi
rm -rf /etc/netdata /var/lib/netdata /var/log/netdata /usr/share/netdata /etc/nginx/.htpasswd

files=(
    "/usr/bin/server"
    "/usr/local/bin/proxy"
    "/usr/local/bin/badvpn"
    "/usr/bin/noobzvpns"
    "/usr/bin/vpn_telegram_bot.py"
    "/usr/local/sbin/add-ssh"
    "/usr/local/sbin/bot-menu"
    "/usr/local/sbin/menu"
    "/usr/local/sbin/menu-ssh"
    "/usr/local/sbin/vpn_telegram_bot.py"
    "/usr/local/sbin/xp"
    "/usr/local/sbin/v2ray-watchdog"
    "/usr/local/sbin/update"
    "/usr/bin/update"
    "/etc/issue.net"
    "/root/.ip"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "  - Menghapus file ${file}..."
        rm -f "$file"
    fi
done

# 8. Purge installed packages (Optional, keeps core packages to avoid breaking dependencies)
echo -e "${blue}[8/8] Menghapus paket yang terpasang...${NC}"
apt-get purge -y sslh dropbear dante-server microsocks stunnel4 squid netdata speedtest-cli cloudflare-warp &>/dev/null
apt-get autoremove -y &>/dev/null

echo -e "${yellow}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${green}         Autoscript berhasil di-uninstall dengan bersih!      ${NC}"
echo -e "${yellow}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
exit 0
