#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print message with color
print_message() {
  echo -e "${GREEN}==>${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}==>${NC} $1"
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Install core dependencies based on OS
install_core_dependencies() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    print_message "Installing core dependencies for macOS..."
    
    # Check if Homebrew is installed
    if ! command_exists brew; then
      print_message "Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
      print_message "Homebrew already installed, updating..."
      brew update
    fi
    
    # Install GNU stow
    if ! command_exists stow; then
      print_message "Installing GNU stow..."
      brew install stow
    fi
    
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    print_message "Installing core dependencies for Ubuntu..."
    
    # Update package lists
    print_message "Updating package lists..."
    sudo apt update
    
    # Install GNU stow
    if ! command_exists stow; then
      print_message "Installing GNU stow..."
      sudo apt install -y stow
    fi
  else
    print_warning "Unsupported OS: $OSTYPE"
    exit 1
  fi
}

# Install common tools for both macOS and Ubuntu
install_common_tools() {
  print_message "Installing common tools..."
  
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS installations using Homebrew
    
    # Terminal utilities
    print_message "Installing terminal utilities..."
    brew install nvim starship zoxide fzf eza bat fastfetch lolcat git
    brew install zsh-syntax-highlighting zsh-autosuggestions
    
    # Programming environments
    if ! command_exists pyenv; then
      print_message "Installing pyenv..."
      brew install pyenv pyenv-virtualenv
    fi
    
    # NVM for Node.js
    if [ ! -d "$HOME/.nvm" ]; then
      print_message "Installing nvm..."
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
    fi
    
    # AI tools
    print_message "Installing AI tools..."
    brew install ollama
    pip install aider-chat
    pip install claude-cli
    
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Ubuntu installations
    
    # Install build essentials and other dependencies
    print_message "Installing build essentials and dependencies..."
    sudo apt install -y build-essential curl wget git zsh
    
    # Install Neovim
    if ! command_exists nvim; then
      print_message "Installing Neovim..."
      sudo apt install -y neovim
    fi
    
    # Install Starship prompt
    if ! command_exists starship; then
      print_message "Installing Starship prompt..."
      curl -sS https://starship.rs/install.sh | sh
    fi
    
    # Install Zoxide
    if ! command_exists zoxide; then
      print_message "Installing Zoxide..."
      curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
    fi
    
    # Install FZF
    if [ ! -d "$HOME/.fzf" ]; then
      print_message "Installing FZF..."
      git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
      ~/.fzf/install --all
    fi
    
    # Install eza (modern ls replacement)
    if ! command_exists eza; then
      print_message "Installing eza..."
      sudo apt install -y eza || {
        # If not available in repositories, try cargo install
        if ! command_exists cargo; then
          print_message "Installing Rust for eza..."
          curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
          source "$HOME/.cargo/env"
        fi
        cargo install eza
      }
    fi
    
    # Install bat
    if ! command_exists bat; then
      print_message "Installing bat..."
      sudo apt install -y bat || sudo apt install -y batcat
    fi
    
    # Install fastfetch
    if ! command_exists fastfetch; then
      print_message "Installing fastfetch..."
      sudo apt install -y fastfetch || {
        print_warning "fastfetch not available in repositories, skipping..."
      }
    fi
    
    # Install lolcat
    if ! command_exists lolcat; then
      print_message "Installing lolcat..."
      sudo apt install -y lolcat || sudo gem install lolcat
    fi
    
    # Install ZSH plugins
    print_message "Installing ZSH plugins..."
    sudo apt install -y zsh-syntax-highlighting zsh-autosuggestions
    
    # Antigen
    if [ ! -f "$HOME/antigen.zsh" ]; then
      print_message "Installing Antigen..."
      curl -L git.io/antigen > ~/antigen.zsh
    fi
    
    # Pyenv
    if ! command_exists pyenv; then
      print_message "Installing pyenv..."
      curl https://pyenv.run | bash
    fi
    
    # NVM
    if [ ! -d "$HOME/.nvm" ]; then
      print_message "Installing nvm..."
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
    fi
    
    # AI tools
    print_message "Installing AI tools..."
    curl https://ollama.ai/install.sh | sh
    pip install aider-chat
    pip install claude-cli
  fi
}

# Install macOS specific tools
install_macos_tools() {
  if [[ "$OSTYPE" != "darwin"* ]]; then
    return
  fi
  
  print_message "Installing macOS specific tools..."
  
  # PostgreSQL
  brew install postgresql@16
  
  # Asciiquarium
  brew install asciiquarium
  
  # SDKMAN
  if [ ! -d "$HOME/.sdkman" ]; then
    print_message "Installing SDKMAN..."
    curl -s "https://get.sdkman.io" | bash
  fi
}

# Install Ubuntu specific tools
install_ubuntu_tools() {
  if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    return
  fi
  
  print_message "Installing Ubuntu specific tools..."
  # Add any Ubuntu-specific tools here
}

# Create necessary config directories
create_config_dirs() {
  print_message "Creating config directories..."
  
  mkdir -p "$HOME/.config/nvim/logo"
  mkdir -p "$HOME/.config/eza"
  mkdir -p "$HOME/.config/bat/themes"
  mkdir -p "$HOME/.cache/zsh"
}

# Setup dotfiles with stow
setup_dotfiles() {
  print_message "Setting up dotfiles with stow..."
  
  # Check if we're in the dotfiles directory
  if [ ! -f "$(pwd)/README.md" ] || ! grep -q "Dot files" "$(pwd)/README.md"; then
    print_warning "Please run this script from the dotfiles directory"
    exit 1
  fi
  
  # Backup existing configs
  if [ -f "$HOME/.zshrc" ]; then
    print_message "Backing up existing .zshrc..."
    mv "$HOME/.zshrc" "$HOME/.zshrc.backup"
  fi
  
  # Create symlinks with stow
  print_message "Creating symlinks with stow..."
  stow .
  
  print_message "Dotfiles installation complete!"
  print_message "Please log out and log back in or run 'source ~/.zshrc' to apply changes."
}

# Main function
main() {
  print_message "Starting dotfiles setup..."
  
  install_core_dependencies
  install_common_tools
  
  if [[ "$OSTYPE" == "darwin"* ]]; then
    install_macos_tools
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    install_ubuntu_tools
  fi
  
  create_config_dirs
  setup_dotfiles
  
  print_message "Setup complete! 🎉"
}

# Run the script
main