# Setup fzf
# ---------
if [[ ! "$PATH" == */home/momo/Projects/fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/home/momo/Projects/fzf/bin"
fi

source <(fzf --zsh)
