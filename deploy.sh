#!/bin/bash
# ==============================================================================
# Script Deployment BaknusChat Web (Docker & Docker Compose)
# Domain: web.baknuschat.smkbn666.sch.id
# ==============================================================================

set -e

DOMAIN="web.baknuschat.smkbn666.sch.id"
CONTAINER_PORT=8080

echo "🚀 Memulai proses deployment BaknusChat Web untuk $DOMAIN..."

# 1. Periksa ketersediaan Docker & Docker Compose
if ! command -v docker &> /dev/null; then
    echo "⚠️ Docker belum terinstall. Menginstall Docker..."
    sudo apt update
    sudo apt install -y ca-certificates curl gnupg lsb-release
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    echo "✅ Docker berhasil terinstall."
fi

# 2. Build Flutter Web jika belum ada atau diperbarui
if [ ! -d "build/web" ]; then
    echo "📦 Folder build/web tidak ditemukan. Membangun Flutter Web..."
    if command -v flutter &> /dev/null; then
        flutter build web --release --pwa-strategy=none
    else
        echo "❌ Error: Flutter SDK tidak ditemukan di server dan folder build/web belum tersedia."
        echo "Silakan jalankan 'flutter build web --release' di lokal lalu upload folder build/web ke server."
        exit 1
    fi
fi

# 3. Memastikan service Docker berjalan
echo "⚙️ Memastikan Docker service aktif..."
sudo systemctl start docker || true
sudo systemctl enable docker || true

# 4. Jalankan Docker Compose
echo "🐳 Menjalankan container Docker dengan Docker Compose..."
sudo docker compose up -d --build

echo "✅ Container BaknusChat Web berhasil berjalan pada port $CONTAINER_PORT."

# 4. Opsi Konfigurasi Reverse Proxy Nginx & SSL Certbot di Host
echo ""
read -p "Apakah Anda ingin mengonfigurasi Nginx Host & Let's Encrypt SSL (HTTPS) secara otomatis? (y/n): " SSL_CONF

if [[ "$SSL_CONF" =~ ^[Yy]$ ]]; then
    echo "🌐 Menginstall Nginx Host & Certbot..."
    sudo apt update
    sudo apt install -y nginx certbot python3-certbot-nginx

    NGINX_CONF="/etc/nginx/sites-available/baknuschat-web"
    
    echo "📝 Membuat konfigurasi Nginx Reverse Proxy..."
    sudo bash -c "cat > $NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$CONTAINER_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    sudo ln -sf /etc/nginx/sites-available/baknuschat-web /etc/nginx/sites-enabled/
    sudo nginx -t
    sudo systemctl reload nginx

    echo "🔒 Mengaktifkan SSL HTTPS dengan Certbot..."
    sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@smkbn666.sch.id || {
        echo "⚠️ Certbot otomatis gagal. Anda bisa menjalankan 'sudo certbot --nginx -d $DOMAIN' secara manual nanti."
    }

    echo "🎉 SSL HTTPS berhasil dikonfigurasi!"
fi

echo "=============================================================================="
echo "✨ Deployment Selesai! Aplikasi Anda siap diakses di:"
echo "👉 http://$DOMAIN (atau https://$DOMAIN)"
echo "=============================================================================="
