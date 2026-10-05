# Stow this repo as a single package into $HOME.
DOTFILES := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
STOW_DIR := $(patsubst %/,%,$(dir $(DOTFILES)))
PACKAGE  := $(notdir $(DOTFILES))
TARGET   ?= $(HOME)
STOW     := stow -v -d $(STOW_DIR) -t $(TARGET)

.PHONY: help check install restow uninstall adopt theme

help: ## Show available targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

check: ## Dry run: show what would be linked and any conflicts
	$(STOW) -n $(PACKAGE)

install: ## Symlink dotfiles into ~
	$(STOW) $(PACKAGE)

restow: ## Re-link (prune stale links, add new files)
	$(STOW) -R $(PACKAGE)

uninstall: ## Remove symlinks from ~
	$(STOW) -D $(PACKAGE)

adopt: ## Move existing files from ~ into repo, then link (review with git diff!)
	$(STOW) --adopt $(PACKAGE)
	@git -C $(DOTFILES) status --short

theme: ## Render colors from theme/palette.sh into app configs
	@$(DOTFILES)/theme/render.sh
