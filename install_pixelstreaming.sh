#!/bin/bash
#===============================================================================
# SCRIPT: install_pixelstreaming.sh
# DESCR:  Enterprise Pixel Streaming Setup (Cloud/Hybrid + VR + AMD/NVIDIA Support)
# VER:    3.1.0
# AUTH:   Cline (updated)
#===============================================================================

set -euo pipefail

# Farben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

USER_NAME="uestream"
PROJECT_NAME="ue_gateway"
BASE_DIR="/home/${USER_NAME}/${PROJECT_NAME}"
NGINX_CONF="/etc/nginx/sites-available/${PROJECT_NAME}"

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[FEHLER/ERROR]${NC} $1"; exit 1; }
log_step()  { echo -e "${YELLOW}=== $1 ===${NC}"; }

# Root Check
if [[ $EUID -ne 0 ]]; then
   log_error "Script must be run as root (sudo)."
fi

# Language Selection with validation
log_step "Sprache wählen / Select Language"
echo "1) Deutsch"
echo "2) English"
while true; do
    read -p "Auswahl (1/2): " LANG_CHOICE
    case $LANG_CHOICE in
        1) LANG="DE"; log_info "Sprache: Deutsch"; break;;
        2) LANG="EN"; log_info "Language: English"; break;;
        *) log_warn "Ungültige Auswahl. Bitte 1 oder 2 eingeben / Invalid. Enter 1 or 2";;
    esac
done

# Text variables based on language
if [ "$LANG" = "DE" ]; then
    PROMPT_DOMAIN="Domainname (z.B. stream.firma.de): "
    PROMPT_EMAIL="Admin Email für SSL (z.B. it@firma.de): "
    MODE_PROMPT="Betriebsmodus wählen:\n1) Cloud (UE auf Server, GPU nötig)\n2) Hybrid (UE lokal, Server signaling only)"
    VR_PROMPT="VR/XR Support?\n1) Nein (Flat Screen)\n2) Ja (WebXR, hohe Last)"
    GPU_PROMPT="GPU Typ (Cloud only):\n1) NVIDIA\n2) AMD\n3) CPU/Other (Vulkan)"
    BINARY_PROMPT="Unreal Binary Name (z.B. MeinProjekt.sh): "
else
    PROMPT_DOMAIN="Domain name (e.g. stream.yourcompany.com): "
    PROMPT_EMAIL="Admin Email for SSL (e.g. it@yourcompany.com): "
    MODE_PROMPT="Select mode:\n1) Cloud (UE on server, GPU required)\n2) Hybrid (UE local, server signaling only)"
    VR_PROMPT="VR/XR support?\n1) No (Flat Screen)\n2) Yes (WebXR, high load)"
    GPU_PROMPT="GPU Type (Cloud only):\n1) NVIDIA\n2) AMD\n3) CPU/Other (Vulkan)"
    BINARY_PROMPT="Unreal Binary Name (e.g. MyProject.sh): "
fi

log_step "Konfiguration / Configuration"
read -p "$PROMPT_DOMAIN" DOMAIN
read -p "$PROMPT_EMAIL" EMAIL

echo -e "$MODE_PROMPT"
while true; do
    read -p "Choice (1/2): " MODE
    [[ "$MODE" =~ ^[1-2]$ ]] && break
    log_warn "Invalid. 1 or 2 / Ungültig. 1 oder 2"
done

GPU_TYPE=""
BINARY_NAME=""
if [[ "$MODE" == "1" ]]; then
    echo -e "$GPU_PROMPT"
    while true; do
        read -p "Choice (1-3): " GPU_TYPE
        [[ "$GPU_TYPE" =~ ^[1-3]$ ]] && break
        log_warn "Invalid. 1-3"
    done
    read -p "$BINARY_PROMPT" BINARY_NAME
    if [ -z "$BINARY_NAME" ]; then log_error "Binary name required for Cloud mode."; fi
fi

echo -e "$VR_PROMPT"
while true; do
    read -p "Choice (1/2): " VR_MODE
    [[ "$VR_MODE" =~ ^[1-2]$ ]] && break
    log_warn "Invalid. 1 or 2"
done

# 1. System Prep
log_step "System Update & Base Install"
apt-get update -qq && apt-get upgrade -y -qq
apt-get install -y git curl nginx certbot python3-certbot-nginx ufw unzip libvulkan1 mesa-vulkan-drivers vulkan-tools

