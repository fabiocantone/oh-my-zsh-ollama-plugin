#!/bin/bash

#=====================================================================================
# Oh-My-Zsh Ollama Plugin Installer
# This script installs the oh-my-zsh-ollama-plugin and configures it.
#=====================================================================================

# --- Configurazione ---
# Sostituisci con il tuo repository URL
REPO_URL="https://github.com/fabiocantone/oh-my-zsh-ollama-plugin.git"
PLUGIN_NAME="ollama"

# --- Colori per l'output ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Funzioni di supporto ---

# Stampa un messaggio di errore ed esce
error_exit() {
    echo -e "${RED}ERRORE: $1${NC}" >&2
    exit 1
}

# Stampa un messaggio di successo
success() {
    echo -e "${GREEN}$1${NC}"
}

# Stampa un messaggio informativo
info() {
    echo -e "${YELLOW}$1${NC}"
}

# --- Inizio Installazione ---

echo "=========================================="
echo "  Oh-My-Zsh Ollama Plugin Installer"
echo "=========================================="

# 1. Verifica dei prerequisiti
info "Verifica dei prerequisiti..."
command -v zsh >/dev/null 2>&1 || error_exit "Zsh non è installato. Per favore, installalo prima."
command -v git >/dev/null 2>&1 || error_exit "Git non è installato. Per favore, installarlo prima."
command -v ollama >/dev/null 2>&1 || error_exit "Ollama non è installato. Per favore, installalo da https://ollama.com."

# Verifica se Ollama è in esecuzione
if ! ollama list >/dev/null 2>&1; then
    error_exit "Ollama non sembra essere in esecuzione. Avvialo con 'ollama serve' e riprova."
fi
success "Prerequisiti verificati."

# 2. Ottenere la lista dei modelli Ollama
info "Recupero della lista dei modelli Ollama disponibili..."
MODELS=($(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}'))

if [ ${#MODELS[@]} -eq 0 ]; then
    error_exit "Nessun modello Ollama trovato. Per favore, scarica almeno un modello (es. 'ollama pull llama3')."
fi

# 3. Selezione interattiva del modello
echo "Seleziona il modello di default da usare:"
PS3="Inserisci il numero del modello: "
select SELECTED_MODEL in "${MODELS[@]}"; do
    if [[ -n "$SELECTED_MODEL" ]]; then
        success "Modello selezionato: $SELECTED_MODEL"
        break
    else
        echo "Scelta non valida. Riprova."
    fi
done

# 4. Definizione dei percorsi
ZSHRC_FILE="$HOME/.zshrc"
OH_MY_ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
PLUGIN_DIR="$OH_MY_ZSH_CUSTOM_DIR/plugins/$PLUGIN_NAME"

# 5. Installazione/Aggiornamento del plugin
info "Installazione del plugin in $PLUGIN_DIR..."
if [ -d "$PLUGIN_DIR" ]; then
    info "Directory del plugin esistente. Rimozione in corso..."
    rm -rf "$PLUGIN_DIR"
fi

git clone -q "$REPO_URL" "$PLUGIN_DIR" || error_exit "Impossibile clonare il repository del plugin."
success "Plugin clonato con successo."

# 6. Aggiunta del plugin a .zshrc
info "Aggiornamento del file .zshrc..."

# Aggiunge 'ollama' alla lista dei plugin se non è già presente
if grep -q "plugins=(.*$PLUGIN_NAME" "$ZSHRC_FILE"; then
    info "Plugin '$PLUGIN_NAME' è già presente in .zshrc."
else
    # Usa sed per aggiungere il plugin alla lista plugins=(...)
    # Questo comando è robusto e gestisce spazi e parentesi
    sed -i.bak "s/^plugins=(/plugins=($PLUGIN_NAME /" "$ZSHRC_FILE" && \
    sed -i.bak "s/^plugins=($PLUGIN_NAME /&)/" "$ZSHRC_FILE"
    success "Plugin '$PLUGIN_NAME' aggiunto alla lista dei plugin in .zshrc."
fi

# Aggiunge la variabile d'ambiente se non è già presente
if grep -q "export OLLAMA_DEFAULT_MODEL" "$ZSHRC_FILE"; then
    # Se esiste, la aggiorna
    sed -i.bak "s/export OLLAMA_DEFAULT_MODEL=.*/export OLLAMA_DEFAULT_MODEL=\"$SELECTED_MODEL\"/" "$ZSHRC_FILE"
    info "Variabile OLLAMA_DEFAULT_MODEL aggiornata in .zshrc."
else
    # Altrimenti, la aggiunge in fondo al file
    echo "" >> "$ZSHRC_FILE"
    echo "# Ollama Plugin Default Model" >> "$ZSHRC_FILE"
    echo "export OLLAMA_DEFAULT_MODEL=\"$SELECTED_MODEL\"" >> "$ZSHRC_FILE"
    success "Variabile OLLAMA_DEFAULT_MODEL impostata in .zshrc."
fi

# Rimuove il file di backup creato da sed
rm -f "$ZSHRC_FILE.bak"

# 7. Ricarica la configurazione
info "Ricaricamento della configurazione di Zsh..."
source "$ZSHRC_FILE"

echo "=========================================="
success "Installazione completata con successo!"
echo "=========================================="
echo "Il plugin '$PLUGIN_NAME' è ora attivo e il modello di default è impostato su '$SELECTED_MODEL'."
echo "Apri una nuova finestra del terminale per assicurarti che tutte le modifiche siano applicate correttamente."