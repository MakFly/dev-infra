.PHONY: help install uninstall up up-async up-local down restart ps logs doctor db-create db-list runtime-trading runtime-dist down-trading down-dist

DEVHUB := ./bin/devhub

help:
	@echo "Targets:"
	@echo "  make install              Install devhub globally (symlink + zsh aliases)"
	@echo "  make up                   Start core+storage"
	@echo "  make up-async            Start core+storage+async"
	@echo "  make up-local             Start core+storage+php85+node24"
	@echo "  make down                 Stop all"
	@echo "  make ps                   Show status"
	@echo "  make doctor               Health/network/ports"
	@echo "  make runtime-trading      Start trading app override"
	@echo "  make runtime-dist         Start distribution app override"
	@echo "  make down-trading         Stop trading-app runtime"
	@echo "  make down-dist            Stop distribution-app runtime"

install:
	@./data/scripts/install.sh

uninstall:
	@./data/scripts/uninstall.sh

up:
	@$(DEVHUB) up

up-async:
	@$(DEVHUB) up --with async

up-local:
	@$(DEVHUB) up --with php85,node24

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