# GPU Specific (Mode 1)
if [[ "$MODE" == "1" ]]; then
    if [[ "$GPU_TYPE" == "1" ]]; then
        log_warn "NVIDIA: Ensure drivers installed (nvidia-smi). Add PPA if needed."
        apt-get install -y nvidia-driver-535  # Example, adjust
    elif [[ "$GPU_TYPE" == "2" ]]; then
        log_info "AMD: Installing mesa-vulkan-drivers & firmware"
        apt-get install -y firmware-amd-graphics
    fi
fi

# Firewall
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh && ufw allow http && ufw allow https
ufw deny 8888  # Internal

# 2. User & Dirs
log_step "User & Dirs"
id "$USER_NAME" &>/dev/null || adduser --disabled-password --gecos "" "$USER_NAME"
mkdir -p "$BASE_DIR"/{SignalingWebServer,Build,Logs}
chown -R "$USER_NAME:$USER_NAME" "$BASE_DIR"

# 3. Node.js
log_step "Node.js LTS"
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs

# Signaling Placeholder
if [ ! -f "$BASE_DIR/SignalingWebServer/server.js" ]; then
    log_warn "SignalingWebServer missing! Copy from UE."
    echo "console.log('Copy real SignalingWebServer here');" > "$BASE_DIR/SignalingWebServer/server.js"
fi
chown -R "$USER_NAME:$USER_NAME" "$BASE_DIR/SignalingWebServer"

# 4. Services
log_step "Services"

# Signaling Service
cat > /etc/systemd/system/ue-signaling.service <<EOF
[Unit]
Description=UE Pixel Streaming Signaling
After=network.target
[Service]
Type=simple
User=$USER_NAME
Group=$USER_NAME
WorkingDirectory=$BASE_DIR/SignalingWebServer
ExecStart=/usr/bin/node server.js --port 8888 --public-ip $DOMAIN
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
[Install]
WantedBy=multi-user.target
EOF

if [[ "$MODE" == "1" ]]; then
    VR_PARAMS=""
    [[ "$VR_MODE" == "2" ]] && VR_PARAMS="-VR -PixelStreamingEncoderCodec=H264 -PixelStreamingBitrate=50000 -PixelStreamingFramerate=90 -UseVulkan"
    cat > /etc/systemd/system/ue-app.service <<EOF
[Unit]
Description=Unreal Engine App
After=network.target ue-signaling.service
Requires=ue-signaling.service
[Service]
Type=simple
User=$USER_NAME
Group=$USER_NAME
WorkingDirectory=$BASE_DIR/Build
ExecStart=$BASE_DIR/Build/$BINARY_NAME -RenderOffScreen -PixelStreamingURL=ws://127.0.0.1:8888 -ForceRes=1920x1080 -Windowed $VR_PARAMS
Restart=on-failure
RestartSec=10
Environment=DISPLAY=:0
NoNewPrivileges=true
PrivateTmp=true
[Install]
WantedBy=multi-user.target
EOF
    log_info "UE App service ready. Place $BINARY_NAME in $BASE_DIR/Build/"
else
    log_warn "Hybrid: Connect local UE to ws://$DOMAIN:8888"
fi

# 5. Nginx
log_step "Nginx"
cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    location /.well-known/acme-challenge/ { root /var/www/certbot; }
    location / { return 301 https://\$server_name\$request_uri; }
}
server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Permissions-Policy "xr-spatial-tracking=(self \"https://$DOMAIN\")" always;
    location / {
        proxy_pass http://127.0.0.1:8888;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
}
EOF
ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/$PROJECT_NAME
rm -f /etc/nginx/sites-enabled/default
nginx -t || log_error "Nginx config error"

# 6. SSL
log_step "SSL Cert"
certbot --nginx --agree-tos --redirect --email "$EMAIL" -d "$DOMAIN" || log_warn "Certbot failed, check DNS"

# 7. Final
log_step "Finalizing"
systemctl daemon-reload
systemctl enable --now ue-signaling
[[ "$MODE" == "1" ]] && systemctl enable ue-app
systemctl restart nginx

log_info "============================================================"
log_info "Success! https://$DOMAIN"
log_info "Mode: $([[ "$MODE" == "1" ]] && echo "Cloud" || echo "Hybrid") | VR: $([[ "$VR_MODE" == "2" ]] && echo "Yes" || echo "No")"
log_info "Upload files to $BASE_DIR"
log_info "Check logs: journalctl -u ue-signaling -f"
log_info "============================================================"