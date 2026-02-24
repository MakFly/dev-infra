.PHONY: help install uninstall up up-async up-debug down restart ps logs doctor db-create db-list runtime-trading runtime-dist down-trading down-dist

DEVHUB := ./bin/devhub

help:
	@echo "Targets:"
	@echo "  make install              Install devhub globally (symlink + zsh aliases)"
	@echo "  make up                   Start core+storage"
	@echo "  make up-async            Start core+storage+async"
	@echo "  make up-debug             Start core+storage+debug"
	@echo "  make down                 Stop all"
	@echo "  make ps                   Show status"
	@echo "  make doctor               Health/network/ports"
	@echo "  make runtime-trading      Start trading-app (PHP 8.1 + Node 20)"
	@echo "  make runtime-dist         Start distribution-app (PHP 8.2 + Node 22)"
	@echo "  make down-trading         Stop trading-app runtime"
	@echo "  make down-dist            Stop distribution-app runtime"

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

runtime-trading:
	@$(DEVHUB) runtime trading

runtime-dist:
	@$(DEVHUB) runtime distribution

down-trading:
	@$(DEVHUB) down-runtime trading

down-dist:
	@$(DEVHUB) down-runtime distribution
