package proxy

import (
	"bufio"
	"bytes"
	"crypto/sha1" //nolint:gosec
	"encoding/base64"
	"fmt"
	"io"
	"log"
	"net"
	"os"
	"strings"
	"sync"
	"time"
)

// staticWSResponse is the fallback WebSocket upgrade response when no
// Sec-WebSocket-Key is present (mirrors the Python RESPONSE constant).
var staticWSResponse = []byte(
	"HTTP/1.1 101 Switching Protocols\r\n" +
		"Upgrade: websocket\r\n" +
		"Connection: Upgrade\r\n" +
		"Sec-WebSocket-Accept: foo\r\n\r\n",
)

// allowedSSHPorts are the only ports that traffic is forwarded to.
var allowedSSHPorts = map[string]bool{
	"22": true, "109": true, "110": true, "111": true, "143": true, "3303": true,
}

// v2rayPaths are path prefixes routed to the local V2Ray/Nginx backend.
var v2rayPaths = []string{"/vmess", "/vless", "/trojan", "/noobz", "/api", "/netdata"}

// v2rayBackend is the upstream address for V2Ray/Nginx traffic.
const v2rayBackend = "127.0.0.1:2080"

// wsMu guards ws-ports.txt file writes.
var wsMu sync.Mutex

func addWSMapping(localPort string, realIP string) {
	wsMu.Lock()
	defer wsMu.Unlock()
	f, err := os.OpenFile(wsMappingFile, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return
	}
	defer f.Close()
	fmt.Fprintf(f, "%s:%s\n", localPort, realIP)
}

func removeWSMapping(localPort string) {
	wsMu.Lock()
	defer wsMu.Unlock()
	data, err := os.ReadFile(wsMappingFile)
	if err != nil {
		return
	}
	prefix := localPort + ":"
	var out []byte
	for _, line := range bytes.Split(data, []byte("\n")) {
		if len(line) == 0 {
			continue
		}
		if !strings.HasPrefix(string(line), prefix) {
			out = append(out, line...)
			out = append(out, '\n')
		}
	}
	os.WriteFile(wsMappingFile, out, 0o644) //nolint:errcheck
}

// ConnectionHandler handles a single client connection.
type ConnectionHandler struct {
	client net.Conn
	target net.Conn
	server *Server
	remoteAddr string
}

func newConnectionHandler(conn net.Conn, s *Server) *ConnectionHandler {
	return &ConnectionHandler{
		client:     conn,
		server:     s,
		remoteAddr: conn.RemoteAddr().String(),
	}
}

func (h *ConnectionHandler) close() {
	if h.client != nil {
		h.client.Close()
	}
	if h.target != nil {
		h.target.Close()
	}
}

