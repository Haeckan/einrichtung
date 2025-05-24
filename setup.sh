#!/bin/bash

set -e

# 1. Programme installieren
PACKAGES=(nala htop mc iftop zsh curl wget git tmux)
echo "[+] Installiere Pakete: ${PACKAGES[*]}"
sudo apt update
sudo apt install -y "${PACKAGES[@]}"

# 2. Prüfen und setzen des apt Proxy
APT_PROXY_FILE="/etc/apt/apt.conf.d/01proxy"
PROXY_ADDRESS="http://10.12.1.48:3142"
echo "[+] Überprüfe APT Proxy..."

if grep -q "$PROXY_ADDRESS" "$APT_PROXY_FILE" 2>/dev/null; then
    echo "[i] APT Proxy ist bereits gesetzt."
else
    echo "Acquire::http::Proxy \"$PROXY_ADDRESS\";" | sudo tee "$APT_PROXY_FILE"
    echo "[+] APT Proxy wurde gesetzt."
fi

# 3. zsh als Standardshell setzen
if [ "$SHELL" != "$(which zsh)" ]; then
    echo "[+] Setze zsh als Standardshell für Benutzer $USER"
    chsh -s $(which zsh)
fi

# 4. Oh My Zsh installieren
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "[+] Installiere Oh My Zsh"
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "[i] Oh My Zsh ist bereits installiert."
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
