#!/usr/bin/env bash
set -e

# Colores terminal
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[info]${NC} $1"; }
success() { echo -e "${GREEN}[ok]${NC} $1"; }
error()   { echo -e "${RED}[error]${NC} $1"; exit 1; }

# Nombres y Rutas
THEME_BASE="Noctalia-Colloid"
REAL_FOLDER="Noctalia-Colloid-Dark"
ICONS_DIR="$HOME/.icons"
NOCTALIA_DIR="$HOME/.config/noctalia"
TEMPLATES_DIR="$NOCTALIA_DIR/templates"
THEME_DIR="$ICONS_DIR/$REAL_FOLDER"
TMP_DIR="/tmp/icon-install-colloid"

clear
# Arte ASCII solicitado
echo -e "${BLUE}"
echo "    ____                                ______    ____      _     __"
echo "   / __ \__  ______  ____ _____ ___  (_)____            / ____/___  / / /___  (_)___/ /"
echo "  / / / / / / / __ \/ __ \`/ __ \`__ \/ / ___/  ______   / /   / __ \/ / / __ \/ / __  / "
echo " / /_/ / /_/ / / / / /_/ / / / / / / / /__   /_____/  / /___/ /_/ / / / /_/ / / /_/ /  "
echo "/_____/\__, /_/ /_/\__,_/_/ /_/ /_/_/\___/            \____/\____/_/_/\____/_/\__,_/   "
echo "      /____/                                                                           "
echo -e "${NC}"

echo -e "${BLUE}=== GESTOR EXCLUSIVO: $THEME_BASE ===${NC}"
echo "1) Instalar / Reparar"
echo "2) Desinstalar Completamente"
read -r -p "Selecciona una opción [1-2]: " OPT < /dev/tty

# --- OPCIÓN 2: DESINSTALACIÓN ---
if [ "$OPT" == "2" ]; then
    info "Eliminando $THEME_BASE..."
    rm -rf "$THEME_DIR" "$ICONS_DIR/${THEME_BASE}-Light" "$TEMPLATES_DIR/${THEME_BASE}.sh"
    sed -i "/\[templates.${THEME_BASE,,}\]/,+4d" "$NOCTALIA_DIR/user-templates.toml" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "Adwaita"
    success "Desinstalación completa."; exit 0
fi

# --- OPCIÓN 1: INSTALACIÓN ---
info "Iniciando instalación de $THEME_BASE..."

# 1. Descarga limpia
rm -rf "$TMP_DIR" && mkdir -p "$TMP_DIR"
curl -fsSL "https://github.com/vinceliuice/Colloid-icon-theme/archive/refs/heads/main.zip" -o "$TMP_DIR/colloid.zip"
unzip -q "$TMP_DIR/colloid.zip" -d "$TMP_DIR"
CDIR=$(find "$TMP_DIR" -maxdepth 1 -type d -name "Colloid-icon-theme*")

# 2. Instalador Oficial
bash "$CDIR/install.sh" -d "$ICONS_DIR" -n "$THEME_BASE" -t default -s default

# 3. Snapshot de Git (Para permitir cambios de color infinitos)
cd "$THEME_DIR"
rm -rf .git
git init -q && git add . && git commit -q -m "original" && git tag -f "original"

# 4. Plantilla de Noctalia (Motor de color dinámico corregido)
info "Creando plantilla de aplicación..."
mkdir -p "$TEMPLATES_DIR"
cat > "$TEMPLATES_DIR/${THEME_BASE}.sh" << 'EOF'
#!/usr/bin/env bash
PRI="{{colors.primary.default.hex}}"
C1="${PRI:1}"
T_DIR="$HOME/.icons/Noctalia-Colloid-Dark"

# Hard Reset para limpiar colores previos antes de aplicar el nuevo
git -C "$T_DIR" reset --hard -q original
git -C "$T_DIR" clean -fd -q

# Reemplazo de color maestro (Carpetas, degradados y apps)
find "$T_DIR" -name "*.svg" -type f -print0 | xargs -0 sed -i -E \
    -e "s/#60c0f0/#${C1}/gI" \
    -e "s/#5294e2/#${C1}/gI" \
    -e "s/fill:#[0-9a-fA-F]{6}/fill:#${C1}/gI" \
    -e "s/stop-color:#[0-9a-fA-F]{6}/stop-color:#${C1}/gI" \
    -e "s/style=\"fill:#[0-9a-fA-F]{6}/style=\"fill:#${C1}/gI" \
    -e "s/currentColor/#${C1}/gI"

gtk-update-icon-cache -f -t "$T_DIR" 2>/dev/null
gsettings set org.gnome.desktop.interface icon-theme "hicolor"
sleep 0.2
gsettings set org.gnome.desktop.interface icon-theme "Noctalia-Colloid-Dark"
EOF

# 5. Registro en user-templates.toml (Adaptado para que Noctalia lo reconozca)
info "Registrando en user-templates.toml..."
sed -i "/\[templates.${THEME_BASE,,}\]/,+4d" "$NOCTALIA_DIR/user-templates.toml" 2>/dev/null || true
cat >> "$NOCTALIA_DIR/user-templates.toml" << EOF

[templates.${THEME_BASE,,}]
input_path  = "~/.config/noctalia/templates/${THEME_BASE}.sh"
output_path = "~/.cache/noctalia/${THEME_BASE}-apply.sh"
post_hook   = "bash ~/.cache/noctalia/${THEME_BASE}-apply.sh"
EOF

# 6. Finalización y Aplicación inicial
chmod +x "$TEMPLATES_DIR/${THEME_BASE}.sh"
gsettings set org.gnome.desktop.interface icon-theme "$REAL_FOLDER"
rm -rf "$TMP_DIR"

success "¡Instalación de $THEME_BASE completada!"
info "Ya puedes cambiar el color en Noctalia para ver los cambios reflejados."
