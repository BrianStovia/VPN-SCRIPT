#!/usr/bin/env bash


# Clear SUDO_USER to bypass acme.sh warnings under sudo
export SUDO_USER=""

# Define Colors
green="\e[1;32m"
NC="\e[0m"

# Define Hosting
hosting="https://raw.githubusercontent.com/BrianStovia/Sws-ro/main"

# Get directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to get file from local workspace
get_file() {
    local source_name="$1"
    local dest_path="$2"
    local cache_buster="?v=$(date +%s)"
    
    if [ -f "${SCRIPT_DIR}/${source_name}" ]; then
        echo "Using local file ${source_name}..."
        cp "${SCRIPT_DIR}/${source_name}" "${dest_path}"
    elif [ -f "${SCRIPT_DIR}/file/${source_name}" ]; then
        echo "Using repository file file/${source_name}..."
        cp "${SCRIPT_DIR}/file/${source_name}" "${dest_path}"
    else
        echo "Downloading ${source_name} from hosting..."
        wget -q -O "${dest_path}" "${hosting}/${source_name}${cache_buster}"
        if [ $? -ne 0 ]; then
            echo "Downloading ${source_name} from hosting/file..."
            wget -q -O "${dest_path}" "${hosting}/file/${source_name}${cache_buster}"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to download ${source_name} from hosting!"
                exit 1
            fi
        fi
    fi
}

if [ -f "/usr/local/etc/v2ray/domain" ]; then
echo "Script Already Installed"
exit 1
fi

if [ -f "/etc/xray/domain" ]; then
echo "Script Already Installed"
exit 1
fi

if [ -f "/etc/v2ray/domain" ]; then
echo "Script Already Installed"
exit 1
fi

if [ -f "/root/domain" ]; then
echo "Script Already Installed"
exit 1
fi

clear
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "$green          Input Domain              	$NC"
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
if [ -z "$domain" ]; then
    read -p " Input Your SubDomain : " domain
fi

clear

# Resolv
echo -e "nameserver 1.1.1.1" >> /etc/resolv.conf

# Memperbaiki Port Default Login SSH & Optimasi Speed SSH
cd /etc/ssh
find . -type f -name "*sshd_config*" -exec sed -i 's|#Port 22|Port 22|g' {} +
echo -e "Port 3303" >> sshd_config
echo -e "Port 109" >> sshd_config

# SSH Speed Optimization Configurations
sed -i '/^UseDNS/d' sshd_config 2>/dev/null
sed -i '/^GSSAPIAuthentication/d' sshd_config 2>/dev/null
sed -i '/^Ciphers/d' sshd_config 2>/dev/null
sed -i '/^MACs/d' sshd_config 2>/dev/null

echo -e "UseDNS no" >> sshd_config
echo -e "GSSAPIAuthentication no" >> sshd_config
cd
systemctl daemon-reload
systemctl restart ssh
systemctl restart sshd
# Create 2GB swap file if swap does not exist to prevent OOM crashes
if ! free | grep -i swap | awk '{print $2}' | grep -q '[1-9]'; then
    echo "Creating 2GB swap file..."
    dd if=/dev/zero of=/swapfile bs=1M count=2048 &>/dev/null
    chmod 600 /swapfile
    mkswap /swapfile &>/dev/null
    swapon /swapfile &>/dev/null
    echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
fi

# Optimize network card transmission queue length to prevent packet loss
primary_interface=$(ip route | grep default | awk '{print $5}')
if [ -n "$primary_interface" ]; then
    echo "Optimizing network card queue length for ${primary_interface}..."
    ip link set dev $primary_interface txqueuelen 10000 &>/dev/null
fi

# Network & TCP Speed Optimization (BBR)
sysctl_optimize() {
    local key="$1"
    local val="$2"
    sed -i "/^${key}/d" /etc/sysctl.conf 2>/dev/null
    echo "${key} = ${val}" >> /etc/sysctl.conf
}

