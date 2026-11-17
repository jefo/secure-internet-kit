#!/bin/bash
# Secure Internet Kit Cert Renewal Hook

echo "--- Starting Certbot Renewal ---"
certbot renew --quiet

# Если сертификат обновился, Certbot положит новые файлы. 
# Нам нужно отправить сигнал SIGHUP процессу, чтобы он перечитал конфиги без разрыва сессий.
PID=$(pidof trusttunnel_endpoint)

if [ -n "$PID" ]; then
    kill -HUP $PID
    echo "Signal SIGHUP sent to TrustTunnel (PID: $PID). Certificates reloaded."
else
    echo "TrustTunnel is not running. Starting service..."
    systemctl start trusttunnel
fi
