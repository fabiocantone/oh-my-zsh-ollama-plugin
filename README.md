# Oh-My-Zsh Ollama Plugin

An intelligent [Oh-My-Zsh](https://ohmyz.sh/) plugin that seamlessly integrates [Ollama](https://ollama.com/) into your command line.

It provides:
- A quick chat function (`ochat`).
- A command generation and execution function (`odo`).
- **Automatic error detection and suggestion of fixes.**

![Demo](https://github.com/TUO_USERNAME/oh-my-zsh-ollama-plugin/assets/YOUR_ID/demo.gif) 
<!-- Add a GIF or screenshot here to make it more appealing! -->

## Prerequisites

- [Zsh](https://www.zsh.org/)
- [Oh-My-Zsh](https://ohmyz.sh/)
- [Ollama](https://ollama.com/) installed and running (`ollama serve`)

## Installation

The easiest way to install this plugin is by running our automatic installer. It will guide you through selecting a default model and will configure everything for you.

### Automatic Installer (Recommended)

Just run this command in your terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/fabiocantone/oh-my-zsh-ollama-plugin/main/install.sh | bash
```

This will use the first available model as default. If you want to specify a particular model, you can pass it as a parameter:

```bash
curl -fsSL https://raw.githubusercontent.com/fabiocantone/oh-my-zsh-ollama-plugin/main/install.sh | bash -s glm-4.6:cloud
```

Replace `glm-4.6:cloud` with the model name of your choice.

After installation, you can always change the default model by editing the `OLLAMA_DEFAULT_MODEL` variable in your `~/.zshrc` file or by running:

```bash
export OLLAMA_DEFAULT_MODEL="your-model-name"
```

### Manual installer

1.  Clone this repository into your custom plugins directory:

    ```bash
    git clone https://github.com/TUO_USERNAME/oh-my-zsh-ollama-plugin.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/ollama
    ```

2.  Enable the plugin by adding `ollama` to the plugins list in your `~/.zshrc` file:

    ```zsh
    plugins=(git ollama)
    ```

3.  Reload your Zsh configuration:

    ```bash
    source ~/.zshrc
    ```

## Usage

### 1. Chat with Ollama (`ochat`)

Ask a question to any of your installed models.

```bash
# Ask llama3 a question
ochat llama3 "Explain quantum computing in simple terms"
```