echo "Optimizing network and TCP settings..."
sysctl_optimize "fs.file-max" "2097152"
sysctl_optimize "net.core.default_qdisc" "fq_codel"
sysctl_optimize "net.ipv4.tcp_congestion_control" "bbr"
sysctl_optimize "net.core.rmem_max" "67108864"
sysctl_optimize "net.core.wmem_max" "67108864"
sysctl_optimize "net.core.rmem_default" "33554432"
sysctl_optimize "net.core.wmem_default" "33554432"
sysctl_optimize "net.core.optmem_max" "2048576"
sysctl_optimize "net.ipv4.tcp_rmem" "4096 87380 67108864"
sysctl_optimize "net.ipv4.tcp_wmem" "4096 65536 67108864"
sysctl_optimize "net.ipv4.tcp_fastopen" "3"
sysctl_optimize "net.ipv4.tcp_fin_timeout" "15"
sysctl_optimize "net.ipv4.tcp_keepalive_time" "300"
sysctl_optimize "net.ipv4.tcp_keepalive_probes" "5"
sysctl_optimize "net.ipv4.tcp_keepalive_intvl" "15"
sysctl_optimize "net.ipv4.tcp_max_syn_backlog" "8192"
sysctl_optimize "net.ipv4.tcp_max_tw_buckets" "1440000"
sysctl_optimize "net.ipv4.tcp_tw_reuse" "1"
sysctl_optimize "net.core.netdev_max_backlog" "10000"
sysctl_optimize "net.ipv4.udp_rmem_min" "16384"
sysctl_optimize "net.ipv4.udp_wmem_min" "16384"
sysctl -p
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
sysctl --system

# System Limits Optimization
if ! grep -q "* soft nofile" /etc/security/limits.conf; then
cat >> /etc/security/limits.conf <<EOF
* soft nofile 1000000
* hard nofile 1000000
root soft nofile 1000000
root hard nofile 1000000
EOF
fi

# Non Interactive
export DEBIAN_FRONTEND=noninteractive
apt update

# Pakcage
apt install curl wget gnupg openssl -y
apt install jq -y
apt install perl -y
apt install sudo -y
apt install screen -y
apt install socat -y
apt install util-linux -y
apt install lsb-release -y
apt install bsdextrautils -y 2>/dev/null || apt install bsdmainutils -y
apt install iptables -y
apt install iptables-persistent -y
apt install binutils -y
apt install python3 python3-pip -y
apt install zip -y
apt install unzip -y
apt install bc -y
apt install speedtest-cli -y

# Ensure standard systemd system users exist and have correct permissions to prevent 217/USER boot failures
systemd-sysusers 2>/dev/null || true
for sys_user in systemd-network systemd-resolve systemd-timesync; do
    if ! getent passwd "$sys_user" >/dev/null; then
        echo "Creating missing systemd user: $sys_user"
        groupadd -r "$sys_user" 2>/dev/null || true
        useradd -r -g "$sys_user" -d /run/systemd -s /usr/sbin/nologin "$sys_user" 2>/dev/null || true
    fi
done
chmod 644 /etc/passwd /etc/group 2>/dev/null || true
systemctl enable systemd-networkd 2>/dev/null || true
systemctl start systemd-networkd 2>/dev/null || true

# Setup Banner SSH
sed -i '/^#\?Banner /c\Banner /etc/issue.net' /etc/ssh/sshd_config
rm -f /etc/issue.net
get_file "issue.net" "/etc/issue.net"
chmod +x /etc/issue.net
systemctl daemon-reload
systemctl restart ssh
systemctl restart sshd

# Disable rpcbind and rpcbind.socket to prevent port 111 conflict with dropbear
systemctl stop rpcbind rpcbind.socket 2>/dev/null || true
systemctl disable rpcbind rpcbind.socket 2>/dev/null || true

# Installasi Dropbear
apt install dropbear -y
rm /etc/default/dropbear
clear
# RSA
rm -f /etc/dropbear/dropbear_rsa_host_key
dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key

# DSS (DSA)
rm -f /etc/dropbear/dropbear_dss_host_key
dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key

