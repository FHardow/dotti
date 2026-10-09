# Single source of truth for desktop colors.
# Edit here, then run `make theme` to regenerate every colors file.
# Hex values without '#'; alphas are 0.0–1.0.

# Base
bg=0e1215          # deepest tone, tinted into glass surfaces
fg=e6e9ef          # primary text
fg_dim=9aa3ad      # secondary text
glass=ffffff       # highlight tone for frosted layers/borders

# Accents
accent=8fd6b5      # mint, primary accent
accent_alt=7fb8e6  # sky, secondary accent
red=ef7a7a
orange=f0a46c
yellow=e9cf7a
green=a3d98f
blue=7fb8e6
purple=c3a3e6
cyan=7fd6d2

# Glass levels
bg_alpha=0.45         # panels: bar, notification center
overlay_alpha=0.85    # popups over apps: launcher, menus
surface_alpha=0.07    # raised elements on glass (pills, inputs)
hover_alpha=0.14      # hovered/selected elements
border_alpha=0.12     # hairline borders
shadow_alpha=0.35

# Windows (Hyprland)
win_opacity_active=0.96
win_opacity_inactive=0.88
