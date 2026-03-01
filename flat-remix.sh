#!/usr/bin/env bash
set -e

# Colores para la terminal
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[info]${NC} $1"; }
success() { echo -e "${GREEN}[ok]${NC} $1"; }
error()   { echo -e "${RED}[error]${NC} $1"; exit 1; }

# Rutas de trabajo (Local Share Icons)
THEME_NAME="Noctalia-Colloid"
REAL_FOLDER="Noctalia-Colloid-Dark"
ICONS_DIR="$HOME/.local/share/icons"
NOCTALIA_DIR="$HOME/.config/noctalia"
TEMPLATES_DIR="$NOCTALIA_DIR/templates"
CACHE_DIR="$HOME/.cache/noctalia"
THEME_DIR="$ICONS_DIR/$REAL_FOLDER"
TMP_DIR="/tmp/icon-install-colloid"

mkdir -p "$ICONS_DIR"
mkdir -p "$TEMPLATES_DIR"

clear
# Nuevo Arte ASCII solicitado
echo -e "${BLUE}"
echo "    _  __            __        ___              ________      __ "
echo "   / | / /___  _____/ /_____ _/ (_)___ _       / ____/ /___ _/ /_"
echo "  /  |/ / __ \/ ___/ __/ __ \`/ / / __ \`/_____/ /_  / / __ \`/ __/"
echo " / /|  / /_/ / /__/ /_/ /_/ / / / /_/ /_____/ __/ / / /_/ / /_  "
echo "/_/ |_/\____/\___/\__/\__,_/_/_/\__,_/     /_/   /_/\__,_/\__/  "
echo "                                                                "
echo -e "${NC}"

echo -e "${BLUE}=== GESTOR: $THEME_NAME (LOCAL MODE) ===${NC}"
echo "1) Instalar / Reparar en ~/.local/share/icons"
echo "2) LIMPIEZA TOTAL (Desinstalar)"
read -r -p "Selecciona una opción [1-2]: " OPT

if [ "$OPT" == "2" ]; then
    info "Eliminando rastro de configuraciones..."
    rm -rf "$THEME_DIR" "$TEMPLATES_DIR/${THEME_NAME}.sh"
    sed -i "/\[templates.${THEME_NAME,,}\]/,+4d" "$NOCTALIA_DIR/user-templates.toml" 2>/dev/null || true
    success "Sistema limpio."; exit 0
fi

# --- DESCARGA ---
info "Descargando base Colloid..."
rm -rf "$TMP_DIR" && mkdir -p "$TMP_DIR"
curl -fsSL "https://github.com/vinceliuice/Colloid-icon-theme/archive/refs/heads/main.zip" -o "$TMP_DIR/colloid.zip"
unzip -q "$TMP_DIR/colloid.zip" -d "$TMP_DIR"
CDIR=$(find "$TMP_DIR" -maxdepth 1 -type d -name "Colloid-icon-theme*")

# --- INSTALACIÓN OFICIAL ---
info "Ejecutando instalador en ruta local..."
bash "$CDIR/install.sh" -d "$ICONS_DIR" -n "$THEME_NAME" -t default -s default

# --- SNAPSHOT GIT (Obligatorio para el cambio de color) ---
info "Creando snapshot original..."
cd "$THEME_DIR"
rm -rf .git
git init -q
git add .
git commit -q -m "original"
git tag "original"

# --- SCRIPT APLICADOR DE COLOR (Template) ---
info "Creando template para Noctalia..."
cat > "$TEMPLATES_DIR/${THEME_NAME}.sh" << 'EOF'
#!/usr/bin/env bash
PRI="{{colors.primary.default.hex}}"
C1="${PRI:1}"
T_DIR="$HOME/.local/share/icons/Noctalia-Colloid-Dark"

# Restaurar iconos originales antes de aplicar nuevo color
git -C "$T_DIR" reset --hard -q original
git -C "$T_DIR" clean -fd -q

# Motor de color ultra-agresivo (Mezcla de Colloid + Flat Remix)
find "$T_DIR" -name "*.svg" -type f -print0 | xargs -0 sed -i -E \
    -e "s/#60c0f0/#${C1}/gI" \
    -e "s/#5294e2/#${C1}/gI" \
    -e "s/fill:#[0-9a-fA-F]{6}/fill:#${C1}/gI" \
    -e "s/fill=\"#[0-9a-fA-F]{6}\"/fill=\"#${C1}\"/gI" \
    -e "s/stop-color:#[0-9a-fA-F]{6}/stop-color:#${C1}/gI" \
    -e "s/stop-color=\"#[0-9a-fA-F]{6}\"/stop-color=\"#${C1}\"/gI" \
    -e "s/style=\"fill:#[0-9a-fA-F]{6}/style=\"fill:#${C1}/gI" \
    -e "s/currentColor/#${C1}/gI"

gtk-update-icon-cache -f -t "$T_DIR" 2>/dev/null
gsettings set org.gnome.desktop.interface icon-theme "hicolor"
sleep 0.3
gsettings set org.gnome.desktop.interface icon-theme "Noctalia-Colloid-Dark"
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

chmod +x "$TEMPLATES_DIR/${THEME_NAME}.sh"
gsettings set org.gnome.desktop.interface icon-theme "$REAL_FOLDER"
rm -rf "$TMP_DIR"

success "¡Instalación finalizada!"
info "Ya puedes aplicar tus colores desde Noctalia."
