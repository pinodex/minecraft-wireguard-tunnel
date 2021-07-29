#!/bin/bash

if [ "$EUID" -ne 0 ]
then
  echo "Please run script as root."
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y wireguard sslh nginx nginx-extras

WG_SERVER_PRIVATE_KEY=$(wg genkey)
WG_SERVER_PUBLIC_KEY=$(echo "$WG_SERVER_PRIVATE_KEY" | wg pubkey)

WG_CLIENT_PRIVATE_KEY=$(wg genkey)
WG_CLIENT_PUBLIC_KEY=$(echo "$WG_CLIENT_PRIVATE_KEY" | wg pubkey)

cat <<EOT > /etc/wireguard/wg0.conf
[Interface]
PrivateKey = $WG_SERVER_PRIVATE_KEY
Address = 10.69.69.1/30
ListenPort = 42069

[Peer]
PublicKey = $WG_CLIENT_PUBLIC_KEY
AllowedIPs = 10.69.69.2/32
EOT

cat <<EOT
[Interface]
PrivateKey = $WG_CLIENT_PRIVATE_KEY
Address = 10.69.69.2/30

[Peer]
PublicKey = $WG_SERVER_PUBLIC_KEY
AllowedIPs = 10.69.69.1/32
Endpoint = IP:42069
PersistentKeepalive = 25
EOT

cat <<EOT > /etc/default/sslh
DAEMON=/usr/sbin/sslh
DAEMON_OPTS="--user sslh --listen 0.0.0.0:25565 --anyprot 10.69.69.2:25565 --pidfile /var/run/sslh/sslh.pid"
EOT

cat <<EOT > /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
pid /run/nginx.pid;

load_module /usr/lib/nginx/modules/ngx_stream_module.so;

events {
  worker_connections 1024;
}

stream {
  server {
    listen 24454 udp;
    proxy_pass 10.69.69.2:24454;
  }
}
EOT

systemctl restart wg-quick@wg0
systemctl restart sslh
systemctl restart nginx
