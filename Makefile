.PHONY: help install uninstall up up-async up-debug down restart ps logs doctor db-create db-list

DEVHUB := ./bin/devhub

help:
	@echo "Targets:"
	@echo "  make install      Install devhub globally (symlink + zsh aliases)"
	@echo "  make up           Start core+storage"
	@echo "  make up-async     Start core+storage+async"
	@echo "  make up-debug     Start core+storage+debug"
	@echo "  make down         Stop all"
	@echo "  make ps           Show status"
	@echo "  make doctor       Health/network/ports"

install:
	@./scripts/install.sh

uninstall:
	@./scripts/uninstall.sh

up:
	@$(DEVHUB) up

up-async:
	@$(DEVHUB) up --with async

up-debug:
	@$(DEVHUB) up --with debug

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
