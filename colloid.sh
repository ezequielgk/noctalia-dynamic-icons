#!/usr/bin/env bash
set -e

# Colores para la terminal
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[info]${NC} $1"; }
success() { echo -e "${GREEN}[ok]${NC} $1"; }
error()   { echo -e "${RED}[error]${NC} $1"; exit 1; }

# Rutas de trabajo
THEME_NAME="Noctalia-Colloid"
ICONS_DIR="$HOME/.icons"
NOCTALIA_DIR="$HOME/.config/noctalia"
TEMPLATES_DIR="$NOCTALIA_DIR/templates"
CACHE_DIR="$HOME/.cache/noctalia"
THEME_DIR="$ICONS_DIR/$THEME_NAME"
TMP_DIR="/tmp/icon-install-colloid"

clear
echo -e "${BLUE}"
echo "    ____                                ______    ____      _     __"
echo "   / __ \__  ______  ____ _____ ___  (_)____            / ____/___  / / /___  (_)___/ /"
echo "  / / / / / / / __ \/ __ \`/ __ \`__ \/ / ___/  ______   / /   / __ \/ / / __ \/ / __  / "
echo " / /_/ / /_/ / / / / /_/ / / / / / / / /__   /_____/  / /___/ /_/ / / / /_/ / / /_/ /  "
echo "/_____/\__, /_/ /_/\__,_/_/ /_/ /_/_/\___/            \____/\____/_/_/\____/_/\__,_/   "
echo "      /____/                                                                           "
echo -e "${NC}"

echo -e "${BLUE}=== INSTALADOR EXCLUSIVO: $THEME_NAME ===${NC}"
echo "1) Instalar $THEME_NAME"
echo "2) LIMPIEZA TOTAL"
read -r -p "Selecciona una opción [1-2]: " OPT < /dev/tty

if [ "$OPT" == "2" ]; then
    info "Limpiando instalación de $THEME_NAME..."
    rm -rf "$THEME_DIR" "$ICONS_DIR/${THEME_NAME}-Dark" "$TEMPLATES_DIR/${THEME_NAME}.sh" "$CACHE_DIR/${THEME_NAME}-apply.sh"
    sed -i "/\[templates.${THEME_NAME,,}\]/,+4d" "$NOCTALIA_DIR/user-templates.toml" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "Adwaita"
    success "Limpieza completa."; exit 0
fi

# --- DESCARGA ---
info "Descargando repositorio original de Colloid..."
rm -rf "$TMP_DIR" && mkdir -p "$TMP_DIR"
curl -fsSL "https://github.com/vinceliuice/Colloid-icon-theme/archive/refs/heads/main.zip" -o "$TMP_DIR/colloid.zip"
unzip -q "$TMP_DIR/colloid.zip" -d "$TMP_DIR"
CDIR=$(find "$TMP_DIR" -maxdepth 1 -type d -name "Colloid-icon-theme*")

# --- INSTALACIÓN OFICIAL ---
info "Ejecutando instalador oficial de Colloid..."
bash "$CDIR/install.sh" -d "$ICONS_DIR" -n "$THEME_NAME" -t default -s default

if [ -d "$ICONS_DIR/${THEME_NAME}-Dark" ]; then
    rm -rf "$THEME_DIR"
    mv "$ICONS_DIR/${THEME_NAME}-Dark" "$THEME_DIR"
    rm -rf "$ICONS_DIR/${THEME_NAME}-Light" 2>/dev/null || true
else
    error "Error: El instalador de Colloid no creó la carpeta esperada."
fi

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
THEME_NAME="Noctalia-Colloid"
T_DIR="$HOME/.icons/$THEME_NAME"
BRANCH="color-${C1}"

git -C "$T_DIR" checkout -q original -- .
git -C "$T_DIR" checkout -b "$BRANCH" 2>/dev/null || git -C "$T_DIR" checkout -q "$BRANCH"

# REEMPLAZO MAESTRO PARA DEGRADADOS
find "$T_DIR" -name "*.svg" -type f -print0 | xargs -0 sed -i -E \
    -e "s/#60c0f0/#${C1}/gI" \
    -e "s/fill:#[0-9a-fA-F]{6}/fill:#${C1}/gI" \
    -e "s/stop-color:#[0-9a-fA-F]{6}/stop-color:#${C1}/gI" \
    -e "s/style=\"fill:#[0-9a-fA-F]{6}/style=\"fill:#${C1}/gI"

gtk-update-icon-cache -f -t "$T_DIR" 2>/dev/null
gsettings set org.gnome.desktop.interface icon-theme "hicolor"
sleep 0.3
gsettings set org.gnome.desktop.interface icon-theme "$THEME_NAME"
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
rm -rf "$TMP_DIR"

success "¡Instalación de $THEME_NAME completada!"
info "Refresca la Paleta de Colores en Noctalia para ver los cambios."