// serve is the goroutine entry point for each connection.
func (h *ConnectionHandler) serve() {
	defer func() {
		h.close()
		h.server.removeConn(h)
	}()

	// Set TCP options
	if tc, ok := h.client.(*net.TCPConn); ok {
		tc.SetNoDelay(true)    //nolint:errcheck
		tc.SetKeepAlive(true)  //nolint:errcheck
	}

	// Read the initial buffer
	h.client.SetReadDeadline(time.Now().Add(1 * time.Second)) //nolint:errcheck
	buf := make([]byte, bufLen)
	n, err := h.client.Read(buf)
	if err != nil || n == 0 {
		return
	}
	clientBuf := buf[:n]
	h.client.SetReadDeadline(time.Time{}) //nolint:errcheck

	// SOCKS5 detection
	if len(clientBuf) > 0 && clientBuf[0] == 5 {
		h.handleSOCKS5(clientBuf)
		return
	}

	// Read remainder of HTTP headers
	h.client.SetReadDeadline(time.Now().Add(1 * time.Second)) //nolint:errcheck
	for {
		if bytes.Contains(bytes.ToLower(clientBuf), []byte("ssh-")) {
			break
		}
		if bytes.Contains(clientBuf, []byte("\r\n\r\n")) {
			h.client.SetReadDeadline(time.Now().Add(100 * time.Millisecond)) //nolint:errcheck
		}
		tmp := make([]byte, bufLen)
		nn, rerr := h.client.Read(tmp)
		if nn > 0 {
			clientBuf = append(clientBuf, tmp[:nn]...)
		}
		if rerr != nil {
			break
		}
	}
	h.client.SetReadDeadline(time.Time{}) //nolint:errcheck

	// Split HTTP payload and SSH leftover
	sshIdx := bytes.Index(bytes.ToLower(clientBuf), []byte("ssh-"))
	var httpPayload, leftover []byte
	if sshIdx != -1 {
		httpPayload = clientBuf[:sshIdx]
		leftover = clientBuf[sshIdx:]
	} else {
		httpPayload = clientBuf
	}
	_ = httpPayload

	// X-Split header: read one more chunk
	if findHeader(clientBuf, "X-Split") != "" {
		h.client.SetReadDeadline(time.Now().Add(500 * time.Millisecond)) //nolint:errcheck
		tmp := make([]byte, bufLen)
		if nn, _ := h.client.Read(tmp); nn > 0 {
			if sshIdx != -1 {
				leftover = append(leftover, tmp[:nn]...)
			} else {
				clientBuf = append(clientBuf, tmp[:nn]...)
			}
		}
		h.client.SetReadDeadline(time.Time{}) //nolint:errcheck
	}

	isHTTP := isHTTPRequest(clientBuf)
	isConnect := bytes.HasPrefix(bytes.ToLower(clientBuf), []byte("connect"))

	// Parse CONNECT target host
	requestHost := ""
	for _, line := range bytes.Split(clientBuf, []byte("\n")) {
		line = bytes.TrimRight(line, "\r\n ")
		if bytes.HasPrefix(bytes.ToLower(line), []byte("connect ")) {
			parts := bytes.Fields(line)
			if len(parts) >= 2 {
				requestHost = string(parts[1])
			}
			break
		}
	}

	hostPort := firstNonEmpty(
		requestHost,
		findHeader(clientBuf, "X-Real-Host"),
		findHeader(clientBuf, "Host"),
		defaultHost,
	)

	passwd := findHeader(clientBuf, "X-Pass")
	_ = passwd // PASS feature: not configured by default

	// Check if path is a V2Ray/Nginx path
	isV2ray := false
	if isHTTP {
		firstLine := strings.TrimSpace(strings.SplitN(string(clientBuf), "\n", 2)[0])
		parts := strings.Fields(firstLine)
		if len(parts) >= 2 {
			reqPath := strings.ToLower(parts[1])
			for _, vp := range v2rayPaths {
				if strings.HasPrefix(reqPath, vp) {
					isV2ray = true
					break
				}
			}
		}
	}

	if isV2ray {
		if err := h.connectTarget(v2rayBackend); err != nil {
			log.Printf("v2ray connect error: %v", err)
			return
		}
		h.target.Write(clientBuf) //nolint:errcheck
		log.Printf("Connection %s - V2RAY %s", h.remoteAddr, v2rayBackend)
		h.doProxy(true)
		return
	}

	// SSH routing: extract port, validate
	_, _, portStr := partitionHost(hostPort)
	if portStr == "" {
		portStr = "109"
	}
	if !allowedSSHPorts[portStr] {
		portStr = "109"
	}
	targetHost := "127.0.0.1:" + portStr

	if err := h.connectTarget(targetHost); err != nil {
		log.Printf("connect %s error: %v", targetHost, err)
		return
	}

	// Record WS IP mapping
	if localAddr, ok := h.target.LocalAddr().(*net.TCPAddr); ok {
		realIP := findHeader(clientBuf, "X-Real-IP")
		if realIP == "" {
			realIP = findHeader(clientBuf, "X-Forwarded-For")
		}
		if realIP != "" {
			realIP = strings.TrimSpace(strings.SplitN(realIP, ",", 2)[0])
		} else {
			realIP, _, _ = net.SplitHostPort(h.remoteAddr)
		}
		localPort := fmt.Sprintf("%d", localAddr.Port)
		addWSMapping(localPort, realIP)
		defer removeWSMapping(localPort)
	}

	// Forward leftover SSH bytes
	if len(leftover) > 0 {
		h.target.Write(leftover) //nolint:errcheck
	}

	// Send HTTP response back to client
	if isHTTP {
		if isConnect {
			h.client.Write([]byte("HTTP/1.1 200 OK\r\n\r\n")) //nolint:errcheck
		} else {
			wsKey := findHeader(clientBuf, "Sec-WebSocket-Key")
			if wsKey != "" {
				h.client.Write(buildWSAccept(wsKey)) //nolint:errcheck
			} else {
				h.client.Write(staticWSResponse) //nolint:errcheck
			}
		}
	}

	log.Printf("Connection %s - CONNECT %s", h.remoteAddr, targetHost)
	h.doProxy(sshIdx != -1 || !isHTTP)
}

