# Stow this repo as a single package into $HOME.
DOTFILES := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
STOW_DIR := $(patsubst %/,%,$(dir $(DOTFILES)))
PACKAGE  := $(notdir $(DOTFILES))
TARGET   ?= $(HOME)
STOW     := stow -v -d $(STOW_DIR) -t $(TARGET)
PACKAGES := stow swaync hyprpaper hyprlock brightnessctl networkmanager bluetui wlsunset btop nvtop

.PHONY: help deps check install restow uninstall adopt

help: ## Show available targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

deps: ## Install required packages (Arch)
	sudo pacman -S --needed $(PACKAGES)

check: ## Dry run: show what would be linked and any conflicts
	$(STOW) -n $(PACKAGE)

install: ## Symlink dotfiles into ~
	$(STOW) $(PACKAGE)
	-pkill -x waybar
	setsid -f waybar >/dev/null 2>&1

restow: ## Re-link (prune stale links, add new files)
	$(STOW) -R $(PACKAGE)

uninstall: ## Remove symlinks from ~
	$(STOW) -D $(PACKAGE)

adopt: ## Move existing files from ~ into repo, then link (review with git diff!)
	$(STOW) --adopt $(PACKAGE)
	@git -C $(DOTFILES) status --short

theme: ## Render colors from theme/palette.sh into app configs
	@$(DOTFILES)/theme/render.sh
