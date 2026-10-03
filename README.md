<h1 align="center">⚡ Sws-go Premium Autoscript VPS ⚡</h1>

<p align="center">
  <b>Autoscript VPS Multi-Protocol &amp; High Performance Network Tuning for Gaming &amp; Tunneling</b><br>
  Developed by <b>Brian Stovia</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-18.04--24.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Ubuntu">
  <img src="https://img.shields.io/badge/Debian-10--12-A81D33?style=for-the-badge&logo=debian&logoColor=white" alt="Debian">
  <img src="https://img.shields.io/badge/Go-1.22+-00ADD8?style=for-the-badge&logo=go&logoColor=white" alt="Go">
  <img src="https://img.shields.io/badge/Kernel-BBR%20%2B%20fq__codel-blue?style=for-the-badge" alt="Kernel Tuning">
  <img src="https://img.shields.io/badge/Telegram_Bot-Interactive_Panel-0088cc?style=for-the-badge&logo=telegram&logoColor=white" alt="Telegram Bot">
</p>

---

## 🆕 Apa yang Baru — Go Edition

Versi ini telah **sepenuhnya dimigrasi ke Go** untuk performa lebih tinggi dan stabilitas lebih baik:

| Komponen | Sebelumnya | Sekarang |
| :--- | :--- | :--- |
| **API Server** | Python 3 (`server`) | Go binary (`bin/server`) |
| **WebSocket Proxy** | Python 3 (`proxy`) | Go binary (`bin/proxy`) |
| **SSH Limiter** | Python 3 (`ssh-limit`) | Go binary (`bin/ssh-limit`) |
| **Runtime** | Python 3 wajib terinstall | ❌ Tidak perlu Python |
| **Network Stability** | Manual | Auto watchdog + networkd config |

### ✅ Keuntungan Go Binary
* **Tidak perlu Python runtime** — binary langsung jalan tanpa dependensi interpreter
* **Performa lebih tinggi** — goroutines vs Python threads, latensi lebih rendah
* **Binary tunggal** — deploy semudah copy file
* **Startup lebih cepat** — tidak ada overhead interpreter

---

## 🚀 Fitur Unggulan

### 🎮 **Optimasi Low Latency & Anti-Lag Gaming**
* **BadVPN UDPGateway**: Port `7100`, `7200`, `7300` diset khusus dengan **MTU 1380** (mencegah fragmentasi paket & lag spike saat main game online).
* **UDP Custom Protocol**: Port `36712` & `1-65535` untuk koneksi game murni tanpa hambatan.
* **Kernel Network Tuning**: `net.core.default_qdisc = fq_codel` + `TCP BBR` serta buffer minimum UDP 16KB untuk menekan *bufferbloat*.

### 🌐 **Multi-Protokol Tunneling**
* **SSH & OpenVPN**: OpenSSH (`22`, `109`, `3303`), Dropbear (`111`, `69`, `143`), Stunnel4, Websocket HTTP (`80`, `2080`, `2082`), Websocket TLS (`443`).
* **Xray / V2Ray Core**: VMess, VLess, Trojan, dan Shadowsocks dengan TLS & NGINX multiplexing.
* **WireGuard VPN**: Port `51820` (Ultra-fast native UDP VPN).
* **SlowDNS / DNSTT**: Port `53` & `5300` (Solusi bypass kuota zero-balance).
* **Cloudflare WARP Outbound**: Bypass Geo-restriction, ChatGPT, Netflix, & Google CAPTCHA.

### ⚙️ **Go-Powered Core Services**
* **API Server** (`bin/server`): HTTP API server port `9000` dengan Bearer token auth, eksekusi script shell via REST API.
* **WebSocket Proxy** (`bin/proxy`): Proxy multi-protokol — HTTP CONNECT, WebSocket upgrade (dinamis `Sec-WebSocket-Accept`), SOCKS5, dan routing V2Ray path. Listen di port `700` (plain) + `701` (TLS).
* **SSH Limiter** (`bin/ssh-limit`): Monitor sesi SSH aktif (OpenSSH & Dropbear), resolusi IP real melalui WebSocket/Stunnel mapping, enforce limit per-user dari GECOS `/etc/passwd`.

