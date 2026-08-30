#!/usr/bin/env bash
# ==============================================================================
# Omarchy-Style Web Apps Setup for Fedora (Wayland Ozone)
# ==============================================================================
# Features:
# - Configures Chrome Flatpak to use native Wayland via Ozone platform flags
# - Deploys omarchy-launch-webapp & install-webapp to ~/.local/bin
# - Deploys dedicated desktop entries for ChatGPT, Gemini, and Notion
# - Configures standalone window identity & StartupWMClass for WindowCycler
# - Links high-resolution icons & refreshes GTK icon cache
# ==============================================================================

set -euo pipefail

BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor"
CHROME_FLATPAK_CONFIG="$HOME/.var/app/com.google.Chrome/config"

if [ "$EUID" -eq 0 ]; then
    echo "Error: Do not run this script with sudo directly."
    echo "Run it as your normal user."
    exit 1
fi

echo "=========================================="
echo " Starting Web Apps Setup (Wayland Ozone)"
echo "=========================================="

mkdir -p "$BIN_DIR" "$APP_DIR" "$ICON_DIR"

# 1. Configure Persistent Chrome Wayland / Ozone Flags
echo "[1/5] Configuring Chrome Ozone platform flags..."
mkdir -p "$CHROME_FLATPAK_CONFIG" "$HOME/.config"

cat << 'FLAGS_EOF' > "$CHROME_FLATPAK_CONFIG/chrome-flags.conf"
--ozone-platform-hint=auto
--ozone-platform=wayland
--enable-features=WaylandWindowDecorations
FLAGS_EOF

cp "$CHROME_FLATPAK_CONFIG/chrome-flags.conf" "$HOME/.config/chrome-flags.conf"
echo "Saved chrome-flags.conf for Flatpak and native Chrome."

# 2. Deploy Launcher and Installer Scripts
echo "[2/5] Deploying omarchy-launch-webapp and install-webapp to $BIN_DIR..."

cat << 'LAUNCH_EOF' > "$BIN_DIR/omarchy-launch-webapp"
#!/usr/bin/env bash
# ==============================================================================
# omarchy-launch-webapp
# Launches web applications in a dedicated Chromium/Chrome instance
# running natively on Wayland with Ozone platform flags.
#
# Usage:
#   omarchy-launch-webapp <url_or_app_id> [app_name] [additional_flags...]
# ==============================================================================

set -euo pipefail

TARGET="${1:-}"
APP_NAME="${2:-}"
shift 2 2>/dev/null || shift 1 2>/dev/null || true

if [ -z "$TARGET" ]; then
  echo "Usage: $0 <url_or_app_id> [app_name] [additional_flags...]" >&2
  exit 1
fi

# Detect installed browser runner
BROWSER_CMD=()
if [ -n "${WEBAPP_BROWSER:-}" ]; then
  BROWSER_CMD=($WEBAPP_BROWSER)
elif command -v google-chrome-stable >/dev/null 2>&1; then
  BROWSER_CMD=(google-chrome-stable)
elif command -v google-chrome >/dev/null 2>&1; then
  BROWSER_CMD=(google-chrome)
elif command -v chromium >/dev/null 2>&1; then
  BROWSER_CMD=(chromium)
elif command -v brave-browser >/dev/null 2>&1; then
  BROWSER_CMD=(brave-browser)
elif flatpak list --app 2>/dev/null | grep -q "com.google.Chrome"; then
  BROWSER_CMD=(flatpak run com.google.Chrome)
elif flatpak list --app 2>/dev/null | grep -q "org.chromium.Chromium"; then
  BROWSER_CMD=(flatpak run org.chromium.Chromium)
else
  echo "Error: No Chromium-based browser found." >&2
  exit 1
fi

# Ozone & Wayland rendering flags
OZONE_FLAGS=(
  "--ozone-platform=wayland"
  "--enable-features=UseOzonePlatform,WaylandWindowDecorations"
  "--enable-gpu-rasterization"
)

# App mode / target flags
APP_FLAGS=(
  "--profile-directory=Default"
)

