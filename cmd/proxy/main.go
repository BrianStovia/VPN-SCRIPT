package main

import (
	"flag"
	"fmt"
	"log"

	"github.com/BrianStovia/sws-go/internal/proxy"
)

func main() {
	bind := flag.String("b", "127.0.0.1", "bind address")
	port := flag.Int("p", 700, "listen port")
	flag.Parse()

	addr := fmt.Sprintf("%s:%d", *bind, *port)
	fmt.Printf("\n:-------GoProxy-------:\n")
	fmt.Printf("Listening addr: %s\n", *bind)
	fmt.Printf("Listening port: %d\n", *port)
	fmt.Printf(":---------------------:\n")

	// Start plaintext server
	plain := proxy.New(addr, false)
	errCh := make(chan error, 2)
	go func() { errCh <- plain.ListenAndServe() }()

	// Start TLS server on port+1 when default port is 700
	if *port == 700 {
		tlsAddr := fmt.Sprintf("%s:701", *bind)
		fmt.Printf("Listening SSL port: 701\n")
		tls := proxy.New(tlsAddr, true)
		go func() { errCh <- tls.ListenAndServe() }()
	}

	if err := <-errCh; err != nil {
		log.Fatalf("proxy error: %v", err)
	}
}
