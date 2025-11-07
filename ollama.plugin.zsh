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
# Note: Variables are now handled locally in the _ollama_accept_line widget

# --- Core Functions ---

# Returns the list of installed Ollama models
_ollama_models() {
  ollama list 2>/dev/null | tail -n +2 | awk '{print $1}'
}

# Function to filter out "Thinking..." sections from Ollama output
_ollama_filter_thinking() {
  # Use a simple approach: remove control characters with sed, then filter thinking patterns with awk
  sed 's/\x1b\[[0-9;]*[mGKHJ]//g; s/\x1b\[?[0-9;]*[a-zA-Z]//g; s/\x1b\[[0-9]*[nABCDRST]//g; s/\x1b\[K//g; s/\x1b\[=//g' | \
  # Remove spinner characters
  sed 's/[⠙⠹⠸⠼⠴⠦⠧⠇⠏]//g' | \
  # Remove job control messages (e.g., [2] 2691328)
  sed '/^\[[0-9]\+\] [0-9]\+$/d' | \
  # Remove job completion messages (e.g., [2]  + 2692426 done ...)
  sed '/^\[[0-9]\+\]  \+[0-9]\+ done/d' | \
  # Use awk to filter: keep only lines after "...done thinking." and remove thinking patterns
  awk '
    BEGIN { 
      after_done = 0
      in_thinking = 0
    }
    # If we see "Thinking...", mark that we are in thinking section
    /Thinking\.\.\./ {
      in_thinking = 1
      next
    }
    # If we see "...done thinking.", mark that we are done with thinking
    /\.\.\.done thinking\./ {
      in_thinking = 0
      after_done = 1
      next
    }
    # Skip lines that look like thinking
    in_thinking == 1 || /^[Tt]hinking/ || /^[0-9]+\. / || /^\* / || /^Draft [0-9]/ || /^Identify/ || /^Perform/ || /^Formulate/ || /^Select/ || /^Review/ || /^The user/ || /^This is/ || /^Lets/ || /^Alternative/ || /^Start with/ || /^I will/ || /^No need/ || /^Is/ || /^Is it/ || /^Does it/ || /^The final response/ || /^[A-Z][a-z]+ [a-z]+:/ || /^[A-Z][a-z]+:/ {
      next
    }
    # Print actual response lines
    {
      if (length($0) > 0) {
        print
      }
    }
  '
}

# Function to format Ollama response (remove markdown formatting)
_ollama_format_response() {
  # Remove markdown code blocks first (to avoid conflicts)
  sed 's/```[^`]*```//g' | \
  # Remove markdown bold (**text** -> text)
  sed 's/\*\*\([^*]*\)\*\*/\1/g' | \
  # Remove markdown italic (*text* -> text, but not **text**)
  sed 's/\*\([^*][^*]*\)\*/\1/g' | \
  # Remove markdown inline code
  sed 's/`\([^`]*\)`/\1/g' | \
  # Clean up multiple spaces
  sed 's/  \+/ /g' | \
  # Trim leading/trailing whitespace from each line
  sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
  # Remove empty lines
  sed '/^$/d'
}

