#!/usr/bin/env bash
set -e

# Colores para la terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[info]${NC} $1"; }
success() { echo -e "${GREEN}[ok]${NC} $1"; }
error()   { echo -e "${RED}[error]${NC} $1"; exit 1; }

# Rutas
THEME_NAME="Noctalia-Papirus"
ICONS_DIR="$HOME/.icons"
NOCTALIA_DIR="$HOME/.config/noctalia"
TEMPLATES_DIR="$NOCTALIA_DIR/templates"
CACHE_DIR="$HOME/.cache/noctalia"
THEME_DIR="$ICONS_DIR/$THEME_NAME"
PAPIRUS_URL="https://github.com/PapirusDevelopmentTeam/papirus-icon-theme/archive/refs/heads/master.zip"
PAPIRUS_TMP="/tmp/papirus-install"

clear
echo -e "${BLUE}"
echo "    ____                                ____              _                "
echo "   / __ \__  ______  ____ _____ ___  (_)____            / __ \____ _____  (_)______  _______"
echo "  / / / / / / / __ \/ __ \`/ __ \`__ \/ / ___/  ______   / /_/ / __ \`/ __ \/ / ___/ / / / ___/"
echo " / /_/ / /_/ / / / / /_/ / / / / / / / /__   /_____/  / ____/ /_/ / /_/ / / /   / /_/ (__  ) "
echo "/_____/\__, /_/ /_/\__,_/_/ /_/ /_/_/\___/           /_/    \__,_/ .___/_/_/    \__,_/____/  "
echo "      /____/                                                    /_/                          "
echo -e "${NC}"

echo -e "${BLUE}=== INSTALADOR EXCLUSIVO: $THEME_NAME ===${NC}"
echo "1) Instalar $THEME_NAME"
echo "2) LIMPIEZA TOTAL (Eliminar iconos y configuración)"
read -r -p "Selecciona una opción [1-2]: " OPT < /dev/tty

if [ "$OPT" == "2" ]; then
    info "Eliminando rastro de $THEME_NAME..."
    rm -rf "$THEME_DIR" "$TEMPLATES_DIR/$THEME_NAME.sh" "$CACHE_DIR/$THEME_NAME-apply.sh"
    sed -i "/\[templates.${THEME_NAME,,}\]/,+4d" "$NOCTALIA_DIR/user-templates.toml" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "Adwaita"
    success "Sistema limpio."; exit 0
fi

info "Verificando dependencias..."
for cmd in git curl unzip gsettings gtk-update-icon-cache; do
    command -v "$cmd" &>/dev/null || error "Dependencia faltante: $cmd"
done

mkdir -p "$ICONS_DIR" "$TEMPLATES_DIR" "$CACHE_DIR"

info "Descargando base Papirus-Dark..."
rm -rf "$PAPIRUS_TMP" && mkdir -p "$PAPIRUS_TMP"
curl -fsSL "$PAPIRUS_URL" -o "$PAPIRUS_TMP/papirus.zip" || error "No se pudo descargar"
unzip -q "$PAPIRUS_TMP/papirus.zip" -d "$PAPIRUS_TMP"
SRC=$(find "$PAPIRUS_TMP" -maxdepth 2 -name "Papirus-Dark" -type d | head -1)

info "Personalizando paquete de iconos..."
rm -rf "$THEME_DIR"
cp -rL "$SRC" "$THEME_DIR"
# Cambiar el nombre interno del tema
sed -i "s/^Name=.*/Name=$THEME_NAME/" "$THEME_DIR/index.theme"

info "Inicializando motor dinámico (Git)..."
git -C "$THEME_DIR" init -q
git -C "$THEME_DIR" add -A
git -C "$THEME_DIR" commit -q -m "original"
git -C "$THEME_DIR" tag "original"

info "Instalando plantilla de color..."
cat > "$TEMPLATES_DIR/$THEME_NAME.sh" << 'TEMPLATE'
#!/usr/bin/env bash
PRIMARY="{{colors.primary.default.hex}}"
SECONDARY="{{colors.secondary.default.hex}}"
COLOR="${PRIMARY:1}"
COLOR2="${SECONDARY:1}"
THEME_NAME="Noctalia-Papirus"
THEME_DIR="$HOME/.icons/$THEME_NAME"
BRANCH="color-${COLOR}-${COLOR2}"

hex_darken() {
    local hex="${1}"
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    printf "%02x%02x%02x" $(( r*65/100 )) $(( g*65/100 )) $(( b*65/100 ))
}
COLOR_DARK=$(hex_darken "$COLOR")

# Restaurar y aplicar nuevos colores
git -C "$THEME_DIR" checkout -q "original" -- .
git -C "$THEME_DIR" checkout -b "$BRANCH" 2>/dev/null || git -C "$THEME_DIR" checkout -q "$BRANCH"

find "$THEME_DIR" -name "*.svg" -path "*/places/*" -print0 | xargs -0 sed -i \
    -e "s/fill:#5294e2/fill:#${COLOR}/gI" \
    -e "s/fill:#4877b1/fill:#${COLOR_DARK}/gI" \
    -e "s/fill:#1d344f/fill:#${COLOR_DARK}/gI" \
    -e "s/fill:#c9a554/fill:#${COLOR2}/gI" \
    -e "s/fill:#e4e4e4/fill:#${COLOR2}/gI" \
    -e "s/fill:#ffffff/fill:#${COLOR2}/gI"

gtk-update-icon-cache -f -t "$THEME_DIR" 2>/dev/null
gsettings set org.gnome.desktop.interface icon-theme "hicolor"
sleep 0.3
gsettings set org.gnome.desktop.interface icon-theme "$THEME_NAME"
TEMPLATE

info "Actualizando configuración de Noctalia..."
sed -i "/\[templates.${THEME_NAME,,}\]/,+4d" "$NOCTALIA_DIR/user-templates.toml" 2>/dev/null || true
cat >> "$NOCTALIA_DIR/user-templates.toml" << EOF

[templates.${THEME_NAME,,}]
input_path  = "~/.config/noctalia/templates/$THEME_NAME.sh"
output_path = "~/.cache/noctalia/$THEME_NAME-apply.sh"
post_hook   = "bash ~/.cache/noctalia/$THEME_NAME-apply.sh"
EOF

gsettings set org.gnome.desktop.interface icon-theme "$THEME_NAME"
rm -rf "$PAPIRUS_TMP"

echo ""
success "¡Instalación de $THEME_NAME completada!"
info "Refresca tu paleta de Noctalia para aplicar los colores."
