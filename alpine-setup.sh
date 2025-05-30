#!/bin/sh

set -e

# 1. Programme installieren
PACKAGES="htop mc iftop zsh curl wget git tmux rsync bat fzf fastfetch shadow"
echo "[+] Installiere Pakete: $PACKAGES"
sudo apk update
sudo apk add $PACKAGES

# 2. Systemlink für bat -> ~/.local/bin/bat erstellen
mkdir -p "$HOME/.local/bin"
if [ ! -e "$HOME/.local/bin/bat" ]; then
    ln -s /usr/bin/bat "$HOME/.local/bin/bat"
    echo "[+] Symbolischer Link für bat erstellt: ~/.local/bin/bat"
else
    echo "[i] Symbolischer Link für bat existiert bereits."
fi

# 3. zsh als Standardshell setzen
if [ "$SHELL" != "$(which zsh)" ]; then
    if command -v chsh >/dev/null 2>&1; then
        echo "[+] Setze zsh als Standardshell für Benutzer $USER"
        chsh -s "$(which zsh)"
    else
        echo "[!] chsh ist nicht verfügbar. Stelle sicher, dass das Paket 'shadow' installiert ist."
    fi
fi

# 4. Oh My Zsh installieren
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "[+] Installiere Oh My Zsh"
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "[i] Oh My Zsh ist bereits installiert."
fi

# 5. Zsh Plugins installieren
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
PLUGINS="zsh-autosuggestions zsh-syntax-highlighting"
for PLUGIN in $PLUGINS; do
    echo "[+] Installiere Plugin: $PLUGIN"
    git clone https://github.com/zsh-users/$PLUGIN "$ZSH_CUSTOM/plugins/$PLUGIN" || echo "[i] $PLUGIN bereits vorhanden."
done

# 6. Powerlevel10k Theme installieren
echo "[+] Installiere Powerlevel10k Theme"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"

# 7. Tmux Plugin Manager installieren
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
    echo "[+] Installiere Tmux Plugin Manager"
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
else
    echo "[i] TPM ist bereits installiert."
fi

# 8. Konfigurationsdateien aus GitHub laden
CONFIG_FILES="
  https://raw.githubusercontent.com/Haeckan/einrichtung/main/mc%20config/ini|$HOME/.config/mc/ini
  https://raw.githubusercontent.com/Haeckan/einrichtung/main/mc/dracula256.ini|$HOME/.local/share/mc/skins/dracula256.ini
  https://raw.githubusercontent.com/Haeckan/einrichtung/main/root/.p10k.zsh|$HOME/.p10k.zsh
  https://raw.githubusercontent.com/Haeckan/einrichtung/main/root/.tmux.conf|$HOME/.tmux.conf
  https://raw.githubusercontent.com/Haeckan/einrichtung/main/root/.zshrc|$HOME/.zshrc
  https://github.com/Haeckan/einrichtung/raw/refs/heads/main/root/fastfetch/root/config.jsonc|$HOME/.config/fastfetch/config.jsonc
"

for ENTRY in $CONFIG_FILES; do
    URL="$(echo "$ENTRY" | cut -d '|' -f1)"
    DEST="$(echo "$ENTRY" | cut -d '|' -f2)"
    echo "[+] Lade $(basename "$DEST")"
    mkdir -p "$(dirname "$DEST")"
    if [ -f "$DEST" ]; then
        mv "$DEST" "$DEST.bak"
        echo "[i] Alte Datei wurde gesichert: $DEST.bak"
    fi
    curl -fsSL "$URL" -o "$DEST"
done

# 9. Kopiere .start.sh nach /root
echo "[+] Kopiere .start.sh nach /root/.start.sh"
sudo curl -fsSL https://github.com/Haeckan/einrichtung/raw/refs/heads/main/root/.start.sh -o /root/.start.sh
sudo chmod +x /root/.start.sh

# 10. Neustartabfrage
read -p "[?] Jetzt neustarten? (j/N): " CONFIRM
if echo "$CONFIRM" | grep -iq "^j"; then
    echo "[+] Starte neu..."
    sudo reboot
else
    echo "[i] Neustart abgebrochen. Bitte manuell durchführen."
fi
