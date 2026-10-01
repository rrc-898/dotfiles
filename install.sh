#!/usr/bin/env bash

set -uo pipefail

# 43PR/dotfiles installer
# Arch-compatible Linux or Fedora + Hyprland
#
# Usage:
#   ./install.sh
#
# This script:
#   1. Verifies that the system is Arch-based or Fedora
#   2. Detects the available package manager(s)
#   3. Arch: splits packages.txt into "official repo" vs "AUR-only" and
#      installs each with the right tool, so a single AUR-only or
#      unresolvable name never aborts the whole install.
#      Fedora: enables the Hyprland COPR and installs packages-fedora.txt
#      with dnf, plus the few things Fedora doesn't package (starship,
#      Nerd Fonts, papirus-folders) into ~/.local
#   4. Backs up existing ~/.config
#   5. Installs this repository's configuration
#
# Supported package managers:
#   - pacman       (official repos: Arch, Manjaro, EndeavourOS, CachyOS, etc.)
#   - paru / yay   (AUR helpers, optional but recommended)
#   - dnf          (Fedora; COPR lionheartp/Hyprland for the Hyprland extras)
#
# Privilege escalation defaults to sudo. Set SUDO=pkexec to use the
# graphical polkit prompt instead (e.g. when there is no TTY).

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
BACKUP_ROOT="$HOME/.config-backups"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"
SUDO="${SUDO:-sudo}"

# --------------------------------------------------
# Colors / output
# --------------------------------------------------

info() {
    printf '\n\033[1;34m[INFO]\033[0m %s\n' "$1"
}

success() {
    printf '\n\033[1;32m[DONE]\033[0m %s\n' "$1"
}

warning() {
    printf '\n\033[1;33m[WARN]\033[0m %s\n' "$1"
}

error() {
    printf '\n\033[1;31m[ERROR]\033[0m %s\n' "$1" >&2
}

# --------------------------------------------------
# Checks
# --------------------------------------------------

if [[ "${EUID}" -eq 0 ]]; then
    error "Do not run this script as root."
    exit 1
fi

if [[ ! -f /etc/os-release ]]; then
    error "Cannot determine the operating system."
    exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release

# Arch-compatible distributions normally identify themselves
# through ID_LIKE=arch or ID=arch; Fedora through ID=fedora.
if [[ "${ID:-}" == "arch" || "${ID_LIKE:-}" == *arch* ]]; then
    DISTRO="arch"
elif [[ "${ID:-}" == "fedora" ]]; then
    DISTRO="fedora"
else
    error "This installer is intended for Arch-compatible Linux distributions or Fedora."
    error "Detected: ${PRETTY_NAME:-unknown}"
    exit 1
fi

if ! command -v "${SUDO%% *}" >/dev/null 2>&1; then
    error "$SUDO is required."
    exit 1
fi

if [[ "$DISTRO" == "arch" ]] && ! command -v pacman >/dev/null 2>&1; then
    error "pacman was not found. This installer requires an Arch-based system."
    exit 1
fi

if [[ "$DISTRO" == "fedora" ]] && ! command -v dnf >/dev/null 2>&1; then
    error "dnf was not found."
    exit 1
fi

# --------------------------------------------------
# Package manager detection
# --------------------------------------------------

PACKAGE_FILE="$REPO_DIR/packages.txt"
[[ "$DISTRO" == "fedora" ]] && PACKAGE_FILE="$REPO_DIR/packages-fedora.txt"

if [[ ! -f "$PACKAGE_FILE" ]]; then
    error "$(basename "$PACKAGE_FILE") not found."
    exit 1
fi

AUR_HELPER=""
OFFICIAL_PACKAGES=()
AUR_PACKAGES=()
UNKNOWN_PACKAGES=()

info "Detected distribution: ${PRETTY_NAME:-unknown}"

mapfile -t PACKAGES < <(
    grep -vE '^[[:space:]]*(#|$)' "$PACKAGE_FILE"
)

