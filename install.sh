#!/bin/bash

#=====================================================================================
# Oh-My-Zsh Ollama Plugin Installer
# This script installs the oh-my-zsh-ollama-plugin and configures it.
#=====================================================================================

# --- Configuration ---
# Replace with your repository URL
REPO_URL="https://github.com/fabiocantone/oh-my-zsh-ollama-plugin.git"
PLUGIN_NAME="ollama"

# --- Colors for output ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Helper functions ---

# Print an error message and exit
error_exit() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

# Print a success message
success() {
    echo -e "${GREEN}$1${NC}"
}

# Print an info message
info() {
    echo -e "${YELLOW}$1${NC}"
}

# --- Installation Start ---

echo "=========================================="
echo "  Oh-My-Zsh Ollama Plugin Installer"
echo "=========================================="

# 1. Check prerequisites
info "Checking prerequisites..."
command -v zsh >/dev/null 2>&1 || error_exit "Zsh is not installed. Please install it first."
command -v git >/dev/null 2>&1 || error_exit "Git is not installed. Please install it first."
command -v ollama >/dev/null 2>&1 || error_exit "Ollama is not installed. Please install it from https://ollama.com."

# Check if Ollama is running
if ! ollama list >/dev/null 2>&1; then
    error_exit "Ollama doesn't seem to be running. Start it with 'ollama serve' and try again."
fi
success "Prerequisites verified."

# 2. Get the list of Ollama models
info "Retrieving list of available Ollama models..."
MODELS=($(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}'))

if [ ${#MODELS[@]} -eq 0 ]; then
    error_exit "No Ollama models found. Please download at least one model (e.g. 'ollama pull llama3')."
fi

# 3. Interactive model selection
echo "Select the default model to use:"
for i in "${!MODELS[@]}"; do
    echo "$((i+1))) ${MODELS[i]}"
done

# Always use the first model as default when piped
SELECTED_MODEL="${MODELS[0]}"
echo "Using default model: $SELECTED_MODEL"
echo "To select a different model, run: export OLLAMA_DEFAULT_MODEL=\"your-model-name\""

# 4. Define paths
ZSHRC_FILE="$HOME/.zshrc"
OH_MY_ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
PLUGIN_DIR="$OH_MY_ZSH_CUSTOM_DIR/plugins/$PLUGIN_NAME"

# 5. Install/Update plugin
info "Installing plugin to $PLUGIN_DIR..."
if [ -d "$PLUGIN_DIR" ]; then
    info "Existing plugin directory found. Removing..."
    rm -rf "$PLUGIN_DIR"
fi

git clone -q "$REPO_URL" "$PLUGIN_DIR" || error_exit "Failed to clone plugin repository."
success "Plugin cloned successfully."

# 6. Add plugin to .zshrc
info "Updating .zshrc file..."

# Add 'ollama' to plugins list if not already present
if grep -q "plugins=(.*$PLUGIN_NAME" "$ZSHRC_FILE"; then
    info "Plugin '$PLUGIN_NAME' is already present in .zshrc."
else
    # Extract the current plugins line
    PLUGINS_LINE=$(grep "^plugins=(" "$ZSHRC_FILE")
    
    if [ -n "$PLUGINS_LINE" ]; then
        # Get the content inside parentheses
        PLUGINS_CONTENT=$(echo "$PLUGINS_LINE" | sed 's/plugins=(//' | sed 's/)//')
        
        # Add our plugin to the beginning
        NEW_PLUGINS_CONTENT="$PLUGIN_NAME $PLUGINS_CONTENT"
        
        # Replace the line with the updated plugins list
        sed -i.bak "s/^plugins=(.*/plugins=($NEW_PLUGINS_CONTENT)/" "$ZSHRC_FILE"
        success "Plugin '$PLUGIN_NAME' added to plugins list in .zshrc."
    else
        # If no plugins line found, add one
        echo "plugins=($PLUGIN_NAME)" >> "$ZSHRC_FILE"
        success "Plugin '$PLUGIN_NAME' added to .zshrc."
    fi
fi

# Add environment variable if not already present
if grep -q "export OLLAMA_DEFAULT_MODEL" "$ZSHRC_FILE"; then
    # If it exists, update it
    sed -i.bak "s/export OLLAMA_DEFAULT_MODEL=.*/export OLLAMA_DEFAULT_MODEL=\"$SELECTED_MODEL\"/" "$ZSHRC_FILE"
    info "OLLAMA_DEFAULT_MODEL variable updated in .zshrc."
else
    # Otherwise, add it at the end of the file
    echo "" >> "$ZSHRC_FILE"
    echo "# Ollama Plugin Default Model" >> "$ZSHRC_FILE"
    echo "export OLLAMA_DEFAULT_MODEL=\"$SELECTED_MODEL\"" >> "$ZSHRC_FILE"
    success "OLLAMA_DEFAULT_MODEL variable set in .zshrc."
fi

# Remove the backup file created by sed
rm -f "$ZSHRC_FILE.bak"

# 7. Reload configuration
if [ -n "$ZSH_VERSION" ]; then
    info "Reloading Zsh configuration..."
    source "$ZSHRC_FILE"
else
    info "Skipping Zsh configuration reload (not running in Zsh)."
    info "Please restart your terminal or run 'source ~/.zshrc' to apply changes."
fi

echo "=========================================="
success "Installation completed successfully!"
echo "=========================================="
echo "The '$PLUGIN_NAME' plugin is now active and the default model is set to '$SELECTED_MODEL'."
echo "Open a new terminal window to ensure all changes are applied correctly."