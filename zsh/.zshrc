# --- 1. HISTÓRICO ---
# Essencial para produtividade: histórico gigante e compartilhado entre abas
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY         # Compartilha histórico entre instâncias do terminal
setopt HIST_IGNORE_ALL_DUPS  # Não salva comandos repetidos
setopt HIST_REDUCE_BLANKS    # Remove espaços extras

# --- 2. PLUGINS (Instalados via pacman) ---
# Syntax highlighting: Comando verde (existe) ou vermelho (erro)
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# Autosuggestions: Sugere comandos do histórico em cinza (Seta Direita aceita)
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# --- 3. KEYBINDINGS (Fix para Kitty/Home/End) ---
# Garante que Home, End e Setas com Ctrl funcionem perfeitamente
# --- KEYBINDINGS (Navegação de Elite no Kitty) ---
bindkey "^[[H" beginning-of-line          # Home
bindkey "^[[F" end-of-line                # End
bindkey "^[[3~" delete-char               # Delete simples
bindkey "^[[3;5~" kill-word               # Ctrl + Delete (deleta palavra à direita)
# bindkey '^H' backward-kill-word           # Ctrl + Backspace (deleta palavra à esquerda)
bindkey "^[[1;5C" forward-word            # Ctrl + Seta Direita (pula palavra)
bindkey "^[[1;5D" backward-word           # Ctrl + Seta Esquerda (volta palavra)

# --- 4. ALIASES (Onde a mágica acontece) ---
alias ls='eza --icons --group-directories-first'
alias ll='eza -lh --icons --git --group-directories-first'
alias lt='eza --tree --level=2 --icons'
alias cat='bat --paging=never'
alias grep='rg'
alias sys='fastfetch'
alias v='nvim'
alias conf='cd ~/.config'

# --- 5. INICIALIZAÇÃO ---
# Starship (Prompt) e Zoxide (Navegação Inteligente)
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"

# Fix para o Completion (TAB mais inteligente)
autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' # Case insensitive
zstyle ':completion:*' menu select                 # Menu visual no TAB

# STARSHIP
eval "$(starship init zsh)"
export PATH="$HOME/.local/bin:$PATH"

function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

echo 'eval "$(mise activate zsh)"' >> ~/.zshrc

eval "$(mise activate zsh)"
