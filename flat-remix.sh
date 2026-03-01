#!/usr/bin/env bash
set -e

# Colores para la terminal
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[info]${NC} $1"; }
success() { echo -e "${GREEN}[ok]${NC} $1"; }
error()   { echo -e "${RED}[error]${NC} $1"; exit 1; }

# Rutas
ICONS_DIR="$HOME/.icons"
NOCTALIA_DIR="$HOME/.config/noctalia"
TEMPLATES_DIR="$NOCTALIA_DIR/templates"
CACHE_DIR="$HOME/.cache/noctalia"
THEME_NAME="Noctalia-Flat"
THEME_DIR="$ICONS_DIR/$THEME_NAME"
TMP_DIR="/tmp/icon-install-flat-remix"

clear
# Arte ASCII solicitado
echo -e "${BLUE}"
echo "    _  __            __        ___              ________      __ "
echo "   / | / /___  _____/ /_____ _/ (_)___ _       / ____/ /___ _/ /_"
echo "  /  |/ / __ \/ ___/ __/ __ \`/ / / __ \`/_____/ /_  / / __ \`/ __/"
echo " / /|  / /_/ / /__/ /_/ /_/ / / / /_/ /_____/ __/ / / /_/ / /_  "
echo "/_/ |_/\____/\___/\__/\__,_/_/_/\__,_/     /_/   /_/\__,_/\__/  "
echo "                                                                "
echo -e "${NC}"

echo -e "${BLUE}=== INSTALADOR EXCLUSIVO: $THEME_NAME ===${NC}"
echo "1) Instalar $THEME_NAME (Basado en Flat Remix)"
echo "2) LIMPIEZA TOTAL"
read -r -p "Selecciona una opción [1-2]: " OPT

if [ "$OPT" == "2" ]; then
    info "Eliminando rastro de configuraciones previas..."
    rm -rf "$THEME_DIR" "$TEMPLATES_DIR/${THEME_NAME}.sh" "$CACHE_DIR/${THEME_NAME}-apply.sh"
    sed -i "/\[templates.${THEME_NAME,,}\]/,+4d" "$NOCTALIA_DIR/user-templates.toml" 2>/dev/null || true
    success "Sistema limpio."; exit 0
fi

# --- CONFIGURACIÓN ESPECÍFICA ---
B_NAME="Flat Remix"
URL="https://github.com/daniruiz/flat-remix/archive/refs/heads/master.zip"
MATCH="Flat-Remix-Blue-Dark"

# --- DESCARGA ---
info "Descargando base $B_NAME..."
rm -rf "$TMP_DIR" && mkdir -p "$TMP_DIR"
curl -fsSL "$URL" -o "$TMP_DIR/theme.zip"
unzip -q "$TMP_DIR/theme.zip" -d "$TMP_DIR"
SRC=$(find "$TMP_DIR" -maxdepth 3 -name "$MATCH" -type d | head -1)

# --- COPIA INTELIGENTE (Creando tema separado) ---
info "Creando estructura para $THEME_NAME..."
rm -rf "$THEME_DIR" && mkdir -p "$THEME_DIR"
find "$SRC" -type d -name "places" | while read -r p; do
    rel="${p#$SRC/}"; mkdir -p "$THEME_DIR/$rel"
    cp -a "$p/." "$THEME_DIR/$rel/"
done

# Copiar index.theme y renombrarlo internamente
cp "$SRC/index.theme" "$THEME_DIR/"
sed -i "s/^Name=.*/Name=$THEME_NAME/" "$THEME_DIR/index.theme"
sed -i "s/^Inherits=.*/Inherits=$MATCH,hicolor/" "$THEME_DIR/index.theme"

# --- SNAPSHOT GIT (Para reset de color) ---
info "Creando snapshot original para Noctalia..."
cd "$THEME_DIR"
git init -q
git add .
git commit -q -m "original"
git tag -f "original"

# --- SCRIPT APLICADOR DE COLOR (Template) ---
info "Creando template para Noctalia..."
mkdir -p "$TEMPLATES_DIR"
cat > "$TEMPLATES_DIR/${THEME_NAME}.sh" << 'EOF'
#!/usr/bin/env bash
PRI="{{colors.primary.default.hex}}"
C1="${PRI:1}"
T_DIR="$HOME/.icons/Noctalia-Flat"
BRANCH="color-${C1}"

# Resetear al estado original antes de pintar
git -C "$T_DIR" checkout -q original -- .
git -C "$T_DIR" checkout -b "$BRANCH" 2>/dev/null || git -C "$T_DIR" checkout -q "$BRANCH"

# MOTOR DE COLOR ULTRA-AGRESIVO
find "$T_DIR" -name "*.svg" -type f -print0 | xargs -0 sed -i -E \
    -e "s/fill:#[0-9a-fA-F]{6}/fill:#${C1}/gI" \
    -e "s/fill=\"#[0-9a-fA-F]{6}\"/fill=\"#${C1}\"/gI" \
    -e "s/stop-color:#[0-9a-fA-F]{6}/stop-color:#${C1}/gI" \
    -e "s/stop-color=\"#[0-9a-fA-F]{6}\"/stop-color=\"#${C1}\"/gI" \
    -e "s/style=\"fill:#[0-9a-fA-F]{6}/style=\"fill:#${C1}/gI"

gtk-update-icon-cache -f -t "$T_DIR" 2>/dev/null
gsettings set org.gnome.desktop.interface icon-theme "hicolor"
sleep 0.5
gsettings set org.gnome.desktop.interface icon-theme "Noctalia-Flat"
EOF

# --- VINCULACIÓN CON NOCTALIA ---
info "Actualizando user-templates.toml..."
sed -i "/\[templates.${THEME_NAME,,}\]/,+4d" "$NOCTALIA_DIR/user-templates.toml" 2>/dev/null || true
cat >> "$NOCTALIA_DIR/user-templates.toml" << EOF

[templates.${THEME_NAME,,}]
input_path  = "~/.config/noctalia/templates/${THEME_NAME}.sh"
output_path = "~/.cache/noctalia/${THEME_NAME}-apply.sh"
post_hook   = "bash ~/.cache/noctalia/${THEME_NAME}-apply.sh"
EOF

# Aplicar el tema inmediatamente
gsettings set org.gnome.desktop.interface icon-theme "$THEME_NAME"
rm -rf "$TMP_DIR"

success "¡Instalación de $THEME_NAME completada!"
info "Refresca la Paleta de Colores en Noctalia para ver los cambios."