# ECDSA
rm -f /etc/dropbear/dropbear_ecdsa_host_key
dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key
cat>  /etc/default/dropbear << END

NO_START=0
# the TCP port that Dropbear listens on
DROPBEAR_PORT=111

# any additional arguments for Dropbear
#DROPBEAR_EXTRA_ARGS="-p 109 -p 69 "

# specify an optional banner file containing a message to be
# sent to clients before they connect, such as "/etc/issue.net"
DROPBEAR_BANNER="/etc/issue.net"

# RSA hostkey file (default: /etc/dropbear/dropbear_rsa_host_key)
DROPBEAR_RSAKEY="/etc/dropbear/dropbear_rsa_host_key"

# DSS hostkey file (default: /etc/dropbear/dropbear_dss_host_key)
#DROPBEAR_DSSKEY="/etc/dropbear/dropbear_dss_host_key"

# ECDSA hostkey file (default: /etc/dropbear/dropbear_ecdsa_host_key)
DROPBEAR_ECDSAKEY="/etc/dropbear/dropbear_ecdsa_host_key"

# Receive window size - this is a tradeoff between memory and
# network performance
DROPBEAR_RECEIVE_WINDOW=65536
END
echo "/bin/false" >> /etc/shells
echo "/usr/sbin/nologin" >> /etc/shells
systemctl daemon-reload
systemctl enable dropbear
systemctl restart dropbear
clear

# Save Data IP
curl -s http://checkip.amazonaws.com > /root/.ip

# Special SSLH
echo 'sslh   sslh/inetd_or_standalone select standalone' | sudo debconf-set-selections
apt update -y
apt install sslh -y

# Configure systemd-tmpfiles to recreate /run/sslh on boot (prevents service crash after reboot)
mkdir -p /run/sslh
chown sslh:sslh /run/sslh
echo "d /run/sslh 0755 sslh sslh -" > /etc/tmpfiles.d/sslh.conf

# Main Menu
mkdir -p /usr/local/sbin
cd /usr/local/sbin
get_file "main.zip" "m.zip"
unzip -o m.zip
chmod +x *
rm -f m.zip