# --------------------------------------------------
# Fedora: dnf + COPR + things Fedora doesn't package
# --------------------------------------------------

install_nerd_font() {
    # $1 = family name as fc-list reports it, $2 = nerd-fonts release asset
    local family="$1" asset="$2" dir tmp
    # fc-list does the match itself: piping into grep -q would SIGPIPE
    # fc-list and, under pipefail, report "missing" for installed fonts
    if [[ -n "$(fc-list "$family" family)" ]]; then
        info "$family already installed."
        return
    fi
    dir="$HOME/.local/share/fonts/${asset%%.*}NerdFont"
    tmp="$(mktemp -d)"
    info "Installing $family into $dir..."
    if curl -fsSL -o "$tmp/$asset" \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$asset"; then
        mkdir -p "$dir"
        tar -xJf "$tmp/$asset" -C "$dir" --wildcards '*.ttf'
        fc-cache -f "$dir" >/dev/null
        success "$family installed."
    else
        warning "Failed to download $asset."
    fi
    rm -rf "$tmp"
}

if [[ "$DISTRO" == "fedora" ]]; then
    if ! dnf repolist 2>/dev/null | grep -q 'lionheartp:Hyprland'; then
        info "Enabling COPR lionheartp/Hyprland (hyprlock, hyprpolkitagent, awww, cliphist, nwg-look)..."
        $SUDO dnf copr enable -y lionheartp/Hyprland \
            || warning "Could not enable the Hyprland COPR; some packages will fail."
    fi

    if [[ "${#PACKAGES[@]}" -gt 0 ]]; then
        info "Installing packages with dnf..."
        # --skip-unavailable: one missing name never aborts the whole install
        if $SUDO dnf install -y --skip-unavailable "${PACKAGES[@]}"; then
            success "Packages installed."
        else
            warning "dnf reported an error installing one or more packages. Continuing anyway."
        fi
        for pkg in "${PACKAGES[@]}"; do
            rpm -q --whatprovides "$pkg" >/dev/null 2>&1 || UNKNOWN_PACKAGES+=("$pkg")
        done
    fi

    mkdir -p "$HOME/.local/bin"

    if ! command -v starship >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/starship" ]]; then
        info "Installing starship into ~/.local/bin..."
        curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin" >/dev/null \
            && success "starship installed." \
            || warning "Failed to install starship."
    fi

    install_nerd_font "JetBrainsMono Nerd Font" "JetBrainsMono.tar.xz"
    install_nerd_font "Iosevka Nerd Font" "Iosevka.tar.xz"

    if ! command -v papirus-folders >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/papirus-folders" ]]; then
        curl -fsSL -o "$HOME/.local/bin/papirus-folders" \
            https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/papirus-folders \
            && chmod +x "$HOME/.local/bin/papirus-folders" \
            || warning "Failed to download papirus-folders."
    fi

    info "hyprmod is AUR-only and has no Fedora package; skipping it."
fi

if [[ "$DISTRO" == "arch" ]]; then

if command -v paru >/dev/null 2>&1; then
    AUR_HELPER="paru"
elif command -v yay >/dev/null 2>&1; then
    AUR_HELPER="yay"
fi

if [[ -n "$AUR_HELPER" ]]; then
    info "AUR helper available: $AUR_HELPER"
else
    info "No AUR helper found. Bootstrapping yay..."

    if sudo pacman -S --needed --noconfirm git base-devel; then
        YAY_BUILD_DIR="$(mktemp -d)"

        if git clone https://aur.archlinux.org/yay.git "$YAY_BUILD_DIR/yay" \
            && (cd "$YAY_BUILD_DIR/yay" && makepkg -si --noconfirm); then
            AUR_HELPER="yay"
            success "yay installed."
        else
            warning "Failed to build/install yay automatically."
            warning "You can install one manually (paru or yay) and re-run this script."
        fi

        rm -rf "$YAY_BUILD_DIR"
    else
        warning "Failed to install git/base-devel; cannot bootstrap an AUR helper."
        warning "AUR-only packages will be listed but skipped."
    fi