// connectTarget dials the upstream address.
func (h *ConnectionHandler) connectTarget(addr string) error {
	conn, err := net.DialTimeout("tcp", addr, connectTimeout)
	if err != nil {
		return err
	}
	if tc, ok := conn.(*net.TCPConn); ok {
		tc.SetNoDelay(true)   //nolint:errcheck
		tc.SetKeepAlive(true) //nolint:errcheck
	}
	h.target = conn
	return nil
}

// doProxy bidirectionally copies data between client and target.
func (h *ConnectionHandler) doProxy(_ bool) {
	done := make(chan struct{}, 2)
	copy := func(dst, src net.Conn) {
		defer func() { done <- struct{}{} }()
		buf := make([]byte, bufLen)
		for {
			src.SetReadDeadline(time.Now().Add(idleTimeout)) //nolint:errcheck
			n, err := src.Read(buf)
			if n > 0 {
				dst.SetWriteDeadline(time.Now().Add(30 * time.Second)) //nolint:errcheck
				if _, werr := dst.Write(buf[:n]); werr != nil {
					return
				}
			}
			if err != nil {
				return
			}
		}
	}
	go copy(h.target, h.client)
	go copy(h.client, h.target)
	<-done
}

// ── helpers ──────────────────────────────────────────────────────────────────

func isHTTPRequest(buf []byte) bool {
	lower := bytes.ToLower(buf)
	for _, m := range [][]byte{[]byte("get "), []byte("post "), []byte("connect "), []byte("http/")} {
		if bytes.Contains(lower, m) {
			return true
		}
	}
	return false
}

// findHeader searches buf for header (case-insensitive) and returns its value.
func findHeader(buf []byte, header string) string {
	headerLower := strings.ToLower(header) + ":"
	sc := bufio.NewScanner(bytes.NewReader(buf))
	for sc.Scan() {
		line := strings.TrimRight(sc.Text(), "\r\n ")
		if strings.HasPrefix(strings.ToLower(line), headerLower) {
			return strings.TrimSpace(line[len(headerLower):])
		}
	}
	return ""
}

// partitionHost splits "host:port" → (host, ":", port).
func partitionHost(hostPort string) (string, string, string) {
	idx := strings.LastIndex(hostPort, ":")
	if idx == -1 {
		return hostPort, "", ""
	}
	return hostPort[:idx], ":", hostPort[idx+1:]
}

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if v != "" {
			return v
		}
	}
	return ""
}

// buildWSAccept generates the Sec-WebSocket-Accept response header value.
func buildWSAccept(key string) []byte {
	const magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
	h := sha1.New() //nolint:gosec
	io.WriteString(h, key+magic) //nolint:errcheck
	accept := base64.StdEncoding.EncodeToString(h.Sum(nil))
	resp := "HTTP/1.1 101 Switching Protocols\r\n" +
		"Upgrade: websocket\r\n" +
		"Connection: Upgrade\r\n" +
		"Server: rbstv-Proxy\r\n" +
		"Sec-WebSocket-Accept: " + accept + "\r\n\r\n"
	return []byte(resp)
}