### 🛡️ **Stabilitas Network Interface**
* **systemd-networkd config**: File `.network` otomatis dibuat untuk interface utama (`ens*`) dengan `KeepConfiguration=dhcp-on-stop` — interface **tidak drop** saat layanan restart.
* **ActivationPolicy=always-up**: Interface dipaksa tetap aktif setiap saat.
* **udev rule persisten**: `txqueuelen 10000` tetap aktif setelah reboot via `/etc/udev/rules.d/60-txqueuelen.rules`.
* **Net Watchdog** (`net-watchdog.timer`): Cek status interface tiap **60 detik**, auto-recover jika down. Log tersimpan di `/var/log/net-watchdog.log`.
* **systemd-networkd-wait-online**: Semua layanan VPN menunggu network benar-benar UP sebelum start.

### 🤖 **Telegram Seller Bot Panel Interactive**
* **Manajemen Akun via Bot**: Buat, hapus, perpanjang, dan cek daftar akun (SSH, VMess, VLess, Trojan, WireGuard).
* **Custom Max Login IP**: Admin / Seller bebas memasukkan limit IP / Device saat membuat akun SSH.
* **Auto Reboot Control (`/reboot`)**: Atur jadwal restart VPS (1 Jam, 6 Jam, 12 Jam, 24 Jam 04:00 Subuh, 1 Minggu, atau Off) dari Telegram chat.
* **RAM Cache Cleaner (`/clear_ram`)**: Membersihkan cache memori RAM VPS secara instan via chat.
* **Bot Latency Check (`/ping`)**: Cek kecepatan respon bot & status BBR / `fq_codel`.
* **Auto Backup ke Telegram**: File `.zip` cadangan database dikirimkan langsung ke Telegram Admin via `sendDocument` API.
* **Pemberitahuan Akun Expired (`xp`)**: Notifikasi otomatis saat akun kadaluwarsa dibersihkan dari sistem.

### 🔒 **Manajemen & Keamanan System**
* **SSH Multi-Login Limiter** (Go): Pemantauan & auto-kill sesi login berlebih, resolusi IP real via WS/Stunnel mapping.
* **Fail2ban**: Proteksi otomatis dari serangan brute-force pada semua port SSH.
* **Netdata Dashboard**: Monitoring statistik resource server via browser (`https://domain/netdata/`).
* **Stunnel4 TLS Wrapper**: Port `222`, `777` (Dropbear TLS), `990` (OpenSSH TLS).
* **Squid Proxy**: Port `3128` & `8080` untuk HTTP proxy.

---

## 📋 Daftar Port Layanan

| Layanan | Port |
| :--- | :--- |
| **SSH WS TLS / V2Ray TLS** | `443` |
| **SSH WS HTTP** | `80`, `2080`, `2082` |
| **OpenSSH** | `22`, `109`, `3303` |
| **Dropbear** | `111`, `69`, `143` |
| **SSL/TLS (Stunnel4)** | `222`, `777`, `990` |
| **Go WebSocket Proxy** | `700` (plain), `701` (TLS) |
| **SOCKS5 Proxy** | `1080` |
| **Squid HTTP Proxy** | `3128`, `8080` |
| **API Server (Go)** | `9000` |
| **UDP Custom** | `1-65535` & `36712` |
| **BadVPN UDPGateway** | `7100`, `7200`, `7300` |
| **WireGuard VPN** | `51820` |
| **SlowDNS / DNSTT** | `53`, `5300` |
| **Netdata Web Dashboard** | `https://domain/netdata/` |

---

## 🗂️ Struktur Go Source Code

