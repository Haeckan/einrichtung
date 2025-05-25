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

echo "Acquire::http::Proxy-Auto-Detect \"\/usr/local/bin/apt-proxy-detect.sh\";" | sudo tee "$APT_CONF_FILE" > /dev/null

echo "[+] APT Proxy wurde gesetzt über apt-proxy-detect.sh."

# 2. Programme installieren
PACKAGES=(nala htop mc iftop zsh curl wget git tmux rsync bat)
echo "[+] Installiere Pakete: ${PACKAGES[*]}"
sudo apt update
sudo apt install -y "${PACKAGES[@]}"

# Systemlink für batcat -> bat erstellen
mkdir -p "$HOME/.local/bin"
if [ ! -e "$HOME/.local/bin/bat" ]; then
    ln -s /usr/bin/batcat "$HOME/.local/bin/bat"
    echo "[+] Symbolischer Link für bat erstellt: ~/.local/bin/bat"
else
    echo "[i] Symbolischer Link für bat existiert bereits."
fi

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

# FZF über GitHub installieren
if [ ! -d "$HOME/.fzf" ]; then
    echo "[+] Installiere fzf von GitHub"
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install --key-bindings --completion --no-update-rc
else
    echo "[i] fzf ist bereits installiert."
fi

# 5. Tmux Plugin Manager installieren
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
    echo "[+] Installiere Tmux Plugin Manager"
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
else
    echo "[i] TPM ist bereits installiert."
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
