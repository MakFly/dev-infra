.PHONY: help install uninstall up up-async down restart ps logs doctor db-create db-list runtime down-runtime

DEVHUB := ./bin/devhub

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
