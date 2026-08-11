//go:build linux

package sshlimit

import (
	"fmt"
	"os"
	"sort"
	"strings"
)

const (
	colorBlue   = "\033[0;34m"
	colorYellow = "\033[33;1m"
	colorGreen  = "\033[32;1m"
	colorReset  = "\033[0m"
	separator   = "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
)

// CheckLogins prints the current SSH login status (--check mode).
func CheckLogins(sessions []Session) {
	// Group sessions by username → set of IPs
	userIPs := map[string]map[string]struct{}{}
	for _, s := range sessions {
		if _, ok := userIPs[s.Username]; !ok {
			userIPs[s.Username] = map[string]struct{}{}
		}
		userIPs[s.Username][s.RealIP] = struct{}{}
	}

	fmt.Printf("%s%s%s\n", colorBlue, separator, colorReset)
	fmt.Println("     =[ SSH User Login ]=")
	fmt.Printf("%s%s%s\n", colorBlue, separator, colorReset)

	for user, ips := range userIPs {
		ipList := make([]string, 0, len(ips))
		for ip := range ips {
			ipList = append(ipList, ip)
		}
		sort.Strings(ipList)
		fmt.Printf("%sUser%s  : %s\n", colorYellow, colorGreen, user)
		fmt.Printf("%sLogin%s : %d IP Login (%s)\n", colorYellow, colorGreen, len(ipList), strings.Join(ipList, ", "))
		fmt.Printf("%s%s%s\n", colorBlue, separator, colorReset)
	}
	fmt.Printf("%d User Online\n", len(userIPs))
	fmt.Printf("%s%s%s\n", colorBlue, separator, colorReset)
}

// EnforceLimits kills sessions that exceed per-user IP limits.
func EnforceLimits(sessions []Session, limits map[string]int, defaultLimit int) {
	// Group sessions by username → ip → []Session
	userSessions := map[string][]Session{}
	for _, s := range sessions {
		userSessions[s.Username] = append(userSessions[s.Username], s)
	}

	for user, sessList := range userSessions {
		limit := defaultLimit
		if l, ok := limits[user]; ok {
			limit = l
		}

		// Group by IP
		ipSessions := map[string][]Session{}
		for _, s := range sessList {
			ipSessions[s.RealIP] = append(ipSessions[s.RealIP], s)
		}

		uniqueIPs := make([]string, 0, len(ipSessions))
		for ip := range ipSessions {
			uniqueIPs = append(uniqueIPs, ip)
		}

		if len(uniqueIPs) <= limit {
			continue
		}

		// Sort IPs by minimum PID (oldest connections kept)
		sort.Slice(uniqueIPs, func(i, j int) bool {
			minI := minPID(ipSessions[uniqueIPs[i]])
			minJ := minPID(ipSessions[uniqueIPs[j]])
			return minI < minJ
		})

		toKeep := uniqueIPs[:limit]
		toKill := uniqueIPs[limit:]

		fmt.Printf("User '%s' exceeds limit (%d/%d IPs). Keeping: %v. Killing: %v.\n",
			user, len(uniqueIPs), limit, toKeep, toKill)

		for _, ip := range toKill {
			for _, s := range ipSessions[ip] {
					fmt.Printf("  Killing PID %d (%s connection from %s)\n", s.PID, s.Type, ip)
				if proc, err := os.FindProcess(s.PID); err == nil {
					if kerr := proc.Kill(); kerr != nil {
						fmt.Fprintf(os.Stderr, "  Error killing PID %d: %v\n", s.PID, kerr)
					}
				} else {
					fmt.Fprintf(os.Stderr, "  Error finding PID %d: %v\n", s.PID, err)
				}
			}
		}
	}
}

func minPID(sessions []Session) int {
	min := sessions[0].PID
	for _, s := range sessions[1:] {
		if s.PID < min {
			min = s.PID
		}
	}
	return min
}