fi

# --------------------------------------------------
# Packages: split into official-repo vs AUR-only
# --------------------------------------------------

if [[ "${#PACKAGES[@]}" -eq 0 ]]; then
    warning "packages.txt does not contain any packages."
else
    info "Resolving packages against official repos..."

    for pkg in "${PACKAGES[@]}"; do
        if pacman -Si "$pkg" >/dev/null 2>&1; then
            OFFICIAL_PACKAGES+=("$pkg")
        elif [[ -n "$AUR_HELPER" ]] && "$AUR_HELPER" -Si "$pkg" >/dev/null 2>&1; then
            AUR_PACKAGES+=("$pkg")
        else
            UNKNOWN_PACKAGES+=("$pkg")
        fi
    done

    if [[ "${#OFFICIAL_PACKAGES[@]}" -gt 0 ]]; then
        info "Installing official-repo packages..."
        if sudo pacman -Syu --needed --noconfirm "${OFFICIAL_PACKAGES[@]}"; then
            success "Official-repo packages installed."
        else
            warning "pacman reported an error installing one or more official-repo packages. Continuing anyway."
        fi
    fi

    if [[ "${#AUR_PACKAGES[@]}" -gt 0 ]]; then
        if [[ -n "$AUR_HELPER" ]]; then
            info "Installing AUR packages with $AUR_HELPER: ${AUR_PACKAGES[*]}"
            if "$AUR_HELPER" -S --needed --noconfirm "${AUR_PACKAGES[@]}"; then
                success "AUR packages installed."
            else
                warning "$AUR_HELPER reported an error installing one or more AUR packages. Continuing anyway."
            fi
        fi
    fi

    if [[ "${#UNKNOWN_PACKAGES[@]}" -gt 0 ]]; then
        warning "Could not resolve the following package(s) in any repo: ${UNKNOWN_PACKAGES[*]}"
        warning "Check the name with 'pacman -Ss <name>' or https://aur.archlinux.org, then fix packages.txt."
    fi
fi

fi # DISTRO == arch

# --------------------------------------------------
# Default shell
# --------------------------------------------------

ZSH_BIN="$(command -v zsh || true)"
if [[ -n "$ZSH_BIN" ]]; then
    if [[ "$(basename "$SHELL")" != "zsh" ]]; then
        info "Setting Zsh as the default shell..."

        if chsh -s "$ZSH_BIN"; then
            success "Default shell changed to Zsh."
            warning "Log out and back in for the shell change to take effect."
        else
            warning "Failed to change the default shell to Zsh."
        fi
    else
        info "Zsh is already the default shell."
    fi
else
    warning "Zsh is not installed; skipping default shell configuration."
fi

# --------------------------------------------------
# Backup existing configuration
# --------------------------------------------------

if [[ -d "$CONFIG_DIR" ]]; then
    info "Backing up existing ~/.config..."

    mkdir -p "$BACKUP_DIR"

    # Only back up directories/files that this repository
    # is going to replace.
    for item in "$REPO_DIR/.config/"*; do
        [[ -e "$item" ]] || continue

        name="$(basename "$item")"

        if [[ -e "$CONFIG_DIR/$name" ]]; then
            cp -a "$CONFIG_DIR/$name" "$BACKUP_DIR/"
        fi
    done

    if [[ -e "$HOME/.zshrc" ]]; then
        mkdir -p "$BACKUP_DIR/home"
        cp -a "$HOME/.zshrc" "$BACKUP_DIR/home/"
    fi

    success "Existing configuration backed up to:"
    printf '  %s\n' "$BACKUP_DIR"
else
    mkdir -p "$CONFIG_DIR"
fi

# --------------------------------------------------
# Install dotfiles
# --------------------------------------------------

info "Installing dotfiles..."