# Symlink all custom sbin scripts to /usr/bin to ensure they are always in PATH
for file in /usr/local/sbin/*; do
    if [ -f "$file" ]; then
        ln -sf "$file" "/usr/bin/$(basename "$file")"
    fi
done

# Ensure /usr/local/sbin is in PATH for all profiles
if ! grep -q "PATH.*usr/local/sbin" /etc/profile 2>/dev/null; then
    echo 'export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"' >> /etc/profile
fi
if [ -f "/root/.profile" ] && ! grep -q "PATH.*usr/local/sbin" /root/.profile 2>/dev/null; then
    echo 'export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"' >> /root/.profile
fi

# Stoping HTTP
systemctl stop apache2
systemctl disable apache2

# Setup SSLH
cd /etc/default
rm -f sslh
get_file "sslh" "sslh"
chmod 755 sslh
cd

# Setup Rest Api
mkdir -p /usr/local/sbin/api
cd /usr/local/sbin/api
chmod +x *
cd
get_file "server" "/usr/bin/server"
chmod +x /usr/bin/server
cat> /etc/systemd/system/server.service << END
[Unit]
Description=WebAPI Server Proxy All OS By rbstv
After=syslog.target network-online.target

[Service]
User=root
NoNewPrivileges=true
ExecStart=/usr/bin/server
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
END
mkdir -p /etc/api

# Setup Proxy SSHWS
cd /usr/local/bin
get_file "proxy" "proxy"
chmod +x proxy
cd
echo -e "[Unit]
Description=WebSocket
After=syslog.target network-online.target

[Service]
User=root
NoNewPrivileges=true
ExecStart=/usr/bin/python3 -u /usr/local/bin/proxy
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/proxy.service

# Setup Socks5 Proxy
if apt install dante-server -y 2>/dev/null; then
    sudo touch /var/log/danted.log
    sudo chown root:root /var/log/danted.log
    primary_interface=$(ip route | grep default | awk '{print $5}')
    sudo bash -c "cat <<EOF > /etc/danted.conf
logoutput: /var/log/danted.log
internal: 0.0.0.0 port = 1080
external: $primary_interface
method: username
user.privileged: root
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}
EOF"
    if [ -f "/usr/lib/systemd/system/danted.service" ]; then
        sudo sed -i '/\[Service\]/a ReadWriteDirectories=/var/log' /usr/lib/systemd/system/danted.service
    elif [ -f "/lib/systemd/system/danted.service" ]; then
        sudo sed -i '/\[Service\]/a ReadWriteDirectories=/var/log' /lib/systemd/system/danted.service
    fi
    sudo systemctl daemon-reload
    sudo systemctl restart danted
    sudo systemctl enable danted
else
    echo "dante-server not available. Installing microsocks SOCKS5 proxy instead..."
    if apt install microsocks -y 2>/dev/null; then
        cat <<EOF > /etc/systemd/system/microsocks.service
[Unit]
Description=MicroSocks SOCKS5 Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/microsocks -p 1080
Restart=always

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable microsocks
        systemctl start microsocks
        # Maintain backward compatibility by symlinking danted.service to microsocks.service
        ln -sf /etc/systemd/system/microsocks.service /etc/systemd/system/danted.service
        systemctl daemon-reload
    else
        echo "Warning: Both dante-server and microsocks SOCKS5 proxies failed to install."
    fi
fi

# Setup Nginx
apt install nginx -y
rm -f /etc/nginx/nginx.conf
get_file "nginx.conf" "/etc/nginx/nginx.conf"
sed -i "s|server_name .*;|server_name $domain;|" /etc/nginx/nginx.conf
systemctl stop nginx
systemctl disable nginx

# Setup Badvpn
wget -O /usr/local/bin/badvpn "https://raw.githubusercontent.com/powermx/badvpn/master/badvpn-udpgw" &>/dev/null
chmod +x /usr/local/bin/badvpn

# Create systemd service for Port 7100
echo -e "[Unit]
Description=BadVPN Gaming Support Port 7100 By rbstv
After=syslog.target network-online.target

[Service]
User=root
NoNewPrivileges=true
Nice=-20
ExecStart=/usr/local/bin/badvpn --listen-addr 127.0.0.1:7100 --max-clients 1000 --max-connections-for-client 1000 --client-socket-sndbuf 0 --udp-mtu 1380
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/badvpn-7100.service

# Create systemd service for Port 7200
echo -e "[Unit]
Description=BadVPN Gaming Support Port 7200 By rbstv
After=syslog.target network-online.target

[Service]
User=root
NoNewPrivileges=true
Nice=-20
ExecStart=/usr/local/bin/badvpn --listen-addr 127.0.0.1:7200 --max-clients 1000 --max-connections-for-client 1000 --client-socket-sndbuf 0 --udp-mtu 1380
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/badvpn-7200.service

# Create systemd service for Port 7300
echo -e "[Unit]
Description=BadVPN Gaming Support Port 7300 By rbstv
After=syslog.target network-online.target

[Service]
User=root
NoNewPrivileges=true
Nice=-20
ExecStart=/usr/local/bin/badvpn --listen-addr 127.0.0.1:7300 --max-clients 1000 --max-connections-for-client 1000 --client-socket-sndbuf 0 --udp-mtu 1380
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/badvpn-7300.service

# Maintain backward compatibility for badvpn.service
cp /etc/systemd/system/badvpn-7300.service /etc/systemd/system/badvpn.service

systemctl daemon-reload
systemctl enable badvpn-7100 badvpn-7200 badvpn-7300 badvpn
systemctl start badvpn-7100 badvpn-7200 badvpn-7300 badvpn
systemctl restart badvpn-7100 badvpn-7200 badvpn-7300 badvpn

# Setup Squid Proxy
echo "Installing and configuring Squid Proxy..."
apt install squid -y
cat > /etc/squid/squid.conf << EOF
http_port 8080
http_port 3128
acl SSH_ports port 22 90 109 111 3303
http_access allow SSH_ports
http_access deny all
EOF
systemctl daemon-reload
systemctl enable squid
systemctl restart squid

# Setup UDP Custom
rm -rf /etc/udp
mkdir -p /etc/udp
echo downloading udp-custom
get_file "udp-custom-linux-amd64" "/etc/udp/udp-custom"
chmod +x /etc/udp/udp-custom
echo downloading default config
get_file "udp.json" "/etc/udp/config.json"
chmod 644 /etc/udp/config.json
cat <<EOF > /etc/systemd/system/udp-custom.service
[Unit]
Description=UDP Custom by ePro Dev. Team and modify by FN Project

[Service]
User=root
Type=simple
Nice=-20
ExecStart=/etc/udp/udp-custom server --config /etc/udp/config.json --exclude 7300,51820
WorkingDirectory=/etc/udp/
Restart=always
RestartSec=2s

[Install]
WantedBy=default.target
EOF
echo start service udp-custom
systemctl start udp-custom &>/dev/null
echo enable service udp-custom
systemctl enable udp-custom &>/dev/null

# Cron
apt install cron -y
echo -e "
*/15 * * * * root echo -n > /var/log/v2ray/access.log
*/15 * * * * root xp
* * * * * root /usr/local/sbin/v2ray-watchdog
" >> /etc/crontab

