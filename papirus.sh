#!/usr/bin/env bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[info]${NC} $1"; }
success() { echo -e "${GREEN}[ok]${NC} $1"; }
error()   { echo -e "${RED}[error]${NC} $1"; exit 1; }

ICONS_DIR="$HOME/.icons"
NOCTALIA_DIR="$HOME/.config/noctalia"
TEMPLATES_DIR="$NOCTALIA_DIR/templates"
CACHE_DIR="$HOME/.cache/noctalia"
THEME_DIR="$ICONS_DIR/Papirus-Dark"
PAPIRUS_URL="https://github.com/PapirusDevelopmentTeam/papirus-icon-theme/archive/refs/heads/master.zip"
PAPIRUS_TMP="/tmp/papirus-install"

echo ""
echo "  ╔══════════════════════════════════════════╗"
echo "  ║   Noctalia Dynamic Folder Colors         ║"
echo "  ╚══════════════════════════════════════════╝"
echo ""

info "Verificando dependencias..."
for cmd in git curl unzip gsettings gtk-update-icon-cache gio; do
    command -v "$cmd" &>/dev/null || error "Dependencia faltante: $cmd"
done
success "Dependencias OK"

mkdir -p "$ICONS_DIR" "$TEMPLATES_DIR" "$CACHE_DIR"

info "Descargando Papirus-Dark..."
rm -rf "$PAPIRUS_TMP" && mkdir -p "$PAPIRUS_TMP"
curl -fsSL "$PAPIRUS_URL" -o "$PAPIRUS_TMP/papirus.zip" || error "No se pudo descargar Papirus"
unzip -q "$PAPIRUS_TMP/papirus.zip" -d "$PAPIRUS_TMP"
PAPIRUS_SRC=$(find "$PAPIRUS_TMP" -maxdepth 2 -name "Papirus-Dark" -type d | head -1)
[[ -z "$PAPIRUS_SRC" ]] && error "No se encontró Papirus-Dark"
success "Descargado"

info "Instalando Papirus-Dark..."
rm -rf "$THEME_DIR"
cp -rL "$PAPIRUS_SRC" "$THEME_DIR"
success "Papirus-Dark instalado"

info "Inicializando caché git..."
git -C "$THEME_DIR" init -q
git -C "$THEME_DIR" add -A
git -C "$THEME_DIR" commit -q -m "original"
git -C "$THEME_DIR" tag "original"
success "Caché listo"

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

if git -C "$THEME_DIR" show-ref --quiet "refs/heads/$BRANCH"; then
    git -C "$THEME_DIR" checkout -q "$BRANCH"
else
    git -C "$THEME_DIR" checkout -q main
    git -C "$THEME_DIR" checkout -q "original" -- .
    git -C "$THEME_DIR" add -A
    git -C "$THEME_DIR" commit -q --allow-empty -m "restored"
    git -C "$THEME_DIR" checkout -q -b "$BRANCH"

    find "$THEME_DIR" -name "*.svg" -path "*/places/*" -print0 | xargs -0 sed -i \
        -e "s/fill:#5294e2/fill:#${COLOR}/gI" \
        -e "s/fill:#4877b1/fill:#${COLOR_DARK}/gI" \
        -e "s/fill:#1d344f/fill:#${COLOR_DARK}/gI" \
        -e "s/fill:#c9a554/fill:#${COLOR2}/gI" \
        -e "s/fill:#e4e4e4/fill:#${COLOR2}/gI" \
        -e "s/fill:#ffffff/fill:#${COLOR2}/gI"

    git -C "$THEME_DIR" add -A
    git -C "$THEME_DIR" commit -q -m "${PRIMARY}/${SECONDARY}"
fi

gtk-update-icon-cache -f -t "$THEME_DIR" 2>/dev/null
CURRENT=$(gsettings get org.gnome.desktop.interface icon-theme | tr -d "'")
if [[ "$CURRENT" == "Papirus-Dark" ]]; then
    gsettings set org.gnome.desktop.interface icon-theme "hicolor" 2>/dev/null
    sleep 0.3
    gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark" 2>/dev/null
else
    gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark" 2>/dev/null
fi

gio set ~/Escritorio metadata::custom-icon-name "user-desktop" 2>/dev/null || true
gio set ~/Desktop metadata::custom-icon-name "user-desktop" 2>/dev/null || true
TEMPLATE
success "Template instalado"

info "Actualizando user-templates.toml..."
TOML_FILE="$NOCTALIA_DIR/user-templates.toml"
touch "$TOML_FILE"
if ! grep -q "\[templates.folder-color-papirus\]" "$TOML_FILE"; then
    cat >> "$TOML_FILE" << EOF

[templates.folder-color-papirus]
input_path  = "~/.config/noctalia/templates/folder-color-papirus.sh"
output_path = "~/.cache/noctalia/folder-color-papirus-apply.sh"
post_hook   = "bash ~/.cache/noctalia/folder-color-papirus-apply.sh"
EOF
fi
success "user-templates.toml actualizado"

gtk-update-icon-cache -f -t "$THEME_DIR" 2>/dev/null
gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
gio set ~/Escritorio metadata::custom-icon-name "user-desktop" 2>/dev/null || true
gio set ~/Desktop metadata::custom-icon-name "user-desktop" 2>/dev/null || true
rm -rf "$PAPIRUS_TMP"

echo ""
echo -e "  ${GREEN}✓ Instalación completada${NC}"
echo ""
