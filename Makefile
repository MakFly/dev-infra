.PHONY: help install uninstall up up-async down restart ps logs doctor db-create db-list runtime down-runtime adopt project-list wt-list wt-add wt-rm wt-status test version release

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
	@echo "  make adopt SRC=~/path     One-shot adoption of an existing checkout"
	@echo "  make project-list         List registered projects"
	@echo "  make wt-list PROJECT=x    List project worktrees"
	@echo "  make wt-add PROJECT=x BRANCH=feat/y [BASE=main]  Create a worktree"
	@echo "  make wt-rm PROJECT=x SLUG=feat-y                 Remove a worktree"
	@echo "  make wt-status PROJECT=x  Worktree http/db status"
	@echo "  make test                 Run the bats test suites"
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

adopt:
	@test -n "$(SRC)" || { echo "Usage: make adopt SRC=<path> [NAME=x] [STACK=s]"; exit 1; }
	@$(DEVHUB) project adopt $(SRC) $(if $(NAME),--name $(NAME)) $(if $(STACK),--stack $(STACK))

wt-list:
	@test -n "$(PROJECT)" || { echo "Usage: make wt-list PROJECT=<name>"; exit 1; }
	@$(DEVHUB) wt list $(PROJECT)

wt-add:
	@test -n "$(PROJECT)" || { echo "Usage: make wt-add PROJECT=<name> BRANCH=feat/x [BASE=main]"; exit 1; }
	@test -n "$(BRANCH)" || { echo "Usage: make wt-add PROJECT=<name> BRANCH=feat/x [BASE=main]"; exit 1; }
	@$(DEVHUB) wt add $(PROJECT) $(BRANCH) $(or $(BASE),main)

wt-rm:
	@test -n "$(PROJECT)" || { echo "Usage: make wt-rm PROJECT=<name> SLUG=feat-x"; exit 1; }
	@test -n "$(SLUG)" || { echo "Usage: make wt-rm PROJECT=<name> SLUG=feat-x"; exit 1; }
	@$(DEVHUB) wt rm $(PROJECT) $(SLUG)

wt-status:
	@test -n "$(PROJECT)" || { echo "Usage: make wt-status PROJECT=<name>"; exit 1; }
	@$(DEVHUB) wt status $(PROJECT)

test:
	@bunx bats tests/*.bats

version:
	@$(DEVHUB) version

release:
	@./data/scripts/release.sh $(BUMP)