# Setup default Auto-Reboot Cron (04:00 AM daily)
echo "0 4 * * * root /sbin/reboot" > /etc/cron.d/auto-reboot
systemctl restart cron &>/dev/null

# Setup V2Ray/Nginx Watchdog
cat > /usr/local/sbin/v2ray-watchdog << 'EOF'
#!/usr/bin/env bash
if ! systemctl is-active --quiet v2ray; then
    echo "$(date): v2ray is inactive, restarting..." >> /var/log/v2ray/watchdog.log
    systemctl restart v2ray
fi
if ! systemctl is-active --quiet nginx; then
    echo "$(date): nginx is inactive, restarting..." >> /var/log/v2ray/watchdog.log
    systemctl restart nginx
fi
EOF
chmod +x /usr/local/sbin/v2ray-watchdog

systemctl daemon-reload
systemctl restart cron

# ===== Setup V2ray ======
# Check if the group 'nobody' exists
if getent group nobody > /dev/null; then
    echo "Group 'nobody' already exists."
else
    echo "Group 'nobody' does not exist. Creating..."
    groupadd nobody
fi

# Check if the user 'nobody' exists
if getent passwd nobody > /dev/null; then
    echo "User 'nobody' already exists."
else
    echo "User 'nobody' does not exist. Creating..."
    useradd -g nobody -M -s /sbin/nologin nobody
fi

# Ensure V2Ray configuration directory exists
mkdir -p /usr/local/etc/v2ray
# Ensure V2Ray log directory exists
mkdir -p /var/log/v2ray
chown -R nobody /var/log/v2ray

# Install Xray with retries
echo "Installing Xray..."
for i in {1..3}; do
    if bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh); then
        echo "Xray installed successfully!"
        systemctl stop xray.service 2>/dev/null || true
        systemctl disable xray.service 2>/dev/null || true
        systemctl stop xray@.service 2>/dev/null || true
        systemctl disable xray@.service 2>/dev/null || true
        break
    else
        echo "Xray installation failed, retrying ($i/3)..."
        sleep 3
    fi
done

# Maintain backward compatibility for v2ray binary execution path
ln -sf /usr/local/bin/xray /usr/local/bin/v2ray

# Create v2ray.service wrapping xray-core for backward compatibility
cat > /etc/systemd/system/v2ray.service << END
[Unit]
Description=V2Ray Service (Xray-core drop-in wrapper)
Documentation=https://github.com/XTLS/Xray-core
After=network.target nss-lookup.target

[Service]
User=nobody
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/v2ray run -config /usr/local/etc/v2ray/config.json
Restart=always
RestartSec=3s
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
END
systemctl daemon-reload


