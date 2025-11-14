.PHONY: help init start stop status backup

# Default target
help:
	@echo "Midnight Miner - VPS Management"
	@echo ""
	@echo "Prerequisites: SSH key access to root@<hostname>"
	@echo ""
	@echo "Usage: make <target>-<host>"
	@echo ""
	@echo "Targets:"
	@echo "  init-<host>   - Install mining software on VPS (runs as root)"
	@echo "  start-<host>  - Start mining process"
	@echo "  stop-<host>   - Stop mining process"
	@echo "  status-<host> - Show mining status and save to status.md"
	@echo "  backup-<host> - Backup wallets and status to local data/ folder"
	@echo ""
	@echo "Example:"
	@echo "  make init-v01"
	@echo "  make start-v01"
	@echo "  make status-v01"
	@echo ""
	@echo "Config files are in config/<host>.conf"
	@echo "Miner runs as root in /root/midnight-miner"

# Load host configuration
load-config-%:
	@if [ ! -f "config/$*.conf" ]; then \
		echo "Error: config/$*.conf not found"; \
		echo "Create it from config/v01.conf.example"; \
		exit 1; \
	fi

# Get config values (source the config file)
get-hostname-%: load-config-%
	@. config/$*.conf && echo $$HOSTNAME

get-datadir-%: load-config-%
	@. config/$*.conf && echo $$DATA_DIR

# VPS Mining Setup
init-%: load-config-%
	@echo "=== Setting up mining on VPS: $* ==="
	@HOSTNAME=$$($(MAKE) -s get-hostname-$*); \
	echo "Target: root@$$HOSTNAME"; \
	echo ""; \
	echo "Installing dependencies on $$HOSTNAME..."; \
	ssh root@$$HOSTNAME "apt update && apt install -y python3.12-venv python3-pip build-essential"; \
	echo ""; \
	echo "Creating mining directory..."; \
	ssh root@$$HOSTNAME "mkdir -p /root/midnight-miner"; \
	echo ""; \
	echo "Uploading miner code..."; \
	rsync -avz \
		--exclude='.git' \
		--exclude='.venv' \
		--exclude='venv' \
		--exclude='*.log' \
		--exclude='wallets.json' \
		--exclude='balances.json' \
		--exclude='challenges.json' \
		--exclude='config' \
		--exclude='data' \
		--exclude='vps' \
		. root@$$HOSTNAME:/root/midnight-miner/; \
	echo ""; \
	echo "Installing Python dependencies..."; \
	ssh root@$$HOSTNAME "cd /root/midnight-miner && python3 -m venv .venv && source .venv/bin/activate && pip install -q -r requirements.txt"; \
	echo ""; \
	echo "Installing systemd service..."; \
	ssh root@$$HOSTNAME "bash -s" < scripts/install-service.sh; \
	echo ""; \
	echo "Mining setup complete!"; \
	echo ""; \
	echo "Next step: make start-$*"

# Start Mining
start-%: load-config-%
	@echo "=== Starting mining on VPS: $* ==="
	@HOSTNAME=$$($(MAKE) -s get-hostname-$*); \
	ssh root@$$HOSTNAME "systemctl start midnight-miner"; \
	sleep 2; \
	ssh root@$$HOSTNAME "systemctl status midnight-miner --no-pager"; \
	echo ""; \
	echo "Mining started! Check logs with: make status-$*"

# Stop Mining
stop-%: load-config-%
	@echo "=== Stopping mining on VPS: $* ==="
	@HOSTNAME=$$($(MAKE) -s get-hostname-$*); \
	ssh root@$$HOSTNAME "systemctl stop midnight-miner"; \
	echo "Mining stopped!"

# Mining Status
status-%: load-config-%
	@echo "=== Mining status for VPS: $* ==="
	@HOSTNAME=$$($(MAKE) -s get-hostname-$*); \
	DATADIR=$$($(MAKE) -s get-datadir-$*); \
	mkdir -p $$DATADIR; \
	echo "Fetching status from $$HOSTNAME..."; \
	ssh root@$$HOSTNAME "bash -s" < scripts/get-status.sh > $$DATADIR/status.md; \
	echo ""; \
	cat $$DATADIR/status.md; \
	echo ""; \
	echo "Status saved to $$DATADIR/status.md"

# Backup Mining Data
backup-%: load-config-%
	@echo "=== Backing up mining data from VPS: $* ==="
	@HOSTNAME=$$($(MAKE) -s get-hostname-$*); \
	DATADIR=$$($(MAKE) -s get-datadir-$*); \
	TIMESTAMP=$$(date +%Y%m%d-%H%M%S); \
	mkdir -p $$DATADIR; \
	echo "Downloading wallets.json..."; \
	scp root@$$HOSTNAME:/root/midnight-miner/wallets.json $$DATADIR/wallets-$$TIMESTAMP.json 2>/dev/null || echo "No wallets.json found"; \
	echo "Downloading balances.json..."; \
	scp root@$$HOSTNAME:/root/midnight-miner/balances.json $$DATADIR/balances-$$TIMESTAMP.json 2>/dev/null || echo "No balances.json found"; \
	echo "Downloading challenges.json..."; \
	scp root@$$HOSTNAME:/root/midnight-miner/challenges.json $$DATADIR/challenges-$$TIMESTAMP.json 2>/dev/null || echo "No challenges.json found"; \
	echo "Generating status report..."; \
	$(MAKE) status-$*; \
	echo ""; \
	echo "Backup complete! Files saved to $$DATADIR/"

# Catch-all pattern targets
init:
	@echo "Usage: make init-<host>"
	@echo "Example: make init-v01"

start:
	@echo "Usage: make start-<host>"
	@echo "Example: make start-v01"

stop:
	@echo "Usage: make stop-<host>"
	@echo "Example: make stop-v01"

status:
	@echo "Usage: make status-<host>"
	@echo "Example: make status-v01"

backup:
	@echo "Usage: make backup-<host>"
	@echo "Example: make backup-v01"
