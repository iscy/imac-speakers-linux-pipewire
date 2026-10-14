# Makefile for imac-speakers-linux-pipewire
#
#   make install    - install the filter-chain config and ensure the
#                     filter-chain service is enabled and running
#   make uninstall  - remove the config (leaves the service alone)
#   make status     - show whether the service is running and the sink exists
#   make verify     - check that the "iMac" sink is present
#
# The filter-chain config runs in its own systemd *user* service
# (filter-chain.service), separate from the main pipewire service.

PREFIX      ?= $(HOME)
CONF_DIR    := $(PREFIX)/.config/pipewire/filter-chain.conf.d
CONF_SRC    := filter-chain.conf.d/imac.conf
CONF_DST    := $(CONF_DIR)/imac.conf

# systemctl for the user session; overridable for testing
SYSTEMCTL   ?= systemctl --user

.PHONY: install uninstall status verify help
.DEFAULT_GOAL := help

help:
	@echo "Targets:"
	@echo "  make install    install config + enable/start filter-chain service"
	@echo "  make uninstall  remove the installed config"
	@echo "  make status     show service state and sink presence"
	@echo "  make verify     fail unless the iMac sink is present"

install:
	@echo "==> Installing $(CONF_SRC) -> $(CONF_DST)"
	install -Dm644 $(CONF_SRC) $(CONF_DST)
	@echo "==> Ensuring filter-chain service is enabled and running"
	@if $(SYSTEMCTL) list-unit-files 2>/dev/null | grep -q '^filter-chain\.service'; then \
		$(SYSTEMCTL) enable --now filter-chain; \
	else \
		echo "WARNING: filter-chain.service unit not found." >&2; \
		echo "  The filter-chain config must run as a separate client:" >&2; \
		echo "    pipewire -c filter-chain.conf" >&2; \
		echo "  (or create/enable the unit if your distro ships it)"; \
	fi
	@echo "==> Done. Check with: make status"

uninstall:
	@echo "==> Removing $(CONF_DST)"
	rm -f $(CONF_DST)
	@echo "Note: the filter-chain service is left enabled; disable it with"
	@echo "  systemctl --user disable --now filter-chain"
	@echo "  if you no longer use any filter chains."

status:
	@echo "==> filter-chain service:"
	@$(SYSTEMCTL) status filter-chain --no-pager || true
	@echo "==> Sinks:"
	@pactl list short sinks 2>/dev/null | grep -iE 'imac|pro-output' || echo "  (no iMac / pro-output sinks found)"

verify:
	@if pactl list short sinks 2>/dev/null | grep -qi 'iMac'; then \
		echo "OK: iMac sink present"; \
	else \
		echo "FAIL: iMac sink not found. Is the filter-chain service running?" >&2; \
		exit 1; \
	fi
