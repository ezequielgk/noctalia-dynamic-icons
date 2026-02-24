#!/usr/bin/env bash
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[info]${NC} $1"; }
success() { echo -e "${GREEN}[ok]${NC} $1"; }
error()   { echo -e "${RED}[error]${NC} $1"; exit 1; }

THEME_NAME="Noctalia-Tela-dark"
ICONS_DIR="$HOME/.icons"
NOCTALIA_DIR="$HOME/.config/noctalia"
TEMPLATES_DIR="$NOCTALIA_DIR/templates"
CACHE_DIR="$HOME/.cache/noctalia"
THEME_DIR="$ICONS_DIR/$THEME_NAME"
TMP_DIR="/tmp/icon-install-tela"

clear
echo -e "${BLUE}"
echo "    _   __           __      ___          ______     __"
echo "   / | / /___  _____/ /___  / (_)___ _   /_  __/__  / /___ _"
echo "  /  |/ / __ \/ ___/ __/ / / / / __ \`/    / / / _ \/ / __ \`/"
echo " / /|  / /_/ / /__/ /_/ /_/ / / /_/ /    / / /  __/ / /_/ / "
echo "/_/ |_/\____/\___/\__/\__,_/_/\__,_/    /_/  \___/_/\__,_/  "
echo -e "${NC}"

echo -e "${BLUE}=== INSTALADOR EXCLUSIVO: $THEME_NAME ===${NC}"
echo "1) Instalar $THEME_NAME"
echo "2) LIMPIEZA TOTAL"
read -r -p "Selecciona una opción [1-2]: " OPT < /dev/tty

if [ "$OPT" == "2" ]; then
    info "Limpiando instalación de $THEME_NAME..."
    rm -rf "$THEME_DIR"
    rm -rf "$TEMPLATES_DIR/${THEME_NAME}.sh" "$CACHE_DIR/${THEME_NAME}-apply.sh"
    sed -i "/\[templates.${THEME_NAME,,}\]/,+4d" "$NOCTALIA_DIR/user-templates.toml" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "Adwaita"
    success "Limpieza completa."; exit 0
fi

# --- DESCARGA ---
info "Descargando repositorio original de Tela..."
rm -rf "$TMP_DIR" && mkdir -p "$TMP_DIR"
curl -fsSL "https://github.com/vinceliuice/Tela-icon-theme/archive/refs/heads/master.zip" -o "$TMP_DIR/tela.zip"
unzip -q "$TMP_DIR/tela.zip" -d "$TMP_DIR"
TDIR=$(find "$TMP_DIR" -maxdepth 1 -type d -name "Tela-icon-theme*")

# --- INSTALACIÓN OFICIAL ---
info "Ejecutando instalador oficial de Tela..."
rm -rf "$THEME_DIR"
bash "$TDIR/install.sh" -d "$ICONS_DIR" -n "Noctalia-Tela"
# El instalador crea: Noctalia-Tela, Noctalia-Tela-dark, Noctalia-Tela-light
# Usamos Noctalia-Tela-dark directamente, sin mover nada

[ -d "$THEME_DIR" ] || error "El instalador no creó $THEME_NAME"

# --- PREPARACIÓN PARA NOCTALIA ---
info "Configurando Git interno para los iconos..."
cd "$THEME_DIR"
git init -q
git add .
git commit -q -m "original"
git tag "original"

# --- CREACIÓN DEL SCRIPT DE APLICACIÓN ---
info "Creando plantilla para Noctalia..."
mkdir -p "$TEMPLATES_DIR"
cat > "$TEMPLATES_DIR/${THEME_NAME}.sh" << 'EOF'
#!/usr/bin/env bash
PRI="{{colors.primary.default.hex}}"
C1="${PRI:1}"
THEME_NAME="Noctalia-Tela-dark"
T_DIR="$HOME/.icons/$THEME_NAME"
BRANCH="color-${C1}"

if [[ ! -d "$T_DIR/.git" ]]; then
    git -C "$T_DIR" init -q
    git -C "$T_DIR" add -A
    git -C "$T_DIR" commit -q -m "original"
    git -C "$T_DIR" tag "original"
fi

if git -C "$T_DIR" show-ref --quiet "refs/heads/$BRANCH"; then
    git -C "$T_DIR" checkout -q "$BRANCH"
else
    git -C "$T_DIR" checkout -q main
    git -C "$T_DIR" checkout -q "original" -- .
    git -C "$T_DIR" add -A
    git -C "$T_DIR" commit -q --allow-empty -m "restored"
    git -C "$T_DIR" checkout -q -b "$BRANCH"

    find "$T_DIR" -name "*.svg" -path "*/places/*" -type f -print0 | xargs -0 sed -i \
        -e "s/\.ColorScheme-Highlight { color:#[0-9a-fA-F]\{6\}/\.ColorScheme-Highlight { color:#${C1}/gI" \
        -e "s/\.ColorScheme-Text { color:#[0-9a-fA-F]\{6\}/\.ColorScheme-Text { color:#${C1}/gI" \
        -e "s/fill=\"currentColor\"/fill=\"#${C1}\"/gI"

    git -C "$T_DIR" add -A
    git -C "$T_DIR" commit -q -m "$PRI"
fi

gtk-update-icon-cache -f -t "$T_DIR" 2>/dev/null
CURRENT=$(gsettings get org.gnome.desktop.interface icon-theme | tr -d "'")
if [[ "$CURRENT" == "$THEME_NAME" ]]; then
    gsettings set org.gnome.desktop.interface icon-theme "hicolor" 2>/dev/null
    sleep 0.3
    gsettings set org.gnome.desktop.interface icon-theme "$THEME_NAME" 2>/dev/null
else
    gsettings set org.gnome.desktop.interface icon-theme "$THEME_NAME" 2>/dev/null
fi

gio set ~/Escritorio metadata::custom-icon-name "user-desktop" 2>/dev/null || true
gio set ~/Desktop metadata::custom-icon-name "user-desktop" 2>/dev/null || true
EOF

# --- VINCULACIÓN CON EL ARCHIVO TOML ---
info "Registrando en user-templates.toml..."
sed -i "/\[templates.${THEME_NAME,,}\]/,+4d" "$NOCTALIA_DIR/user-templates.toml" 2>/dev/null || true
cat >> "$NOCTALIA_DIR/user-templates.toml" << EOF

[templates.${THEME_NAME,,}]
input_path  = "~/.config/noctalia/templates/${THEME_NAME}.sh"
output_path = "~/.cache/noctalia/${THEME_NAME}-apply.sh"
post_hook   = "bash ~/.cache/noctalia/${THEME_NAME}-apply.sh"
EOF

gsettings set org.gnome.desktop.interface icon-theme "$THEME_NAME"
gio set ~/Escritorio metadata::custom-icon-name "user-desktop" 2>/dev/null || true
gio set ~/Desktop metadata::custom-icon-name "user-desktop" 2>/dev/null || true
rm -rf "$TMP_DIR"

success "¡Instalación de $THEME_NAME completada!"
info "Refresca la Paleta de Colores en Noctalia para ver los cambios."
