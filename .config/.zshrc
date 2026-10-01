# Safe to source on top of an existing config (e.g. from ~/.zshrc.d):
# every block below skips itself if something equivalent is already loaded.

[[ -n "${STARSHIP_SHELL:-}" ]] || eval "$(starship init zsh)"

# Monochrome eza
export EZA_COLORS="uu=bright-black:gu=bright-black:da=bright-black:ur=white:uw=bright-black:ux=white:ue=bright-black:gr=bright-black:gw=bright-black:gx=white:tr=bright-black:fi=white:di=bright-white:ln=bright-black:pi=bright-black:so=bright-black:bd=bright-black:cd=bright-black:or=bright-black:mi=bright-black:ex=white"

if ! alias ls >/dev/null 2>&1; then
    alias ls='eza --icons'
    alias ll='eza -lah --icons --git'
    alias la='eza -a --icons'
    alias lt='eza --tree --icons'
fi


# --------------------------------------------------
# Completion
# --------------------------------------------------

if (( ! ${+functions[compdef]} )); then
    autoload -Uz compinit
    compinit
fi

# Better completion menu
zstyle ':completion:*' menu select

# Case-insensitive matching
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Completion colors — grayscale
zstyle ':completion:*' list-colors \
  '=(#b)*(=0)=38;5;250' \
  '=(#b)*(=1)=38;5;255' \
  '=(#b)*(=2)=38;5;245' \
  '=(#b)*(=3)=38;5;240'

# Autosuggestions — dark gray
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'

# --------------------------------------------------
# History
# --------------------------------------------------

# Never shrink a bigger history someone already configured
HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
(( ${HISTSIZE:-0} >= 10000 )) || HISTSIZE=10000
(( ${SAVEHIST:-0} >= 10000 )) || SAVEHIST=10000

setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS

# Plugin paths: Arch uses /usr/share/zsh/plugins/<name>, Fedora /usr/share/<name>
for _p in /usr/share/zsh/plugins/zsh-autosuggestions /usr/share/zsh-autosuggestions; do
    if (( ! ${+functions[_zsh_autosuggest_start]} )) && [[ -r $_p/zsh-autosuggestions.zsh ]]; then
        source $_p/zsh-autosuggestions.zsh
    fi
done

# Syntax highlighting
for _p in /usr/share/zsh/plugins/zsh-syntax-highlighting /usr/share/zsh-syntax-highlighting; do
    if (( ! ${+functions[_zsh_highlight]} )) && [[ -r $_p/zsh-syntax-highlighting.zsh ]]; then
        source $_p/zsh-syntax-highlighting.zsh
    fi
done
unset _p

# Grayscale
ZSH_HIGHLIGHT_STYLES[command]='fg=white'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=white'
ZSH_HIGHLIGHT_STYLES[function]='fg=white'
ZSH_HIGHLIGHT_STYLES[alias]='fg=white'
ZSH_HIGHLIGHT_STYLES[path]='fg=245'
ZSH_HIGHLIGHT_STYLES[comment]='fg=240'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=245'


# 43PR theme controller
theme() { python3 "$HOME/.config/43pr/bin/theme.py" "$@"; }