# Function to show animated spinner while waiting
_ollama_spinner() {
  local pid=$1
  local spinstr='|/-\'
  local temp
  while ps -p $pid > /dev/null 2>&1; do
    temp=${spinstr#?}
    printf "\r💭 Thinking... %c" "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep 0.1
  done
  printf "\r"
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
  
  # Run ollama and capture output
  local output=$(ollama run "$model" "$prompt" 2>&1)
  
  # Display filtered and formatted response
  echo "$output" | _ollama_filter_thinking | _ollama_format_response
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
  command_to_run=$(ollama run "$model" "Generate a single-line shell command to perform this action: \"$action\". Only output the raw command, with no explanation or markdown formatting like \`\`\`." | _ollama_filter_thinking | _ollama_format_response)
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

# Function to execute a command with error capture
# Usage: otry <command>
otry() {
  if [ "$#" -lt 1 ]; then
    echo "Usage: otry <command>"
    echo "Executes a command and captures error output for analysis"
    return 1
  fi
  
  local command="$*"
  local temp_file=$(mktemp)
  
  echo "🔧 Executing: $command"
  
  # Execute the command, capturing both stdout and stderr
  eval "$command" > "$temp_file" 2>&1
  local exit_code=$?
  
  # Display the output
  cat "$temp_file"
  
  # If there was an error, analyze it
  if [[ $exit_code -ne 0 ]]; then
    local error_output=$(cat "$temp_file")
    
    echo
    read -q "REPLY?🤖 Error detected (exit code $exit_code). Want a solution using $OLLAMA_DEFAULT_MODEL? [y/N] "
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo "🔍 Analyzing command: '$command'..."
      
      # Build a prompt for the AI that includes the exit code, command and error output
      local prompt="The shell command '$command' failed with exit code $exit_code.
      
Error output:
$error_output

Based on this information, explain what went wrong in one short sentence, then provide a single-line shell command to fix it. 

Format your response exactly like this:
EXPLANATION: <your explanation>
COMMAND: <the command>"
      
      # Call Ollama and capture the response
      local response
      response=$(ollama run "$OLLAMA_DEFAULT_MODEL" "$prompt" 2>/dev/null | _ollama_filter_thinking | _ollama_format_response)
      
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
    fi
  fi
  
  # Clean up
  rm -f "$temp_file"
  
  # Return the original exit code
  return $exit_code
}

# --- LOGIC FOR AUTOMATIC ERROR DETECTION ---
# Note: This section is now handled by the _ollama_accept_line widget above

# --- Register Zsh Hooks ---

# Load Zsh's hook system
autoload -U add-zsh-hook

# Override the accept-line widget to capture command output
_ollama_accept_line() {
  # Store the command
  # OLLAMA_LAST_COMMAND="$BUFFER" # This line is removed
  
  # Create a temporary file to capture output
  local temp_file=$(mktemp)
  
  # Execute the command with output capture
  eval "$BUFFER" > "$temp_file" 2>&1
  local exit_code=$?
  
  # Display the output
  cat "$temp_file"
  
  # If there was an error, analyze it
  if [[ $exit_code -ne 0 ]]; then
    local error_output=$(cat "$temp_file")
    
    echo
    read -q "REPLY?🤖 Errore rilevato (codice $exit_code). Vuoi una soluzione usando $OLLAMA_DEFAULT_MODEL? [y/N] "
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo "🔍 Analisi del comando: '$BUFFER'..." # Changed $OLLAMA_LAST_COMMAND to $BUFFER
      
      # Build a prompt for the AI
      local prompt="Ho eseguito questo comando '$BUFFER' ed ho ricevuto questo errore: # Changed $OLLAMA_LAST_COMMAND to $BUFFER

$error_output

Exit code: $exit_code

Quali azioni mi consigli? Spiega il problema in modo conciso e fornisci un comando per risolverlo."
      
      # Call Ollama and capture the response
      local response
      response=$(ollama run "$OLLAMA_DEFAULT_MODEL" "$prompt" 2>/dev/null | _ollama_filter_thinking | _ollama_format_response)
      
      echo -e "\n---"
      echo "💡 Suggerimento:"
      echo "$response"
      
      # Try to extract a command from the response
      local command_to_run=""
      
      # Try multiple patterns to extract a command
      # Pattern 1: Look for code blocks with bash
      command_to_run=$(echo "$response" | grep -A 1 "```bash" | grep -v "```bash" | grep -v "```" | head -1 | sed 's/^[[:space:]]*//')
      
      # Pattern 2: Look for any code block
      if [[ -z "$command_to_run" ]]; then
        command_to_run=$(echo "$response" | grep -E '```[^`]*```' | sed 's/```//g' | head -1 | sed 's/^[[:space:]]*//')
      fi
      
      # Pattern 3: Look for commands in quotes
      if [[ -z "$command_to_run" ]]; then
        command_to_run=$(echo "$response" | grep -E '(`[^`]+`|"[^"]+"|'"'"'[^'"'"']+'"'"')' | head -1 | sed 's/^[^`"'\'']*[`"'\'']\([^`"'\'']*\)[`"'\''].*$/\1/')
      fi
      
      # Pattern 4: Look for lines that start with common command prefixes
      if [[ -z "$command_to_run" ]]; then
        command_to_run=$(echo "$response" | grep -E '^(rm |git |gh |cd |ls |mkdir |cp |mv |sudo |npm |pip |docker |kubectl )' | head -1 | sed 's/^[[:space:]]*//')
      fi
      
      if [[ -n "$command_to_run" ]]; then
        echo -e "\n🔧 Comando suggerito:"
        echo -e "\033[1;32m$command_to_run\033[0m"
        read -q "REPLY2?Eseguire questo comando? [y/N] "
        echo
        if [[ $REPLY2 =~ ^[Yy]$ ]]; then
          echo "🚀 Esecuzione in corso..."
          eval "$command_to_run"
        else
          echo "Esecuzione annullata."
        fi
      else
        echo -e "\n❌ Impossibile estrarre un comando dalla risposta."
        echo "Puoi provare a eseguire manualmente uno dei comandi suggeriti sopra."
      fi
    fi
  fi
  
  # Clean up
  rm -f "$temp_file"
  
  # Reset the buffer
  BUFFER=""
}

# Create a new widget that uses our function
zle -N _ollama_accept_line

# Bind it to Enter key
bindkey '^M' _ollama_accept_line


# --- Tab Completion ---
# _ochat_odo_completion() {
#   local -a models
#   models=($( _ollama_models ))
#   _describe 'ollama models' models
# }
# compdef _ochat_odo_completion ochat
# compdef _ochat_odo_completion odo