if [[ "$TARGET" =~ ^https?:// ]]; then
  APP_FLAGS+=("--app=${TARGET}")
elif [[ "$TARGET" =~ ^--app-id= ]]; then
  APP_FLAGS+=("${TARGET}")
else
  APP_FLAGS+=("--app-id=${TARGET}")
fi

if [ -n "$APP_NAME" ]; then
  APP_FLAGS+=(
    "--class=${APP_NAME}"
    "--name=${APP_NAME}"
  )
fi

exec "${BROWSER_CMD[@]}" "${OZONE_FLAGS[@]}" "${APP_FLAGS[@]}" "$@" >/dev/null 2>&1
LAUNCH_EOF

chmod +x "$BIN_DIR/omarchy-launch-webapp"
ln -sf "$BIN_DIR/omarchy-launch-webapp" "$BIN_DIR/launch-webapp"

cat << 'INSTALL_EOF' > "$BIN_DIR/install-webapp"
#!/usr/bin/env bash
# ==============================================================================
# install-webapp
# Creates a dedicated native desktop entry for any web application
# using omarchy-launch-webapp (Chromium + Wayland Ozone).
#
# Usage:
#   install-webapp <name> <url> [icon_url_or_path]
#
# Example:
#   install-webapp "Linear" "https://linear.app" "https://linear.app/favicon.ico"
# ==============================================================================

set -euo pipefail

NAME="${1:-}"
URL="${2:-}"
ICON_SRC="${3:-}"

if [ -z "$NAME" ] || [ -z "$URL" ]; then
  echo "Usage: $0 <name> <url> [icon_url_or_path]" >&2
  exit 1
fi

APP_ID=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
DESKTOP_FILE="$HOME/.local/share/applications/${APP_ID}.desktop"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
mkdir -p "$HOME/.local/share/applications" "$ICON_DIR"

ICON_NAME="$APP_ID"

if [ -n "$ICON_SRC" ]; then
  if [[ "$ICON_SRC" =~ ^https?:// ]]; then
    curl -sSL "$ICON_SRC" -o "$ICON_DIR/${ICON_NAME}.png" 2>/dev/null || true
  elif [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$ICON_DIR/${ICON_NAME}.png"
  fi
fi

cat << DESKTOP > "$DESKTOP_FILE"
[Desktop Entry]
Version=1.0
Type=Application
Name=${NAME}
Comment=${NAME} Web App
Exec=${HOME}/.local/bin/omarchy-launch-webapp "${URL}" "${APP_ID}"
Icon=${ICON_NAME}
StartupWMClass=${APP_ID}
Terminal=false
Categories=Network;WebBrowser;Utility;
DESKTOP

chmod +x "$DESKTOP_FILE"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo "✓ Successfully installed ${NAME} -> ${DESKTOP_FILE}"
INSTALL_EOF

chmod +x "$BIN_DIR/install-webapp"
ln -sf "$BIN_DIR/install-webapp" "$BIN_DIR/omarchy-install-webapp"

# 3. Deploy Desktop Entries (ChatGPT, Gemini, Notion)
echo "[3/5] Deploying web app desktop entries to $APP_DIR..."

cat << 'CHATGPT_EOF' > "$APP_DIR/chatgpt.desktop"
[Desktop Entry]
Version=1.0
Terminal=false
Type=Application
Name=ChatGPT
GenericName=AI Assistant
Comment=OpenAI ChatGPT
Exec=/home/shubham/.local/bin/omarchy-launch-webapp "cadlkienfkclaiaibeoongdcgmdikeeg" "chatgpt"
Icon=chatgpt
StartupWMClass=chrome-cadlkienfkclaiaibeoongdcgmdikeeg-Default
Categories=Network;WebBrowser;Utility;
Keywords=chatgpt;openai;ai;assistant;chat;
CHATGPT_EOF

cat << 'GEMINI_EOF' > "$APP_DIR/gemini.desktop"
[Desktop Entry]
Version=1.0
Terminal=false
Type=Application
Name=Gemini
GenericName=AI Assistant
Comment=Google Gemini AI Assistant
Exec=/home/shubham/.local/bin/omarchy-launch-webapp "gdfaincndogidkdcdkhapmbffkckdkhn" "gemini"
Icon=gemini
StartupWMClass=chrome-gdfaincndogidkdcdkhapmbffkckdkhn-Default
Categories=Network;WebBrowser;Utility;
Keywords=gemini;google;ai;assistant;chat;
GEMINI_EOF

cat << 'NOTION_EOF' > "$APP_DIR/notion.desktop"
[Desktop Entry]
Version=1.0
Terminal=false
Type=Application
Name=Notion
GenericName=Notes & Workspace
Comment=Notion Workspace
Exec=/home/shubham/.local/bin/omarchy-launch-webapp "dcokohelbbehjlcjjfmhfbpdgfjcoopf" "notion"
Icon=notion
StartupWMClass=chrome-dcokohelbbehjlcjjfmhfbpdgfjcoopf-Default
Categories=Office;Utility;
Keywords=notion;notes;workspace;docs;
NOTION_EOF

chmod +x "$APP_DIR/chatgpt.desktop" "$APP_DIR/gemini.desktop" "$APP_DIR/notion.desktop"

# 4. Link Icons and Build Icon Cache
echo "[4/5] Setting up high-resolution icon symlinks..."
for size in 16x16 32x32 48x48 128x128 256x256 512x512; do
  dir="$ICON_DIR/$size/apps"
  if [ -d "$dir" ]; then
    [ -f "$dir/chrome-cadlkienfkclaiaibeoongdcgmdikeeg-Default.png" ] && ln -sf "$dir/chrome-cadlkienfkclaiaibeoongdcgmdikeeg-Default.png" "$dir/chatgpt.png"
    [ -f "$dir/chrome-gdfaincndogidkdcdkhapmbffkckdkhn-Default.png" ] && ln -sf "$dir/chrome-gdfaincndogidkdcdkhapmbffkckdkhn-Default.png" "$dir/gemini.png"
    [ -f "$dir/chrome-dcokohelbbehjlcjjfmhfbpdgfjcoopf-Default.png" ] && ln -sf "$dir/chrome-dcokohelbbehjlcjjfmhfbpdgfjcoopf-Default.png" "$dir/notion.png"
  fi
done

if [ -d "$ICON_DIR/512x512/apps" ] && [ -f "$ICON_DIR/256x256/apps/chatgpt.png" ] && [ ! -f "$ICON_DIR/512x512/apps/chatgpt.png" ]; then
  ln -sf "$ICON_DIR/256x256/apps/chatgpt.png" "$ICON_DIR/512x512/apps/chatgpt.png"
fi

cp -n /usr/share/icons/hicolor/index.theme "$ICON_DIR/index.theme" 2>/dev/null || true
gtk-update-icon-cache -f "$ICON_DIR" 2>/dev/null || true

# 5. Refresh Desktop Database
echo "[5/5] Refreshing application database..."
update-desktop-database "$APP_DIR" 2>/dev/null || true

echo "=========================================="
echo " Web Apps Setup Completed Successfully!"
echo " Apps installed: ChatGPT, Gemini, Notion"
echo "=========================================="
