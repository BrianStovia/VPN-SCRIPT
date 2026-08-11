<h1 align="center">⚡ Sws-ro Premium Autoscript VPS ⚡</h1>

<p align="center">
  <b>Autoscript VPS Multi-Protocol & High Performance Network Tuning for Gaming & Tunneling</b><br>
  Developed by <b>Brian Stovia</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-18.04--24.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Ubuntu">
  <img src="https://img.shields.io/badge/Debian-10--12-A81D33?style=for-the-badge&logo=debian&logoColor=white" alt="Debian">
  <img src="https://img.shields.io/badge/Kernel-BBR%20%2B%20fq__codel-blue?style=for-the-badge" alt="Kernel Tuning">
  <img src="https://img.shields.io/badge/Telegram_Bot-Interactive_Panel-0088cc?style=for-the-badge&logo=telegram&logoColor=white" alt="Telegram Bot">
</p>

---

## 🚀 Fitur Unggulan

### 🎮 **Optimasi Low Latency & Anti-Lag Gaming**
* **BadVPN UDPGateway**: Port `7100`, `7200`, `7300` diset khusus dengan **MTU 1380** (mencegah fragmentasi paket & lag spike saat main game online).
* **UDP Custom Protocol**: Port `36712` & `1-65535` untuk koneksi game murni tanpa hambatan.
* **Kernel Network Tuning**: `net.core.default_qdisc = fq_codel` + `TCP BBR` serta buffer minimum UDP 16KB untuk menekan *bufferbloat*.

### 🌐 **Multi-Protokol Tunneling**
* **SSH & OpenVPN**: OpenSSH (`22`, `109`, `3303`), Dropbear (`69`, `143`), Stunnel4, Websocket HTTP (`80`, `2080`, `2082`), Websocket TLS (`443`).
* **Xray / V2Ray Core**: VMess, VLess, Trojan, dan Shadowsocks dengan TLS & NGINX multiplexing.
* **WireGuard VPN**: Port `51820` (Ultra-fast native UDP VPN).
* **SlowDNS / DNSTT**: Port `53` & `5300` (Solusi bypass kuota zero-balance).
* **Cloudflare WARP Outbound**: Bypass Geo-restriction, ChatGPT, Netflix, & Google CAPTCHA.

### 🤖 **Telegram Seller Bot Panel Interactive**
* **Manajemen Akun via Bot**: Buat, hapus, perpanjang, dan cek daftar akun (SSH, VMess, VLess, Trojan, WireGuard).
* **Custom Max Login IP**: Admin / Seller bebas memasukkan limit IP / Device saat membuat akun SSH.
* **Auto Reboot Control (`/reboot`)**: Atur jadwal restart VPS (1 Jam, 6 Jam, 12 Jam, 24 Jam 04:00 Subuh, 1 Minggu, atau Off) dari Telegram chat.
* **RAM Cache Cleaner (`/clear_ram`)**: Membersihkan cache memori RAM VPS secara instan via chat.
* **Bot Latency Check (`/ping`)**: Cek kecepatan respon bot & status BBR / `fq_codel`.
* **Auto Backup ke Telegram**: File `.zip` cadangan database dikirimkan langsung ke Telegram Admin via `sendDocument` API.
* **Pemberitahuan Akun Expired (`xp`)**: Notifikasi otomatis saat akun kadaluwarsa dibersihkan dari sistem.

### 🛠️ **Manajemen & Keamanan System**
* **Systemd Networkd Autostart**: Penanganan otomatis pengguna sistem & `systemd-networkd` agar interface jaringan (`ens3`) selalu `UP` setelah reboot.
* **SSH Multi-Login Limiter**: Pemantauan & auto-kill sesi login berlebih (`ssh-limit`).
* **Netdata Dashboard**: Monitoring statistik resource server via browser (`https://domain/netdata/`).
* **Fail2ban**: Proteksi otomatis dari serangan brute-force.

---

## 📋 Daftar Port Layanan

| Layanan | Port |
| :--- | :--- |
| **SSH WS TLS / V2Ray TLS** | `443` |
| **SSH WS HTTP** | `80`, `2080`, `2082` |
| **OpenSSH** | `22`, `109`, `3303` |
| **Dropbear** | `69`, `143` |
| **SSL/TLS (Stunnel4)** | `222`, `777`, `990` |
| **UDP Custom** | `1-65535` & `36712` |
| **BadVPN UDPGateway** | `7100`, `7200`, `7300` |
| **WireGuard VPN** | `51820` |
| **SlowDNS / DNSTT** | `53`, `5300` |
| **Netdata Web Dashboard** | `https://domain/netdata/` |

---

## 💻 Sistem Operasi yang Didukung

* **Ubuntu**: 18.04 LTS, 20.04 LTS, 22.04 LTS, 24.04 LTS (64-bit)
* **Debian**: 10, 11, 12 (64-bit)

---

## 📥 Cara Instalasi (One-Line Installer)

Masuk ke terminal VPS Anda sebagai `root`, lalu jalankan perintah berikut:

```bash
apt update && apt install -y curl wget && sysctl -w net.ipv4.ip_forward=1 && wget -q -O install.sh https://raw.githubusercontent.com/BrianStovia/Sws-ro/main/install.sh && chmod +x install.sh && ./install.sh
```

---

## 🔄 Cara Memperbarui Autoscript (Update)

Untuk memperbarui script & menerapkan patch optimasi terbaru di VPS Anda, cukup ketik:

```bash
update
```
*(atau jalankan perintah one-line di bawah ini):*

```bash
wget -q -O update.sh https://raw.githubusercontent.com/BrianStovia/Sws-ro/main/update.sh && chmod +x update.sh && ./update.sh
```

---

## 🗑️ Cara Uninstall Autoscript

Jika ingin menghapus seluruh instalasi autoscript dari VPS:

```bash
uninstall
```

---

## 👤 Developer & Credit

* **Developer**: [Brian Stovia](https://github.com/BrianStovia)
* **Repository**: [BrianStovia/Sws-ro](https://github.com/BrianStovia/Sws-ro)
* **License**: MIT
