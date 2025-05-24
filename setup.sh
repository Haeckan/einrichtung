#!/bin/bash

set -e

# 1. Prüfen und setzen des apt Proxy über apt-proxy-detect.sh
APT_PROXY_SCRIPT="/usr/local/bin/apt-proxy-detect.sh"
APT_CONF_FILE="/etc/apt/apt.conf.d/00aptproxy"

if [ -x "$APT_PROXY_SCRIPT" ]; then
    echo "[i] apt-proxy-detect.sh ist vorhanden und ausführbar."
else
    echo "[+] Erstelle apt-proxy-detect.sh"
    sudo tee "$APT_PROXY_SCRIPT" > /dev/null <<EOF
#!/bin/bash
if nc -w1 -z "10.12.1.48" 3142; then
  echo -n "http://10.12.1.48:3142"
else
  echo -n "DIRECT"
fi
EOF
    sudo chmod +x "$APT_PROXY_SCRIPT"
fi

echo "Acquire::http::Proxy \"\$(/usr/local/bin/apt-proxy-detect.sh)\";" | sudo tee "$APT_CONF_FILE" > /dev/null

echo "[+] APT Proxy wurde gesetzt über apt-proxy-detect.sh."

# 2. Programme installieren
PACKAGES=(nala htop mc iftop zsh curl wget git tmux rsync)
echo "[+] Installiere Pakete: ${PACKAGES[*]}"
sudo apt update
sudo apt install -y "${PACKAGES[@]}"

# 3. zsh als Standardshell setzen
if [ "$SHELL" != "$(which zsh)" ]; then
    echo "[+] Setze zsh als Standardshell für Benutzer $USER"
    chsh -s "$(which zsh)"
fi

# 4. Oh My Zsh installieren
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "[+] Installiere Oh My Zsh"
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "[i] Oh My Zsh ist bereits installiert."
fi

# Zsh Plugins installieren
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
PLUGINS=(zsh-autosuggestions zsh-syntax-highlighting)
for PLUGIN in "${PLUGINS[@]}"; do
    echo "[+] Installiere Plugin: $PLUGIN"
    case $PLUGIN in
        zsh-autosuggestions)
            git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/$PLUGIN" || echo "[i] $PLUGIN bereits vorhanden."
            ;;
        zsh-syntax-highlighting)
            git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/$PLUGIN" || echo "[i] $PLUGIN bereits vorhanden."
            ;;
    esac
done

# Plugins in .zshrc aktivieren (robust und doppelfrei)
WANTED_PLUGINS=(zsh-autosuggestions zsh-syntax-highlighting tmux cp zsh-interactive-cd fzf)

if [ -f "$HOME/.zshrc" ]; then
    echo "[+] Passe .zshrc Plugin-Zeile an"
    EXISTING=$(grep -oP '^plugins=\(.*?\)' "$HOME/.zshrc" | sed -E 's/^plugins=\((.*)\)/\1/' | tr -d "\n")
    IFS=' ' read -r -a CURRENT_PLUGINS <<< "$EXISTING"
    PLUGIN_SET=()
    for PLUGIN in "${CURRENT_PLUGINS[@]}" "${WANTED_PLUGINS[@]}"; do
        [[ " ${PLUGIN_SET[*]} " == *" $PLUGIN "* ]] || PLUGIN_SET+=("$PLUGIN")
    done
    NEW_LINE="plugins=(${PLUGIN_SET[*]})"
    sed -i "s/^plugins=.*/$NEW_LINE/" "$HOME/.zshrc"
else
    echo "plugins=(${WANTED_PLUGINS[*]})" >> "$HOME/.zshrc"
fi

# Zusätzliche Konfigurationen in .zshrc vor und nach source $ZSH/oh-my-zsh.sh

if grep -q 'source \$ZSH/oh-my-zsh.sh' "$HOME/.zshrc"; then
    PRE_LINES=(
        'ENABLE_CORRECTION="true"'
        'zstyle '"'"':omz:update'"'"' mode auto'
        'ZSH_TMUX_AUTOSTART="true"'
        'ZSH_TMUX_UNICODE="true"'
        'ZSH_TMUX_FIXTERM_WITH_256COLOR="true"'
    )
    for LINE in "${PRE_LINES[@]}"; do
        grep -qxF "$LINE" "$HOME/.zshrc" || sed -i "/source \$ZSH\/oh-my-zsh.sh/i $LINE" "$HOME/.zshrc"
    done

    if ! grep -q 'source <(fzf --zsh)' "$HOME/.zshrc"; then
        sed -i "/source \$ZSH\/oh-my-zsh.sh/a source <(fzf --zsh)" "$HOME/.zshrc"
    fi
else
    {
        echo 'ENABLE_CORRECTION="true"'
        echo 'zstyle '"'"':omz:update'"'"' mode auto'
        echo 'ZSH_TMUX_AUTOSTART="true"'
        echo 'ZSH_TMUX_UNICODE="true"'
        echo 'source $ZSH/oh-my-zsh.sh'
        echo 'source <(fzf --zsh)'
    } >> "$HOME/.zshrc"
fi

# Editor und fzf Optionen ans Ende der .zshrc
EDITOR_LINES=(
    "export EDITOR='nano'"
    "export FZF_DEFAULT_OPTS='--height 40% --tmux 60% --layout reverse --border top'"
    "export TERM=xterm-256color"
)
for LINE in "${EDITOR_LINES[@]}"; do
    grep -qxF "$LINE" "$HOME/.zshrc" || echo "$LINE" >> "$HOME/.zshrc"
done

# FZF über GitHub installieren
if [ ! -d "$HOME/.fzf" ]; then
    echo "[+] Installiere fzf von GitHub"
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install --key-bindings --completion --no-update-rc
else
    echo "[i] fzf ist bereits installiert."
fi

# 5. Tmux Plugin Manager installieren und einrichten
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
    echo "[+] Installiere Tmux Plugin Manager"
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
else
    echo "[i] TPM ist bereits installiert."
fi

# Beispielhafte .tmux.conf hinzufügen
if [ ! -f "$HOME/.tmux.conf" ]; then
    echo "[+] Erstelle Beispiel ~/.tmux.conf"
    cat <<EOF > "$HOME/.tmux.conf"
set -g mouse on
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'

run '~/.tmux/plugins/tpm/tpm'
EOF
fi

# 6. System aktualisieren und neustarten
echo "[+] System wird aktualisiert..."
sudo apt update && sudo apt upgrade -y

read -p "[?] Jetzt neustarten? (j/N): " CONFIRM
if [[ "$CONFIRM" =~ ^[Jj]$ ]]; then
    echo "[+] Starte neu..."
    sudo reboot
else
    echo "[i] Neustart abgebrochen. Bitte manuell durchführen."
fi