# The repo's spicetify config-xpui.ini carries the author's Spotify paths
# (/opt/spotify, /home/rp34). Keep the local one and only switch the theme.
SPICETIFY_INI="$CONFIG_DIR/spicetify/config-xpui.ini"
SPICETIFY_KEEP=""
if [[ -f "$SPICETIFY_INI" ]]; then
    SPICETIFY_KEEP="$(mktemp)"
    cp -a "$SPICETIFY_INI" "$SPICETIFY_KEEP"
fi

# Install ~/.config files
cp -a "$REPO_DIR/.config/." "$CONFIG_DIR/"
rm -f "$CONFIG_DIR/.zshrc"

if [[ -n "$SPICETIFY_KEEP" ]]; then
    mv "$SPICETIFY_KEEP" "$SPICETIFY_INI"
    sed -i -e 's/^current_theme .*/current_theme          = text/' \
           -e 's/^color_scheme .*/color_scheme           = Monochrome/' "$SPICETIFY_INI"
    info "Kept your spicetify paths; theme set to text/Monochrome (run 'spicetify apply')."
fi

# Install the zsh config. If ~/.zshrc sources ~/.zshrc.d (Fedora-style),
# drop it in there instead of replacing a .zshrc that holds PATH and such.
if [[ -f "$REPO_DIR/.config/.zshrc" ]]; then
    if [[ -d "$HOME/.zshrc.d" ]] && grep -q 'zshrc\.d' "$HOME/.zshrc" 2>/dev/null; then
        cp "$REPO_DIR/.config/.zshrc" "$HOME/.zshrc.d/85-43pr.zsh"
        success "Installed zsh config as ~/.zshrc.d/85-43pr.zsh (your ~/.zshrc is untouched)."
    else
        cp "$REPO_DIR/.config/.zshrc" "$HOME/.zshrc"
        success "Installed .zshrc."
    fi
else
    warning ".zshrc not found; skipping."
fi

success "Dotfiles installed."

# --------------------------------------------------
# Papirus folder color
# --------------------------------------------------

if [[ "$DISTRO" == "fedora" ]]; then
    PF="$(command -v papirus-folders || echo "$HOME/.local/bin/papirus-folders")"
    if [[ -x "$PF" ]]; then
        info "Setting Papirus folder color..."
        if $SUDO "$PF" -C white --theme Papirus-Dark; then
            success "Papirus folders set to white."
        else
            warning "Setting the Papirus folder color failed."
        fi
    else
        warning "papirus-folders not available; skipping folder color."
    fi
elif [[ -n "$AUR_HELPER" ]]; then
    info "Installing Papirus folders..."

    if "$AUR_HELPER" -S --needed --noconfirm papirus-folders; then
        if papirus-folders -C white; then
            success "Papirus folders set to white."
        else
            warning "papirus-folders was installed, but setting the folder color failed."
        fi
    else
        warning "Failed to install papirus-folders."
    fi
else
    warning "No AUR helper available; skipping papirus-folders."
fi

# --------------------------------------------------
# Wallpapers
# --------------------------------------------------

info "Creating user directories..."

if command -v xdg-user-dirs-update >/dev/null 2>&1; then
    xdg-user-dirs-update
fi

PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || true)"
[[ -n "$PICTURES_DIR" && "$PICTURES_DIR" != "$HOME" ]] || PICTURES_DIR="$HOME/Pictures"
WALLPAPER_DIR="$PICTURES_DIR/Wallpapers"
mkdir -p "$WALLPAPER_DIR"

# Point the wallpaper picker at it (stored as $HOME/... like upstream)
PAPER_CFG="$CONFIG_DIR/quickshell/hyprquickpaper/config.json"
if [[ -f "$PAPER_CFG" ]] && command -v jq >/dev/null 2>&1; then
    tmp="$(mktemp)"
    jq --arg p "\$HOME/${WALLPAPER_DIR#"$HOME"/}/" '.wallpaper_path = $p' "$PAPER_CFG" > "$tmp" \
        && mv "$tmp" "$PAPER_CFG"
