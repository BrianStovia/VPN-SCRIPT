BINARY_DIR = bin
GOOS      ?= linux
GOARCH    ?= amd64
CGO_ENABLED = 0

.PHONY: all server proxy ssh-limit vpn-bot clean compile-shc secure

all: server proxy ssh-limit vpn-bot

compile-shc:
	@bash build-shc.sh

secure: all compile-shc

server:
	@mkdir -p $(BINARY_DIR)
	GOOS=$(GOOS) GOARCH=$(GOARCH) CGO_ENABLED=$(CGO_ENABLED) \
		go build -trimpath -ldflags="-s -w" -o $(BINARY_DIR)/server ./cmd/server

proxy:
	@mkdir -p $(BINARY_DIR)
	GOOS=$(GOOS) GOARCH=$(GOARCH) CGO_ENABLED=$(CGO_ENABLED) \
		go build -trimpath -ldflags="-s -w" -o $(BINARY_DIR)/proxy ./cmd/proxy

ssh-limit:
	@mkdir -p $(BINARY_DIR)
	GOOS=$(GOOS) GOARCH=$(GOARCH) CGO_ENABLED=$(CGO_ENABLED) \
		go build -trimpath -ldflags="-s -w" -o $(BINARY_DIR)/ssh-limit ./cmd/ssh-limit

vpn-bot:
	@mkdir -p $(BINARY_DIR)
	GOOS=$(GOOS) GOARCH=$(GOARCH) CGO_ENABLED=$(CGO_ENABLED) \
		go build -trimpath -ldflags="-s -w" -o $(BINARY_DIR)/vpn-bot ./cmd/vpn-bot

clean:
	rm -rf $(BINARY_DIR)

