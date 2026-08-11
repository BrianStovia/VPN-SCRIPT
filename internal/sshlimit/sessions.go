//go:build linux

package sshlimit

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
)

// Session represents an active SSH login (OpenSSH or Dropbear).
type Session struct {
	PID      int
	Username string
	RealIP   string
	Type     string // "OpenSSH" or "Dropbear"
}

// WSMap maps a local TCP port (from ws-ports.txt) to the real client IP.
type WSMap map[int]string

// GetWSMappings reads /dev/shm/ws-ports.txt → port:ip pairs.
func GetWSMappings() WSMap {
	m := make(WSMap)
	f, err := os.Open("/dev/shm/ws-ports.txt")
	if err != nil {
		return m
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		parts := strings.SplitN(sc.Text(), ":", 2)
		if len(parts) != 2 {
			continue
		}
		port, err := strconv.Atoi(strings.TrimSpace(parts[0]))
		if err != nil {
			continue
		}
		m[port] = strings.TrimSpace(parts[1])
	}
	return m
}

// GetPasswdLimits reads /etc/passwd and extracts "limit=N" from GECOS fields.
func GetPasswdLimits() map[string]int {
	limits := make(map[string]int)
	f, err := os.Open("/etc/passwd")
	if err != nil {
		return limits
	}
	defer f.Close()
	limitRE := regexp.MustCompile(`limit[=:](\d+)`)
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		parts := strings.Split(sc.Text(), ":")
		if len(parts) < 5 {
			continue
		}
		username := parts[0]
		gecos := parts[4]
		if m := limitRE.FindStringSubmatch(gecos); m != nil {
			n, _ := strconv.Atoi(m[1])
			limits[username] = n
		}
	}
	return limits
}

// GetActiveSessions returns all current SSH sessions, resolving real IPs via
// stunnel and WebSocket mappings.
func GetActiveSessions(conns []Conn, stunnel StunnelPorts, ws WSMap) []Session {
	var sessions []Session

	// ── Dropbear sessions via journalctl ──────────────────────────────────
	logLines := dropbearLogLines()

	type dbLogin struct {
		user string
		ip   string
		port int
	}
	dbLogins := map[int]dbLogin{}

	loginRE := regexp.MustCompile(`dropbear\[(\d+)\]:.*Password auth succeeded for '([^']+)' from ([\d\.]+):(\d+)`)
	exitRE  := regexp.MustCompile(`dropbear\[(\d+)\]:.*Exit \(`)

	for _, line := range logLines {
		if m := loginRE.FindStringSubmatch(line); m != nil {
			pid, _ := strconv.Atoi(m[1])
			port, _ := strconv.Atoi(m[4])
			dbLogins[pid] = dbLogin{user: m[2], ip: m[3], port: port}
		} else if m := exitRE.FindStringSubmatch(line); m != nil {
			pid, _ := strconv.Atoi(m[1])
			delete(dbLogins, pid)
		}
	}

	for pid, dl := range dbLogins {
		if _, err := os.Stat(fmt.Sprintf("/proc/%d", pid)); err != nil {
			continue
		}
		realIP := dl.ip
		if isLocalhost(dl.ip) {
			if ip, ok := ws[dl.port]; ok {
				realIP = ip
			} else if ip, ok := stunnel[dl.port]; ok {
				realIP = ip
			}
		}
		sessions = append(sessions, Session{PID: pid, Username: dl.user, RealIP: realIP, Type: "Dropbear"})
	}

	// ── OpenSSH sessions via /proc UID lookup ─────────────────────────────
	pidSet := map[int]bool{}
	for _, s := range sessions {
		pidSet[s.PID] = true
	}

	for _, c := range conns {
		if c.Proc != "sshd" && c.Proc != "sshd-session" {
			continue
		}
		pid := c.PID
		if pidSet[pid] {
			continue
		}
		username, uid, err := procUser(pid)
		if err != nil || uid < 1000 || username == "root" || username == "sshd" || username == "nobody" {
			continue
		}

		realIP := c.RemoteIP
		if isLocalhost(realIP) {
			if ip, ok := ws[c.RemotePort]; ok {
				realIP = ip
			} else if ip, ok := stunnel[c.RemotePort]; ok {
				realIP = ip
			}
		}
		sessions = append(sessions, Session{PID: pid, Username: username, RealIP: realIP, Type: "OpenSSH"})
		pidSet[pid] = true
	}

	return sessions
}

// dropbearLogLines fetches the last 500 lines from journalctl or auth.log.
func dropbearLogLines() []string {
	out, err := exec.Command("journalctl", "-u", "dropbear", "-n", "500", "--no-pager").Output()
	if err == nil && len(out) > 0 {
		return strings.Split(string(out), "\n")
	}
	// fallback to auth.log
	f, err := os.Open("/var/log/auth.log")
	if err != nil {
		return nil
	}
	defer f.Close()
	var lines []string
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		lines = append(lines, sc.Text())
	}
	if len(lines) > 500 {
		lines = lines[len(lines)-500:]
	}
	return lines
}

// procUser resolves UID and username from /proc/<pid>/status.
func procUser(pid int) (string, int, error) {
	// Read UID from /proc/<pid>/status
	f, err := os.Open(fmt.Sprintf("/proc/%d/status", pid))
	if err != nil {
		return "", 0, err
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := sc.Text()
		if strings.HasPrefix(line, "Uid:") {
			fields := strings.Fields(line)
			if len(fields) >= 2 {
				uid, _ := strconv.Atoi(fields[1])
				username, uerr := lookupUID(uid)
				if uerr != nil {
					username = strconv.Itoa(uid)
				}
				return username, uid, nil
			}
		}
	}
	return "", 0, fmt.Errorf("uid not found in /proc/%d/status", pid)
}

// lookupUID parses /etc/passwd for the given UID.
func lookupUID(uid int) (string, error) {
	f, err := os.Open("/etc/passwd")
	if err != nil {
		return "", err
	}
	defer f.Close()
	target := strconv.Itoa(uid)
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		parts := strings.Split(sc.Text(), ":")
		if len(parts) >= 4 && parts[2] == target {
			return parts[0], nil
		}
	}
	return "", fmt.Errorf("uid %d not found", uid)
}
