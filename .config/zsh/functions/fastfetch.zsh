# Fastfetch function for zellij compatibility
# This function temporarily unsets zellij environment variables to allow image logos

fastfetch() {
    # Store original zellij environment variables
    local orig_zellij="$ZELLIJ"
    local orig_pane_id="$ZELLIJ_PANE_ID"
    local orig_session="$ZELLIJ_SESSION_NAME"
    
    # Temporarily unset zellij variables to bypass terminal multiplexer detection
    unset ZELLIJ ZELLIJ_PANE_ID ZELLIJ_SESSION_NAME
    
    # Run fastfetch with all passed arguments
    "$HOME/dotfiles/bin/fastfetch" "$@"
    
    # Restore original environment variables
    [[ -n "$orig_zellij" ]] && export ZELLIJ="$orig_zellij"
    [[ -n "$orig_pane_id" ]] && export ZELLIJ_PANE_ID="$orig_pane_id"
    [[ -n "$orig_session" ]] && export ZELLIJ_SESSION_NAME="$orig_session"
}

# Alias for convenience
alias ff='fastfetch --config "$HOME/dotfiles/.config/fastfetch/config.jsonc"'