.PHONY: help install uninstall up up-async down restart ps logs doctor db-create db-list runtime down-runtime project-list wt-list version release

DEVHUB := ./bin/devhub
BUMP ?= patch

help:
	@echo "Targets:"
	@echo "  make install              Install devhub globally (symlink + zsh aliases)"
	@echo "  make up                   Start core"
	@echo "  make up-async             Start core+async"
	@echo "  make down                 Stop all"
	@echo "  make restart              Restart core"
	@echo "  make ps                   Show status"
	@echo "  make doctor               Health/network/ports"
	@echo "  make runtime PROJECT=x    Start project runtime override"
	@echo "  make down-runtime PROJECT=x  Stop project runtime"
	@echo "  make project-list         List registered projects"
	@echo "  make wt-list PROJECT=x    List project worktrees"
	@echo "  make version              Show installed version"
	@echo "  make release BUMP=patch   Cut a release (patch|minor|major|X.Y.Z)"

install:
	@./data/scripts/install.sh

uninstall:
	@./data/scripts/uninstall.sh

up:
	@$(DEVHUB) up

up-async:
	@$(DEVHUB) up --with async

down:
	@$(DEVHUB) down

restart:
	@$(DEVHUB) restart

ps:
	@$(DEVHUB) ps

logs:
	@$(DEVHUB) logs

doctor:
	@$(DEVHUB) doctor

db-create:
	@$(DEVHUB) db create $(DB)

db-list:
	@$(DEVHUB) db list

runtime:
	@test -n "$(PROJECT)" || { echo "Usage: make runtime PROJECT=<name>"; exit 1; }
	@$(DEVHUB) runtime $(PROJECT)

down-runtime:
	@test -n "$(PROJECT)" || { echo "Usage: make down-runtime PROJECT=<name>"; exit 1; }
	@$(DEVHUB) down-runtime $(PROJECT)

project-list:
	@$(DEVHUB) project list

wt-list:
	@test -n "$(PROJECT)" || { echo "Usage: make wt-list PROJECT=<name>"; exit 1; }
	@$(DEVHUB) wt list $(PROJECT)

version:
	@$(DEVHUB) version

release:
	@./data/scripts/release.sh $(BUMP)
