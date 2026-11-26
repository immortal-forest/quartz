# quartz: zsh. Plugins come from zinit (cloned on the first start), the
# prompt from starship (~/.config/starship.toml).

# scripts quartz installs (update-hyprland)
[[ ":$PATH:" == *":$HOME/.local/bin:"* ]] || export PATH="$PATH:$HOME/.local/bin"
export GPG_TTY=$(tty)

# zinit: the plugin manager, downloaded once
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
  mkdir -p "$(dirname $ZINIT_HOME)"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# plain redirections (> < >> |&): a coloured `>` splits the font's ligatures
ZSH_HIGHLIGHT_STYLES[redirection]=none

# completions
autoload -U compinit && compinit
zinit cdreplay -q

# keys
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line

# history
HISTSIZE=5000
HISTFILE=~/.zhistory
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# completion style
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# aliases
alias ls='eza --icons=auto --color=auto'
alias grep='grep --color=auto'
alias launch='hyprctl dispatch exec'

# never beep
setopt NO_BEEP

# fzf (Ctrl+R history, Ctrl+T files), zoxide (cd learns your folders), starship
eval "$(fzf --zsh)"
eval "$(zoxide init --cmd cd zsh)"
eval "$(starship init zsh)"
