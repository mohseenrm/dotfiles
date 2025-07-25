export EDITOR="nvim"
export AIDER_EDITOR="nvim"
export OLLAMA_API_BASE=http://127.0.0.1:11434
export MANPAGER="nvim +Man!"

export EZA_CONFIG_DIR="$HOME/.config/eza"
# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"

eval "$(pyenv virtualenv-init -)"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

if [[ $(id -un) == "momo" ]]; then
  export XDG_CONFIG_HOME="$HOME/.config"
  export PATH="$PATH:/usr/local/go/bin"
  # INFO: battery cli tool to maintain battery level
  battery maintain 80
  # battery marinain stop
else
  # Work computer
  export OWL="$HOME/Projects/owl"
  eval "$("$OWL/bin/owl" init -)"
  function aws-login() {  eval $( $OWL/bin/owl aws-login $@ ) ; };

  function aws-ec2() {
    LINES=${LINES} COLUMNS=${COLUMNS} ${OWL}/command/pellets/ec2/scripts/login-wrapper "${@}"
  };

  # sdkman
  export SDKMAN_DIR="$HOME/.sdkman"
  [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

  # pnpm
  export PNPM_HOME="/Users/mmukaddam/Library/pnpm"
  case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PNPM_HOME:$PATH" ;;
  esac
  # pnpm end

  uuid=$(openssl rand -hex 16)
  id=$(echo "${uuid:0:8}${uuid:8:4}${uuid:12:4}${uuid:16:4}${uuid:20:12}")
  # postgresql
  export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"
  alias cf="owl tubes render stargate console console-funnel identity -x console-funnel --stage"
  alias mc="owl tubes render stargate console messaging-monkey-backend messaging-console --stage"
  alias email="echo \"mmukaddam+$id@twilio.com\" ; echo \"mmukaddam+$id@twilio.com\" | pbcopy"
fi

# Mac OS
if [[ $(uname) == "Darwin" ]]; then
  export PATH="$HOME/.local/bin:$PATH"

  # zsh-syntax-highlighting
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

  # zsh-autosuggestions
  source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  alias aq="asciiquarium"
  alias update="brew update && brew upgrade"
# Ubuntu
else
  alias update="sudo apt update; sudo apt upgrade -y"
  source ~/antigen.zsh
  # zsh-syntax-highlighting
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  # zsh-autosuggestions
  antigen bundle zsh-users/zsh-autosuggestions
  antigen apply

  [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
fi

# starship
eval "$(starship init zsh)"
# Zoxide
eval "$(zoxide init --cmd cd zsh)"

# History in cache directory:
mkdir -p ~/.cache/zsh
HISTFILE=~/.cache/zsh/history
HISTSIZE=10000000
SAVEHIST=10000000
setopt APPEND_HISTORY             # Write to history
setopt HIST_EXPIRE_DUPS_FIRST     # Expire duplicate entries first when trimming history.
setopt HIST_FIND_NO_DUPS          # Do not display a line previously found.
setopt HIST_IGNORE_ALL_DUPS       # Delete old recorded entry if new entry is a duplicate.
setopt HIST_IGNORE_DUPS           # Don't record an entry that was just recorded again.
setopt HIST_IGNORE_SPACE          # Don't record an entry starting with a space.
setopt HIST_NO_STORE              # Don't store history commands
setopt HIST_REDUCE_BLANKS         # Remove superfluous blanks before recording entry.
setopt HIST_SAVE_NO_DUPS          # Older duplicates are omitted.
setopt INC_APPEND_HISTORY         # Write to the history file immediately, not when the shell exits.
setopt SHARE_HISTORY              # Share history between all sessions.
SHELL_SESSION_HISTORY=0           # Disable pert-terminal-session

zmodload -i zsh/complist

# zsh vi mode
bindkey -v
export KEYTIMEOUT=1

bindkey '^r' history-incremental-search-backward
bindkey '^R' history-incremental-search-backward
# Edit line in vim buffer ctrl-v
autoload edit-command-line; zle -N edit-command-line
bindkey '^v' edit-command-line
# Enter vim buffer from normal mode
autoload -U edit-command-line && zle -N edit-command-line && bindkey -M vicmd "^v" edit-command-line

# Use vim keys in tab complete menu:
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'left' vi-backward-char
bindkey -M menuselect 'down' vi-down-line-or-history
bindkey -M menuselect 'up' vi-up-line-or-history
bindkey -M menuselect 'right' vi-forward-char

# Fix backspace bug when switching modes
bindkey "^?" backward-delete-char

# Change cursor shape for different vi modes.
function zle-keymap-select {
  if [[ ${KEYMAP} == vicmd ]] ||
     [[ $1 = 'block' ]]; then
    echo -ne '\e[1 q'
  elif [[ ${KEYMAP} == main ]] ||
       [[ ${KEYMAP} == viins ]] ||
       [[ ${KEYMAP} = '' ]] ||
       [[ $1 = 'beam' ]]; then
    echo -ne '\e[5 q'
  fi
}
zle -N zle-keymap-select

# ci", ci', ci`, di", etc
autoload -U select-quoted
zle -N select-quoted
for m in visual viopp; do
  for c in {a,i}{\',\",\`}; do
    bindkey -M $m $c select-quoted
  done
done

# ci{, ci(, ci<, di{, etc
autoload -U select-bracketed
zle -N select-bracketed
for m in visual viopp; do
  for c in {a,i}${(s..)^:-'()[]{}<>bB'}; do
    bindkey -M $m $c select-bracketed
  done
done

zle-line-init() {
    zle -K viins # initiate `vi insert` as keymap (can be removed if `bindkey -V` has been set elsewhere)
    echo -ne "\e[5 q"
}
zle -N zle-line-init

echo -ne '\e[5 q' # Use beam shape cursor on startup.
precmd() { echo -ne '\e[5 q' ;} # Use beam shape cursor for each new prompt.

# eza
alias ls="eza --long --all --icons=\"always\" --show-symlinks"
alias tree="eza --tree --all --icons=\"always\" --show-symlinks"
# bat
alias cat="bat --style=plain"
# AI Reasoning model
# alias air="aider --model ollama_chat/deepseek-r1:70b --config $HOME/aider.conf.yaml"
alias air="aider --model anthropic/claude-3-7-sonnet-20250219 --config $HOME/aider.conf.yaml"
# AI Coding model
alias aic="aider --model ollama_chat/deepseek-coder-v2 --config $HOME/aider.conf.yaml"
# Claude Code
alias cc="claude"
# Weather
alias weather="curl wttr.in/Seattle%2C+WA+98103"

# fzf
source <(fzf --zsh)
# fzf theme
export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS \
  --highlight-line \
  --info=inline-right \
  --ansi \
  --layout=reverse \
  --border=none
  --color=bg+:#283457 \
  --color=bg:#16161e \
  --color=border:#27a1b9 \
  --color=fg:#c0caf5 \
  --color=gutter:#16161e \
  --color=header:#ff9e64 \
  --color=hl+:#2ac3de \
  --color=hl:#2ac3de \
  --color=info:#545c7e \
  --color=marker:#ff007c \
  --color=pointer:#ff007c \
  --color=prompt:#2ac3de \
  --color=query:#c0caf5:regular \
  --color=scrollbar:#27a1b9 \
  --color=separator:#ff9e64 \
  --color=spinner:#ff007c \
"

# Start fastfetch
lolcat ~/.config/nvim/logo/fastfetch.txt | lolcat -p 1 --force | fastfetch --raw - --logo-width 55
