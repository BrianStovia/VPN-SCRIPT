package proxy

import (
	"encoding/binary"
	"fmt"
	"log"
	"net"
)

// handleSOCKS5 implements the SOCKS5 handshake and CONNECT command.
// Only localhost SSH ports are allowed as targets (anti open-proxy).
func (h *ConnectionHandler) handleSOCKS5(initial []byte) {
	_ = initial // already read the first byte (version=5); rest below

	// Auth negotiation: reply "no auth required"
	h.client.Write([]byte{0x05, 0x00}) //nolint:errcheck

	// Read SOCKS5 request: VER CMD RSV ATYP
	header := make([]byte, 4)
	if _, err := readFull(h.client, header); err != nil {
		return
	}
	// header[1] = CMD; we only support CONNECT (0x01)
	if header[1] != 0x01 {
		h.close()
		return
	}

	// Parse address based on ATYP
	var address string
	switch header[3] {
	case 0x01: // IPv4
		addr := make([]byte, 4)
		if _, err := readFull(h.client, addr); err != nil {
			return
		}
		address = net.IP(addr).String()
	case 0x03: // Domain name
		lenBuf := make([]byte, 1)
		if _, err := readFull(h.client, lenBuf); err != nil {
			return
		}
		domBuf := make([]byte, int(lenBuf[0]))
		if _, err := readFull(h.client, domBuf); err != nil {
			return
		}
		address = string(domBuf)
	default:
		h.close()
		return
	}

	// Read port (2 bytes, big-endian)
	portBuf := make([]byte, 2)
	if _, err := readFull(h.client, portBuf); err != nil {
		return
	}
	port := int(binary.BigEndian.Uint16(portBuf))

	// Enforce allowed ports
	portStr := fmt.Sprintf("%d", port)
	if portStr != "22" && portStr != "109" && portStr != "111" && portStr != "3303" {
		port = 109
	}
	targetHost := fmt.Sprintf("127.0.0.1:%d", port)

	log.Printf("Connection %s - SOCKS5 CONNECT %s (original target %s:%d)", h.remoteAddr, targetHost, address, port)

	if err := h.connectTarget(targetHost); err != nil {
		log.Printf("SOCKS5 connect error: %v", err)
		return
	}

	// SOCKS5 success response: VER REP RSV ATYP BND.ADDR BND.PORT
	h.client.Write([]byte{0x05, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00}) //nolint:errcheck

	h.doProxy(true)
}

// readFull reads exactly len(buf) bytes.
func readFull(c net.Conn, buf []byte) (int, error) {
	total := 0
	for total < len(buf) {
		n, err := c.Read(buf[total:])
		total += n
		if err != nil {
			return total, err
		}
	}
	return total, nil
}
