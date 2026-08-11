// Package proxy implements a WebSocket/HTTP CONNECT / SOCKS5 proxy server
// that tunnels traffic to local SSH daemons, matching the behaviour of the
// original Python proxy script.
package proxy

import (
	"crypto/tls"
	"fmt"
	"log"
	"net"
	"sync"
	"time"
)

const (
	bufLen          = 4096 * 4
	defaultHost     = "127.0.0.1:109"
	connectTimeout  = 10 * time.Second
	idleTimeout     = 3600 * time.Second
)

// wsMappingFile is the shared-memory file used to track WebSocket client IPs.
const wsMappingFile = "/dev/shm/ws-ports.txt"

// Server listens on a TCP port and dispatches connections to ConnectionHandler.
type Server struct {
	addr   string
	useTLS bool

	mu      sync.Mutex
	running bool
	ln      net.Listener
	conns   []*ConnectionHandler
}

// New creates a Server that listens on addr.
// If useTLS is true it loads the V2Ray certificate/key pair for TLS.
func New(addr string, useTLS bool) *Server {
	return &Server{addr: addr, useTLS: useTLS}
}

// ListenAndServe starts the server. It blocks until Stop is called or a fatal
// error occurs.
func (s *Server) ListenAndServe() error {
	var ln net.Listener
	var err error

	if s.useTLS {
		cert, cerr := tls.LoadX509KeyPair(
			"/usr/local/etc/v2ray/v2ray.crt",
			"/usr/local/etc/v2ray/v2ray.key",
		)
		if cerr != nil {
			log.Printf("Failed to load TLS cert: %v — falling back to plain", cerr)
			ln, err = net.Listen("tcp", s.addr)
		} else {
			cfg := &tls.Config{
				Certificates: []tls.Certificate{cert},
				MinVersion:   tls.VersionTLS12,
			}
			ln, err = tls.Listen("tcp", s.addr, cfg)
		}
	} else {
		ln, err = net.Listen("tcp", s.addr)
	}
	if err != nil {
		return fmt.Errorf("listen %s: %w", s.addr, err)
	}

	s.mu.Lock()
	s.ln = ln
	s.running = true
	s.mu.Unlock()

	log.Printf("Listening on %s (TLS=%v)", s.addr, s.useTLS)

	for {
		conn, err := ln.Accept()
		if err != nil {
			s.mu.Lock()
			running := s.running
			s.mu.Unlock()
			if !running {
				return nil
			}
			log.Printf("accept error: %v", err)
			continue
		}
		h := newConnectionHandler(conn, s)
		s.addConn(h)
		go h.serve()
	}
}

// Stop closes the listener and all active connections.
func (s *Server) Stop() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.running = false
	if s.ln != nil {
		s.ln.Close()
	}
	for _, c := range s.conns {
		c.close()
	}
}

func (s *Server) addConn(h *ConnectionHandler) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.conns = append(s.conns, h)
}

func (s *Server) removeConn(h *ConnectionHandler) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i, c := range s.conns {
		if c == h {
			s.conns = append(s.conns[:i], s.conns[i+1:]...)
			return
		}
	}
}