```
sws-go/
├── bin/                        # Pre-built Linux amd64 binaries
│   ├── server                  # API Server binary
│   ├── proxy                   # WebSocket/HTTP/SOCKS5 proxy binary
│   └── ssh-limit               # SSH session limiter binary
├── cmd/
│   ├── server/main.go          # Entrypoint API server
│   ├── proxy/main.go           # Entrypoint proxy (-b addr -p port)
│   └── ssh-limit/main.go       # Entrypoint ssh-limit (--check | enforce)
├── internal/
│   ├── server/server.go        # Bearer auth, script execution, logging
│   ├── proxy/
│   │   ├── proxy.go            # TCP listener & TLS support
│   │   ├── handler.go          # HTTP CONNECT, WebSocket, V2Ray routing
│   │   └── socks5.go           # SOCKS5 protocol handler
│   └── sshlimit/
│       ├── ssconn.go           # Parser ss -tnp & stunnel mapping
│       ├── sessions.go         # Dropbear + OpenSSH session detection
│       └── enforce.go          # Limit enforcement & display
├── go.mod
├── Makefile
├── install.sh
├── update.sh
└── uninstall.sh
```

### Build dari Source
```bash
# Clone repo
git clone https://github.com/BrianStovia/VPN-SCRIPT.git
cd VPN-SCRIPT

# Build semua binary (Linux amd64)
make all

# Kompilasi & enkripsi semua skrip shell dengan SHC (Anti-Bajak)
make compile-shc

# Atau build binary + SHC sekaligus
make secure
```

---

## 🔒 Sistem Keamanan & Anti-Bajak (Anti-Theft)

Autoscript ini dilengkapi sistem proteksi ganda agar tidak dapat dibajak atau dicuri:

### 1. 🛡️ Otorisasi IP Whitelist & Expired Date
Installer dan menu dilindungi verifikasi lisensi remote sebelum script dijalankan:
* **Format Database Lisensi (`permission.txt` / GitHub Raw):**
  ```text
  ### <NAMA_CLIENT> <YYYY-MM-DD> <IP_VPS>
  ```
  *Contoh:*
  ```text
  ### AdminDev 2035-12-31 127.0.0.1
  ### UserPremium 2026-12-31 103.150.12.34
  ```
* **Mekanisme Validasi**:
  * Jika IP VPS tidak terdaftar $\rightarrow$ instalasi langsung dibatalkan (**Access Denied**) dan file installer otomatis dihapus.
  * Jika tanggal lisensi sudah lewat $\rightarrow$ instalasi ditolak (**License Expired**).
  * Di VPS yang sudah terinstall, service **`license-check.timer`** mengecek status lisensi secara berkala. Jika IP dicabut dari GitHub, seluruh tunneling service otomatis dimatikan.

### 2. 🔐 Kompilasi SHC (Shell Script Compiler to ELF Binary)
* Semua script shell Bash dikompilasi menjadi **binary ELF stripped** native menggunakan `shc`.
* Source code asli Bash tidak lagi tersimpan dalam bentuk teks terbuka di folder `/usr/local/sbin`.
* Jika pengguna lain membuka file dengan `cat` atau `nano`, mereka hanya akan melihat kode biner mesin terenkripsi, sehingga source code script Anda aman dari penyalinan atau perubahan merek (rebranding).

## 💻 Sistem Operasi yang Didukung

* **Ubuntu**: 18.04 LTS, 20.04 LTS, 22.04 LTS, 24.04 LTS (64-bit)
* **Debian**: 10, 11, 12 (64-bit)

---

## 📥 Cara Instalasi (One-Line Installer)

Masuk ke terminal VPS Anda sebagai `root`, lalu jalankan perintah berikut:

```bash
apt update && apt install -y curl wget && sysctl -w net.ipv4.ip_forward=1 && wget -q -O install.sh https://raw.githubusercontent.com/BrianStovia/VPN-SCRIPT/main/install.sh && chmod +x install.sh && ./install.sh
```

---

## 🔄 Cara Memperbarui Autoscript (Update)

Untuk memperbarui script & menerapkan patch optimasi terbaru di VPS Anda, cukup ketik:

```bash
update
```

*(atau jalankan perintah one-line di bawah ini):*

```bash
wget -q -O update.sh https://raw.githubusercontent.com/BrianStovia/VPN-SCRIPT/main/update.sh && chmod +x update.sh && ./update.sh
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
* **Repository**: [BrianStovia/VPN-SCRIPT](https://github.com/BrianStovia/VPN-SCRIPT)
* **License**: MIT
