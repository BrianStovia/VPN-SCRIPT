//go:build linux

package main

import (
	"log"
	"os"

	"github.com/BrianStovia/sws-go/internal/sshlimit"
)

func main() {
	conns, stunnel, err := sshlimit.GetSSConnections()
	if err != nil {
		log.Printf("warning: could not read ss connections: %v", err)
	}

	ws := sshlimit.GetWSMappings()
	sessions := sshlimit.GetActiveSessions(conns, stunnel, ws)
	limits := sshlimit.GetPasswdLimits()

	if len(os.Args) > 1 && os.Args[1] == "--check" {
		sshlimit.CheckLogins(sessions)
	} else {
		sshlimit.EnforceLimits(sessions, limits, 2)
	}
}