# Backup and merge existing config if it exists
if [ -f "/usr/local/etc/v2ray/config.json" ]; then
    cp /usr/local/etc/v2ray/config.json /usr/local/etc/v2ray/config.json.bak
    get_file "config.json" "/usr/local/etc/v2ray/config.json"
    
    # Download merge_config.py and run it to restore accounts
    get_file "merge_config.py" "/usr/local/sbin/merge_config.py"
    chmod +x /usr/local/sbin/merge_config.py
    python3 /usr/local/sbin/merge_config.py
else
    get_file "config.json" "/usr/local/etc/v2ray/config.json"
fi



# Setup NoobzVPNS
clear
mkdir -p /etc/noobzvpns
cd /etc/noobzvpns
rm -fr *
get_file "config.toml" "config.toml"
wget -q -O /usr/bin/noobzvpns "https://github.com/noobz-id/noobzvpns/raw/master/noobzvpns.x86-64"
chmod +x /usr/bin/noobzvpns
echo -e "[Unit]
Description=NoobzVpn-Server
Wants=network-online.target
After=network.target network-online.target

[Service]
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
User=root
Type=simple
TimeoutStopSec=1
LimitNOFILE=infinity
ExecStart=/usr/bin/noobzvpns start-server

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/noobzvpns.service
chmod +x /etc/noobzvpns/*
cd

# Certificate
iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 2080 2>/dev/null || true
echo -e "${domain}" > /usr/local/etc/v2ray/domain
    rm -rf /root/.acme.sh
    mkdir -p /root/.acme.sh
    curl -sSL https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh -o /root/.acme.sh/acme.sh
    chmod +x /root/.acme.sh/acme.sh
    /root/.acme.sh/acme.sh --upgrade --auto-upgrade || true
    # SSL Certificate Generation with Fallback (LetsEncrypt -> ZeroSSL -> BuyPass)
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    if ! /root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256; then
        echo "Let's Encrypt rate-limited or failed. Trying ZeroSSL..."
        /root/.acme.sh/acme.sh --register-account -m admin@${domain} --server zerossl
        /root/.acme.sh/acme.sh --set-default-ca --server zerossl
        if ! /root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256; then
            echo "ZeroSSL failed. Trying BuyPass..."
            /root/.acme.sh/acme.sh --set-default-ca --server buypass
            /root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
        fi
    fi
    /root/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /usr/local/etc/v2ray/v2ray.crt --keypath /usr/local/etc/v2ray/v2ray.key --ecc

    # Fallback to self-signed certificate if acme.sh failed to create the certificate
    if [ ! -f "/usr/local/etc/v2ray/v2ray.crt" ] || [ ! -f "/usr/local/etc/v2ray/v2ray.key" ]; then
        echo "SSL certificate not found. Generating self-signed certificate as fallback..."
        mkdir -p /usr/local/etc/v2ray
        openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
            -subj "/C=ID/ST=Jakarta/L=Jakarta/O=FNProject/CN=${domain}" \
            -keyout /usr/local/etc/v2ray/v2ray.key \
            -out /usr/local/etc/v2ray/v2ray.crt 2>/dev/null
    fi

cd /root

# Service NoobzVPN
systemctl daemon-reload
systemctl enable noobzvpns
systemctl start noobzvpns

# Enable & Start Service
systemctl daemon-reload
pkill sslh
systemctl enable v2ray
systemctl enable nginx
systemctl enable sslh
systemctl restart v2ray
systemctl restart nginx
systemctl restart sslh
systemctl enable proxy
systemctl start proxy
systemctl restart proxy

# Setup Stunnel4
echo "Installing and configuring Stunnel4..."
apt install stunnel4 -y
mkdir -p /etc/stunnel
cat > /etc/stunnel/stunnel.conf << END
pid = /var/run/stunnel4.pid
cert = /usr/local/etc/v2ray/v2ray.crt
key = /usr/local/etc/v2ray/v2ray.key

[dropbear_222]
accept = 0.0.0.0:222
connect = 127.0.0.1:111

[dropbear_777]
accept = 0.0.0.0:777
connect = 127.0.0.1:111

[openssh_990]
accept = 0.0.0.0:990
connect = 127.0.0.1:22
END
sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
systemctl daemon-reload
systemctl enable stunnel4
systemctl restart stunnel4

# Setup Fail2Ban
echo "Installing and configuring Fail2Ban..."
apt install fail2ban -y
cat > /etc/fail2ban/jail.local << END
[DEFAULT]
bantime = 10m
findtime = 10m
maxretry = 5
backend = systemd
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = 22,109,3303,990

[dropbear]
enabled = true
port = 111,222,777
END
systemctl daemon-reload
systemctl enable fail2ban
systemctl restart fail2ban

# Setup SSH Limit Daemon
echo "Installing and configuring SSH Limit Daemon..."
get_file "ssh-limit" "/usr/local/sbin/ssh-limit"
chmod +x /usr/local/sbin/ssh-limit
ln -sf /usr/local/sbin/ssh-limit /usr/bin/ssh-limit

# Setup Update Script
get_file "update.sh" "/usr/local/sbin/update"
chmod +x /usr/local/sbin/update
ln -sf /usr/local/sbin/update /usr/bin/update


# Systemd Service and Timer for ssh-limit
cat > /etc/systemd/system/ssh-limit.service << END
[Unit]
Description=SSH and VPN IP Limit Enforcer By rbstv
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/ssh-limit
END

cat > /etc/systemd/system/ssh-limit.timer << END
[Unit]
Description=Run SSH Limit Enforcer Every Minute

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
AccuracySec=1s

[Install]
WantedBy=timers.target
END

systemctl daemon-reload
systemctl enable ssh-limit.timer
systemctl start ssh-limit.timer

# Setup SlowDNS
echo "Installing and configuring SlowDNS..."
mkdir -p /etc/slowdns
echo "ns.${domain}" > /etc/slowdns/nameserver

# Download prebuilt dnstt dns-server
wget -q -O /usr/sbin/dns-server "https://github.com/powermx/dnstt/raw/refs/heads/main/dns-server"
chmod +x /usr/sbin/dns-server

# Generate key pair
/usr/sbin/dns-server -gen-key -privkey-file /etc/slowdns/server.key -pubkey-file /etc/slowdns/server.pub

# Create Systemd Service for client-sldns (SlowDNS)
cat > /etc/systemd/system/client-sldns.service << EOF
[Unit]
Description=SlowDNS rbstv Autoscript Service
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE CAP_NET_ADMIN
NoNewPrivileges=true
ExecStart=/usr/sbin/dns-server -udp :5300 -privkey-file /etc/slowdns/server.key ns.${domain} 127.0.0.1:111
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Create compatibility symlink for dnstt.service
ln -sf /etc/systemd/system/client-sldns.service /etc/systemd/system/dnstt.service

systemctl daemon-reload
systemctl enable client-sldns
systemctl enable dnstt
systemctl restart client-sldns
systemctl restart dnstt



# Get main network interface
primary_interface=$(ip route | grep default | awk '{print $5}')

# ===== IP Tables Main Port

if [ -n "$primary_interface" ]; then
    # Redirect TCP 443 ke TCP 2443
    iptables -t nat -A PREROUTING -i $primary_interface -p tcp --dport 443 -j REDIRECT --to-port 2443

    # Redirect UDP 443 ke UDP 36712
    iptables -t nat -A PREROUTING -i $primary_interface -p udp --dport 443 -j REDIRECT --to-port 36712

    # Redirect TCP 80 ke TCP 700 (Python Proxy) untuk bypass Nginx
    iptables -t nat -A PREROUTING -i $primary_interface -p tcp --dport 80 -j REDIRECT --to-port 700

    # Redirect UDP 80 ke UDP 36712
    iptables -t nat -A PREROUTING -i $primary_interface -p udp --dport 80 -j REDIRECT --to-port 36712

    # Redirect UDP 53 ke UDP 5300 untuk SlowDNS
    iptables -t nat -A PREROUTING -i $primary_interface -p udp --dport 53 -j REDIRECT --to-port 5300
else
    # Redirect TCP 443 ke TCP 2443
    iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 2443

    # Redirect UDP 443 ke UDP 36712
    iptables -t nat -A PREROUTING -p udp --dport 443 -j REDIRECT --to-port 36712

    # Redirect TCP 80 ke TCP 700 (Python Proxy) untuk bypass Nginx
    iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 700

    # Redirect UDP 80 ke UDP 36712
    iptables -t nat -A PREROUTING -p udp --dport 80 -j REDIRECT --to-port 36712

    # Redirect UDP 53 ke UDP 5300 untuk SlowDNS
    iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-port 5300
fi



# Open UDP port 5300 for SlowDNS
iptables -A INPUT -p udp --dport 5300 -j ACCEPT

iptables-save > /etc/iptables/rules.v4

# Setup WireGuard VPN
echo "Installing and configuring WireGuard..."
apt install wireguard wireguard-tools qrencode -y
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

# Enable IPv4 routing/forwarding
sysctl_optimize "net.ipv4.ip_forward" "1"
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/99-vpn.conf
sysctl --system

# Generate Server Keys if they don't exist
if [ ! -f "/etc/wireguard/private.key" ]; then
    wg genkey | tee /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key
    chmod 600 /etc/wireguard/private.key /etc/wireguard/public.key
fi

server_priv=$(cat /etc/wireguard/private.key)

# Create Server Configuration
cat > /etc/wireguard/wg0.conf << END
[Interface]
Address = 10.22.0.1/24
SaveConfig = true
PrivateKey = ${server_priv}
ListenPort = 51820
PostUp = sysctl -w net.ipv4.ip_forward=1; iptables -A FORWARD -i wg0 -o ${primary_interface} -j ACCEPT; iptables -A FORWARD -i ${primary_interface} -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT; iptables -t nat -A POSTROUTING -o ${primary_interface} -j MASQUERADE; iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
PostDown = iptables -D FORWARD -i wg0 -o ${primary_interface} -j ACCEPT; iptables -D FORWARD -i ${primary_interface} -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT; iptables -t nat -D POSTROUTING -o ${primary_interface} -j MASQUERADE; iptables -t mangle -D FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
MTU = 1420
END

systemctl daemon-reload
systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0

# Setup Netdata Web Dashboard
echo "Installing Netdata Web Dashboard Monitoring..."
if ! command -v netdata &> /dev/null; then
    wget -O /tmp/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh && sh /tmp/netdata-kickstart.sh --non-interactive --disable-telemetry || true
fi

# Configure Netdata to bind only to 127.0.0.1
if [ -f "/etc/netdata/netdata.conf" ]; then
    if grep -q "\[web\]" /etc/netdata/netdata.conf; then
        sed -i '/\[web\]/a \    bind to = 127.0.0.1' /etc/netdata/netdata.conf
    else
        echo -e "\n[web]\n    bind to = 127.0.0.1" >> /etc/netdata/netdata.conf
    fi
    systemctl restart netdata || true
fi

# Setup Netdata Password Basic Authentication
netdata_pass="admin$(echo "$domain" | tr -d '.')"
pass_hash=$(openssl passwd -1 "$netdata_pass")
echo "admin:$pass_hash" > /etc/nginx/.htpasswd
systemctl restart nginx || true

clear
# rm -f /root/* # Disabled to protect local files and workspace from accidental deletion

echo -e "menu" >> /root/.profile
pub_key=$(cat /etc/slowdns/server.pub 2>/dev/null)
clear
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "          Success Install          "
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e " SlowDNS Nameserver : ns.${domain}"
echo -e " SlowDNS Public Key : ${pub_key}"
echo -e " Web Dashboard      : https://${domain}/netdata/"
echo -e " Dashboard User     : admin"
echo -e " Dashboard Pass     : ${netdata_pass}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
exit 0
