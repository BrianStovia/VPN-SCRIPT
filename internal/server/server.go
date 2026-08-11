package server

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"
)

// Server holds the API server state.
type Server struct {
	validTokens map[string]struct{}
	logger      *log.Logger
}

// New creates a new Server by loading tokens from tokenFile.
func New(tokenFile string, logWriter io.Writer) (*Server, error) {
	tokens, err := loadTokens(tokenFile)
	if err != nil {
		return nil, fmt.Errorf("load tokens: %w", err)
	}
	logger := log.New(logWriter, "", log.LstdFlags)
	return &Server{validTokens: tokens, logger: logger}, nil
}

// loadTokens reads non-empty lines from path as valid Bearer tokens.
func loadTokens(path string) (map[string]struct{}, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	tokens := make(map[string]struct{})
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line != "" {
			tokens[line] = struct{}{}
		}
	}
	return tokens, sc.Err()
}

// authorize validates Bearer token. Returns true if authorized.
func (s *Server) authorize(w http.ResponseWriter, r *http.Request) bool {
	auth := r.Header.Get("Authorization")
	if !strings.HasPrefix(auth, "Bearer ") {
		s.sendUnauthorized(w, r)
		return false
	}
	token := strings.TrimSpace(auth[len("Bearer "):])
	if _, ok := s.validTokens[token]; !ok {
		s.sendUnauthorized(w, r)
		return false
	}
	return true
}

func (s *Server) sendUnauthorized(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("WWW-Authenticate", `Bearer realm="Authentication required"`)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusUnauthorized)
	w.Write([]byte(`{"message": "Unauthorized: Missing or invalid Bearer token"}`)) //nolint:errcheck
	s.logAccess(r, "Unauthorized access attempt")
}

// executeScript runs scriptPath, optionally feeding postData to stdin.
func (s *Server) executeScript(w http.ResponseWriter, r *http.Request, scriptPath, postData string) {
	if _, err := os.Stat(scriptPath); os.IsNotExist(err) {
		http.Error(w, "Script not found", http.StatusNotFound)
		s.logger.Printf("Script not found: %s", scriptPath)
		return
	}

	cmd := exec.Command(scriptPath) //nolint:gosec
	if postData != "" {
		cmd.Stdin = strings.NewReader(postData)
	}
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		msg, _ := json.Marshal(map[string]string{"error": err.Error()})
		w.Write(msg) //nolint:errcheck
		s.logger.Printf("Error executing script %s: %v", scriptPath, err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(stdout.Bytes()) //nolint:errcheck
	s.logger.Printf("Successfully executed script: %s, Output: %s", scriptPath, stdout.String())
}

func (s *Server) logAccess(r *http.Request, extra string) {
	ip := r.RemoteAddr
	if idx := strings.LastIndex(ip, ":"); idx != -1 {
		ip = ip[:idx]
	}
	ua := r.Header.Get("User-Agent")
	if ua == "" {
		ua = "User-Agent not provided"
	}
	s.logger.Printf("Access from IP: %s, User-Agent: %s, Path: %s, %s", ip, ua, r.URL.Path, extra)
}

// scriptPath builds the absolute path of the script for the given request.
func scriptPath(r *http.Request) string {
	return "/usr/local/sbin/api/" + strings.TrimLeft(r.URL.Path, "/")
}

// ServeHTTP implements http.Handler.
func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if !s.authorize(w, r) {
		return
	}
	s.logAccess(r, "")

	switch r.Method {
	case http.MethodGet, http.MethodHead, http.MethodConnect, http.MethodTrace:
		s.executeScript(w, r, scriptPath(r), "")

	case http.MethodOptions:
		w.Header().Set("Allow", "GET, POST, DELETE, PUT, PATCH, CONNECT, TRACE, HEAD, OPTIONS")
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"message": "OPTIONS request received"}`)) //nolint:errcheck

	default: // POST, DELETE, PUT, PATCH
		body, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "failed to read body", http.StatusBadRequest)
			return
		}
		s.executeScript(w, r, scriptPath(r), string(body))
	}
}

// Run starts the HTTP server on the given address (e.g. ":9000").
func Run(addr string, tokenFile string, logFile string) error {
	// Ensure log file exists
	if err := os.MkdirAll("/var/log", 0o755); err == nil {
		if f, err := os.OpenFile(logFile, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644); err == nil {
			f.Close()
		}
	}

	var writers []io.Writer
	writers = append(writers, os.Stdout)
	if lf, err := os.OpenFile(logFile, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644); err == nil {
		writers = append(writers, lf)
	}
	logWriter := io.MultiWriter(writers...)

	srv, err := New(tokenFile, logWriter)
	if err != nil {
		return err
	}

	logger := log.New(logWriter, "", log.LstdFlags)
	logger.Printf("Starting httpd server on %s", addr)

	httpSrv := &http.Server{
		Addr:         addr,
		Handler:      srv,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 60 * time.Second,
		IdleTimeout:  120 * time.Second,
	}
	return httpSrv.ListenAndServe()
}
