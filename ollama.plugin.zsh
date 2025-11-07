#!/usr/bin/env zsh

#=====================================================================================
# Ollama Oh-My-Zsh Plugin
# Author: Your Name
# Repository: https://github.com/TUO_USERNAME/oh-my-zsh-ollama-plugin
# Description: Integrates Ollama for chat, command execution, and automatic error solving.
#=====================================================================================

# --- Configuration ---

# Set the default model to use for automatic error correction.
# You can override this in your .zshrc with: export OLLAMA_DEFAULT_MODEL="codellama"
OLLAMA_DEFAULT_MODEL=${OLLAMA_DEFAULT_MODEL:-"llama3"}

# --- Global Variables for Hooks ---

# Variable to store the last command executed
OLLAMA_LAST_COMMAND=""

# --- Core Functions ---

# Returns the list of installed Ollama models
_ollama_models() {
  ollama list 2>/dev/null | tail -n +2 | awk '{print $1}'
}

# Function for a quick chat with Ollama
# Usage: ochat <model> <question>
ochat() {
  if [ "$#" -lt 1 ]; then
    echo "Usage: ochat [model] <question>"
    echo "If no model is specified, will use OLLAMA_DEFAULT_MODEL"
    return 1
  fi
  
  # Check if first argument is a model or part of the question
  local model="$OLLAMA_DEFAULT_MODEL"
  local prompt="$*"
  
  # If more than 1 argument, assume first is model
  if [ "$#" -gt 1 ]; then
    model="$1"
    shift
    prompt="$*"
  fi
  
  echo "🤖 [$model] $prompt"
  echo "---"
  ollama run "$model" "$prompt" --no-stream
}

# Function to ask Ollama for a command to execute
# WARNING: Use with caution. Always check the command before executing.
# Usage: odo <model> "description of the action"
odo() {
  if [ "$#" -lt 2 ]; then
    echo "Usage: odo <model> \"description of the action\""
    return 1
  fi
  local model="$1"
  local action="$2"
  echo "🤖 [$model] How can I: $action"
  echo "---"
  local command_to_run
  command_to_run=$(ollama run "$model" "Generate a single-line shell command to perform this action: \"$action\". Only output the raw command, with no explanation or markdown formatting like ```." --no-stream
  if [ -z "$command_to_run" ]; then
    echo "❌ Ollama could not generate a command."
    return 1
  fi
  echo -e "\n🔧 Suggested command:\n\033[1;32m$command_to_run\033[0m\n---"
  read -q "REPLY?Execute this command? [y/N] "
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\n🚀 Executing..."
    eval "$command_to_run"
  else
    echo "Execution cancelled."
  fi
}

# --- LOGIC FOR AUTOMATIC ERROR DETECTION ---

# Function that runs BEFORE every command.
# Its only purpose is to save the command that is about to be executed.
_ollama_store_command() {
  OLLAMA_LAST_COMMAND="$1"
}

# Function that runs AFTER every command (thanks to the precmd hook).
# Here we check if there was an error.
_ollama_check_error() {
  local exit_code=$?
  
  # 1. Do nothing if the command was successful (exit code 0).
  # 2. Do nothing if the last command was empty.
  # 3. Do nothing if the last command was one of our plugin commands to avoid loops.
  if [[ $exit_code -eq 0 || -z "$OLLAMA_LAST_COMMAND" || "$OLLAMA_LAST_COMMAND" =~ ^(ochat|odo) ]]; then
    return
  fi

  # Ask the user if they want a solution
  read -q "REPLY?🤖 Error detected (exit code $exit_code). Want a solution using $OLLAMA_DEFAULT_MODEL? [y/N] "
  echo

  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    return
  fi

  echo "🔍 Analyzing command: '$OLLAMA_LAST_COMMAND'..."
  
  # Build a specific prompt for the AI
  local prompt="The shell command '$OLLAMA_LAST_COMMAND' failed with exit code $exit_code. Explain the likely error in one short sentence, then provide a single-line shell command to fix it. Format your response like this:\\nEXPLANATION: <your explanation>\\nCOMMAND: <the command>"
  
  # Call Ollama and capture the response
  local response
  response=$(ollama run "$OLLAMA_DEFAULT_MODEL" "$prompt" 2>/dev/null --no-stream)

  # Extract explanation and command from the response
  local explanation=$(echo "$response" | grep "EXPLANATION:" | sed 's/^EXPLANATION: //')
  local command_to_run=$(echo "$response" | grep "COMMAND:" | sed 's/^COMMAND: //')

  echo -e "\n---"
  echo "💡 Explanation: $explanation"

  if [[ -n "$command_to_run" ]]; then
    echo -e "\n🔧 Suggested command:"
    echo -e "\033[1;32m$command_to_run\033[0m"
    read -q "REPLY2?Execute this command? [y/N] "
    echo
    if [[ $REPLY2 =~ ^[Yy]$ ]]; then
      echo "🚀 Executing..."
      # WARNING: eval is powerful but potentially dangerous.
      # We use it here after two confirmations, but be aware of the risk.
      eval "$command_to_run"
    else
      echo "Execution cancelled."
    fi
  else
    echo "❌ Could not generate a fix command."
  fi
}

# --- Register Zsh Hooks ---

# Load Zsh's hook system
autoload -U add-zsh-hook

# Register our functions to the preexec and precmd hooks
add-zsh-hook preexec _ollama_store_command
add-zsh-hook precmd _ollama_check_error


# --- Tab Completion ---
_ochat_odo_completion() {
  local -a models
  models=($(_ollama_models))
  _describe 'ollama models' models
}
compdef _ochat_odo_completion ochat
compdef _ochat_odo_completion odo