#!/bin/bash

set -e

# Update and install necessary packages
sudo apt update
sudo apt install -y docker.io docker-compose nginx openssl git

# Clone the repository
if [ ! -d /var/www/my_flask_app ]; then
  git clone https://github.com/yourusername/my_flask_app.git /var/www/my_flask_app
fi

# Navigate to the application directory
cd /var/www/my_flask_app

# Build and run the Docker container
docker-compose down
docker-compose up -d --build

# Generate self-signed SSL certificate
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/nginx-selfsigned.key \
  -out /etc/ssl/certs/nginx-selfsigned.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/OU=Department/CN=techmart.com"

# Create a strong Diffie-Hellman group
sudo openssl dhparam -out /etc/nginx/dhparam.pem 2048

# Configure Nginx
sudo tee /etc/nginx/sites-available/default > /dev/null <<EOL
server {
    listen 80;
    server_name techmart.com www.techmart.com;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name techmart.com www.techmart.com;

    ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
    ssl_dhparam /etc/nginx/dhparam.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305';

    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;
    ssl_session_tickets off;

    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

# Restart Nginx
sudo systemctl restart nginx

echo "Deployment completed successfully."
