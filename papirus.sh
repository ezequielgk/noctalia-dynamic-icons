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
ICONS_DIR="$HOME/.icons"
NOCTALIA_DIR="$HOME/.config/noctalia"
TEMPLATES_DIR="$NOCTALIA_DIR/templates"
CACHE_DIR="$HOME/.cache/noctalia"
THEME_DIR="$ICONS_DIR/Papirus-Dark"
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

echo -e "${BLUE}=== INSTALADOR EXCLUSIVO: PAPIRUS DINÁMICO ===${NC}"
echo "1) Instalar Papirus-Dark"
echo "2) LIMPIEZA TOTAL (Eliminar Papirus y configuración)"
read -r -p "Selecciona una opción [1-2]: " OPT

if [ "$OPT" == "2" ]; then
    info "Eliminando rastro de Papirus-Dark..."
    rm -rf "$THEME_DIR" "$TEMPLATES_DIR/folder-color-papirus.sh" "$CACHE_DIR/folder-color-papirus-apply.sh"
    sed -i '/\[templates.folder-color-papirus\]/,+4d' "$NOCTALIA_DIR/user-templates.toml" 2>/dev/null || true
    # Intentar volver a un tema por defecto para no dejar el escritorio sin iconos
    gsettings set org.gnome.desktop.interface icon-theme "Adwaita"
    success "Sistema limpio."; exit 0
fi

info "Verificando dependencias..."
for cmd in git curl unzip gsettings gtk-update-icon-cache gio; do
    command -v "$cmd" &>/dev/null || error "Dependencia faltante: $cmd"
done

mkdir -p "$ICONS_DIR" "$TEMPLATES_DIR" "$CACHE_DIR"

info "Descargando Papirus-Dark..."
rm -rf "$PAPIRUS_TMP" && mkdir -p "$PAPIRUS_TMP"
curl -fsSL "$PAPIRUS_URL" -o "$PAPIRUS_TMP/papirus.zip" || error "No se pudo descargar Papirus"
unzip -q "$PAPIRUS_TMP/papirus.zip" -d "$PAPIRUS_TMP"
PAPIRUS_SRC=$(find "$PAPIRUS_TMP" -maxdepth 2 -name "Papirus-Dark" -type d | head -1)
[[ -z "$PAPIRUS_SRC" ]] && error "No se encontró Papirus-Dark"

info "Instalando Papirus-Dark..."
rm -rf "$THEME_DIR"
cp -rL "$PAPIRUS_SRC" "$THEME_DIR"

info "Inicializando caché git..."
git -C "$THEME_DIR" init -q
git -C "$THEME_DIR" add -A
git -C "$THEME_DIR" commit -q -m "original"
git -C "$THEME_DIR" tag "original"

info "Instalando template..."
cat > "$TEMPLATES_DIR/folder-color-papirus.sh" << 'TEMPLATE'
#!/usr/bin/env bash
PRIMARY="{{colors.primary.default.hex}}"
SECONDARY="{{colors.secondary.default.hex}}"
COLOR="${PRIMARY:1}"
COLOR2="${SECONDARY:1}"
THEME_DIR="$HOME/.icons/Papirus-Dark"
BRANCH="color-${COLOR}-${COLOR2}"

hex_darken() {
    local hex="${1}"
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    printf "%02x%02x%02x" $(( r*65/100 )) $(( g*65/100 )) $(( b*65/100 ))
}
COLOR_DARK=$(hex_darken "$COLOR")

if [[ ! -d "$THEME_DIR/.git" ]]; then
    git -C "$THEME_DIR" init -q
    git -C "$THEME_DIR" add -A
    git -C "$THEME_DIR" commit -q -m "original"
    git -C "$THEME_DIR" tag "original"
fi

# Restaurar y pintar
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
gsettings set org.gnome.desktop.interface icon-theme "hicolor" 2>/dev/null
sleep 0.3
gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark" 2>/dev/null
TEMPLATE

info "Actualizando user-templates.toml..."
sed -i '/\[templates.folder-color-papirus\]/,+4d' "$NOCTALIA_DIR/user-templates.toml" 2>/dev/null || true
cat >> "$NOCTALIA_DIR/user-templates.toml" << EOF

[templates.folder-color-papirus]
input_path  = "~/.config/noctalia/templates/folder-color-papirus.sh"
output_path = "~/.cache/noctalia/folder-color-papirus-apply.sh"
post_hook   = "bash ~/.cache/noctalia/folder-color-papirus-apply.sh"
EOF

gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
rm -rf "$PAPIRUS_TMP"

success "¡Instalación de Papirus completada!"
info "¡Instalación completada! Refresca la Paleta de Colores para ver cambios!"