fi

if [[ -d "$REPO_DIR/Wallpapers" ]]; then
    info "Installing wallpapers..."
    cp -a "$REPO_DIR/Wallpapers/." "$WALLPAPER_DIR/"
    success "Wallpapers installed."
else
    warning "No Wallpapers directory in the repo; created an empty $WALLPAPER_DIR."
fi

# --------------------------------------------------
# Enable user audio services
# --------------------------------------------------

if command -v systemctl >/dev/null 2>&1; then
    info "Enabling PipeWire..."

    systemctl --user enable --now pipewire.service
    systemctl --user enable --now pipewire-pulse.service
    systemctl --user enable --now wireplumber.service

    success "PipeWire configured."
else
    warning "systemctl was not found; skipping PipeWire service setup."
fi

# --------------------------------------------------
# Permissions
# --------------------------------------------------

info "Setting executable permissions on shell scripts..."

find "$CONFIG_DIR" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \;

success "Shell script permissions configured."

# --------------------------------------------------
# Initial theme (generates the files the configs include)
# --------------------------------------------------

if command -v python3 >/dev/null 2>&1; then
    info "Generating initial theme..."
    python3 "$CONFIG_DIR/43pr/bin/theme.py" apply \
        || warning "Initial theme generation failed."
else
    warning "python3 not found; skipping initial theme generation. Configs will use the committed fallback colors until you install python3 and run 'theme apply'."
fi

# --------------------------------------------------
# Dark color scheme (GTK / libadwaita / portals)
# --------------------------------------------------

info "Setting dark color scheme preference..."

gset() {
    if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        gsettings set "$1" "$2" "$3"
    else
        dbus-run-session -- gsettings set "$1" "$2" "$3"
    fi
}

if command -v gsettings >/dev/null 2>&1; then
    gset org.gnome.desktop.interface color-scheme 'prefer-dark' \
        && success "color-scheme set to prefer-dark." \
        || warning "gsettings failed (is dconf installed?)."
    gset org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' || true
    gset org.gnome.desktop.interface icon-theme 'Papirus-Dark' || true
else
    warning "gsettings not found; install glib2 and dconf."
fi

# Fallback that works without a session bus
for v in 3 4; do
    f="$CONFIG_DIR/gtk-$v.0/settings.ini"
    mkdir -p "$(dirname "$f")"
    [[ -f "$f" ]] || printf '[Settings]\n' > "$f"
    if grep -q '^gtk-application-prefer-dark-theme' "$f"; then
        sed -i 's/^gtk-application-prefer-dark-theme.*/gtk-application-prefer-dark-theme=1/' "$f"
    else
        printf 'gtk-application-prefer-dark-theme=1\n' >> "$f"
    fi
done

# --------------------------------------------------
# Finish
# --------------------------------------------------

printf '\n'
printf '\033[1;32m========================================\033[0m\n'
printf '\033[1;32m       43PR Hyprland Setup Ready       \033[0m\n'
printf '\033[1;32m========================================\033[0m\n'
printf '\n'

printf 'Distribution:  %s\n' "${PRETTY_NAME:-unknown}"
if [[ "$DISTRO" == "arch" ]]; then
    printf 'AUR helper:    %s\n' "${AUR_HELPER:-none}"
fi
printf 'Configuration: %s\n' "$CONFIG_DIR"

if [[ -d "$BACKUP_DIR" ]]; then
    printf 'Backup:        %s\n' "$BACKUP_DIR"
fi

if [[ "${#UNKNOWN_PACKAGES[@]}" -gt 0 ]]; then
    printf '\n'
    warning "Unresolved packages (install manually): ${UNKNOWN_PACKAGES[*]}"
fi

printf '\n'
warning "Log out and back into Hyprland for the changes to fully take effect."

printf '\n'
info "You can start Hyprland with:"
printf '  Hyprland\n'

printf '\n'
success "Installation complete!"
