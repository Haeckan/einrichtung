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

echo 'Acquire::http::Proxy-Auto-Detect "/usr/local/bin/apt-proxy-detect.sh";' | sudo tee "$APT_CONF_FILE" > /dev/null

echo "[+] APT Proxy wurde gesetzt über apt-proxy-detect.sh."

# 2. Programme installieren
PACKAGES=(nala htop mc iftop zsh curl wget git tmux rsync bat btop fastfetch)
echo "[+] Installiere Pakete: ${PACKAGES[*]}"
sudo apt update
sudo apt install -y "${PACKAGES[@]}"

# 3. Systemlink für batcat -> bat erstellen
mkdir -p "$HOME/.local/bin"
if [ ! -e "$HOME/.local/bin/bat" ]; then
    ln -s /usr/bin/batcat "$HOME/.local/bin/bat"
    echo "[+] Symbolischer Link für bat erstellt: ~/.local/bin/bat"
else
    echo "[i] Symbolischer Link für bat existiert bereits."
fi

# 4. zsh als Standardshell setzen
if [ "$SHELL" != "$(which zsh)" ]; then
    echo "[+] Setze zsh als Standardshell für Benutzer $USER"
    chsh -s "$(which zsh)"
fi

# 5. Oh My Zsh installieren
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "[+] Installiere Oh My Zsh"
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "[i] Oh My Zsh ist bereits installiert."
fi

# 6. Zsh Plugins installieren
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

# 7. Powerlevel10k Theme installieren
echo "[+] Installiere Powerlevel10k Theme"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

# 8. FZF über GitHub installieren
if [ ! -d "$HOME/.fzf" ]; then
    echo "[+] Installiere fzf von GitHub"
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install --key-bindings --completion --no-update-rc
else
    echo "[i] fzf ist bereits installiert."
fi

# 9. Tmux Plugin Manager installieren und einrichten
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
    echo "[+] Installiere Tmux Plugin Manager"
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
else
    echo "[i] TPM ist bereits installiert."
fi

# 10. Konfigurationsdateien aus GitHub Repository laden
CONFIG_FILES=(
  "https://raw.githubusercontent.com/Haeckan/einrichtung/main/mc%20config/ini|$HOME/.config/mc/ini"
  "https://raw.githubusercontent.com/Haeckan/einrichtung/main/mc/dracula256.ini|$HOME/.local/share/mc/skins/dracula256.ini"
  "https://raw.githubusercontent.com/Haeckan/einrichtung/main/root/.p10k.zsh|$HOME/.p10k.zsh"
  "https://raw.githubusercontent.com/Haeckan/einrichtung/main/root/.tmux.conf|$HOME/.tmux.conf"
  "https://raw.githubusercontent.com/Haeckan/einrichtung/main/root/.zshrc|$HOME/.zshrc"
  "https://github.com/Haeckan/einrichtung/raw/refs/heads/main/root/fastfetch/root/config.jsonc|$HOME/.config/fastfetch/config.jsonc"
)

for ENTRY in "${CONFIG_FILES[@]}"; do
    IFS='|' read -r URL DEST <<< "$ENTRY"
    echo "[+] Lade $(basename "$DEST")"
    mkdir -p "$(dirname "$DEST")"
    if [ -f "$DEST" ]; then
        mv "$DEST" "$DEST.bak"
        echo "[i] Alte Datei wurde gesichert: $DEST.bak"
    fi
    curl -fsSL "$URL" -o "$DEST"
    [[ "$DEST" == "$HOME/.config/fastfetch/config.jsonc" ]] && echo "[+] Fastfetch Konfiguration installiert."
    
    chmod +x "$DEST" 2>/dev/null || true
    
    if [[ "$DEST" == "/root/.start.sh" ]]; then
        sudo chmod +x "$DEST"
    fi

done

# /root/.start.sh separat behandeln
START_SCRIPT_URL="https://github.com/Haeckan/einrichtung/raw/refs/heads/main/root/.start.sh"
START_SCRIPT_DEST="/root/.start.sh"
echo "[+] Lade .start.sh nach /root/.start.sh"
sudo curl -fsSL "$START_SCRIPT_URL" -o "$START_SCRIPT_DEST"
sudo chmod +x "$START_SCRIPT_DEST"
echo "[+] .start.sh ist jetzt ausführbar."

# 11. Fastfetch installieren (neueste Version von GitHub Release)
#echo "[+] Installiere Fastfetch (neueste Version)"
#FASTFETCH_TMP_DIR="/tmp/fastfetch"
#sudo rm -rf "$FASTFETCH_TMP_DIR"
#mkdir -p "$FASTFETCH_TMP_DIR"

#LATEST_URL=$(curl -s https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest \
#  | grep "browser_download_url.*linux-amd64.deb" \
#  | cut -d '"' -f 4)

#if [[ -z "$LATEST_URL" ]]; then
#    echo "[!] Konnte die neueste Version von Fastfetch nicht finden. Abbruch."
#else
#    echo "[+] Lade Fastfetch von: $LATEST_URL"
#    curl -L "$LATEST_URL" -o "$FASTFETCH_TMP_DIR/fastfetch.deb"
#    sudo apt install -y "$FASTFETCH_TMP_DIR/fastfetch.deb"
#    echo "[+] Fastfetch wurde erfolgreich installiert."
#fi

nano .start.sh

# 12. System aktualisieren und neustarten
echo "[+] System wird aktualisiert..."
sudo apt update && sudo apt upgrade -y

read -p "[?] Jetzt neustarten? (j/N): " CONFIRM
if [[ "$CONFIRM" =~ ^[Jj]$ ]]; then
    echo "[+] Starte neu..."
    sudo reboot
else
    echo "[i] Neustart abgebrochen. Bitte manuell durchführen."
fi
