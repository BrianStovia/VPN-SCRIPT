//go:build linux

// Package sshlimit parses network connections from `ss -tnp`.
package sshlimit

import (
	"bufio"
	"bytes"
	"fmt"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
)

// Conn represents one TCP socket entry from `ss -tnp`.
type Conn struct {
	PID        int
	LocalIP    string
	LocalPort  int
	RemoteIP   string
	RemotePort int
	Proc       string
}

var (
	connRE = regexp.MustCompile(`^\S+\s+\S+\s+\S+\s+(\[?[\d\.:a-fA-F]+\]?):(\d+)\s+(\[?[\d\.:a-fA-F]+\]?):(\d+)\s+users:\((.+)\)`)
	pidRE  = regexp.MustCompile(`"([^"]+)",pid=(\d+)`)
)

// StunnelPorts maps a stunnel local port → real client IP.
type StunnelPorts map[int]string

// GetSSConnections runs `ss -tnp` and returns connections + stunnel port map.
func GetSSConnections() ([]Conn, StunnelPorts, error) {
	out, err := exec.Command("ss", "-tnp").Output()
	if err != nil {
		return nil, nil, fmt.Errorf("ss -tnp: %w", err)
	}

	var conns []Conn
	stunnel := make(StunnelPorts)

	// pid → list of its Conn entries (for stunnel pairing)
	type stunnelGroup struct {
		localPorts []int
		publicIP   string
	}
	groups := map[int]*stunnelGroup{}

	sc := bufio.NewScanner(bytes.NewReader(out))
	for sc.Scan() {
		line := sc.Text()
		m := connRE.FindStringSubmatch(strings.TrimSpace(line))
		if m == nil {
			continue
		}
		localIP := stripBrackets(m[1])
		localPort, _ := strconv.Atoi(m[2])
		remoteIP := stripBrackets(m[3])
		remotePort, _ := strconv.Atoi(m[4])
		usersStr := m[5]

		for _, pm := range pidRE.FindAllStringSubmatch(usersStr, -1) {
			proc := pm[1]
			pid, _ := strconv.Atoi(pm[2])
			c := Conn{
				PID:        pid,
				LocalIP:    localIP,
				LocalPort:  localPort,
				RemoteIP:   remoteIP,
				RemotePort: remotePort,
				Proc:       proc,
			}
			conns = append(conns, c)

			if strings.Contains(strings.ToLower(proc), "stunnel") {
				if _, ok := groups[pid]; !ok {
					groups[pid] = &stunnelGroup{}
				}
				g := groups[pid]
				if isLocalhost(remoteIP) && isSSHPort(remotePort) {
					g.localPorts = append(g.localPorts, localPort)
				} else if !isLocalhost(remoteIP) {
					g.publicIP = remoteIP
				}
			}
		}
	}

	for _, g := range groups {
		if g.publicIP != "" {
			for _, lp := range g.localPorts {
				stunnel[lp] = g.publicIP
			}
		}
	}

	return conns, stunnel, sc.Err()
}

func stripBrackets(s string) string {
	return strings.NewReplacer("[", "", "]", "").Replace(s)
}

func isLocalhost(ip string) bool {
	return ip == "127.0.0.1" || ip == "::1" || ip == "localhost"
}

func isSSHPort(port int) bool {
	switch port {
	case 22, 109, 111, 3303:
		return true
	}
	return false
}
