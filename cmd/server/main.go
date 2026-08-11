package main

import (
	"log"

	"github.com/BrianStovia/sws-go/internal/server"
)

func main() {
	if err := server.Run(":9000", "/etc/api/key", "/var/log/api.log"); err != nil {
		log.Fatalf("server error: %v", err)
	}
}
