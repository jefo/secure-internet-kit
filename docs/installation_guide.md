# Инструкция для техников

## На базе (до выезда)

1. Купить VPS (DigitalOcean/Hetzner)
2. Направить домен `vpn-XXX.yourdomain.com` на IP сервера
3. Прогнать `sudo bash scripts/harden/run.sh run`
4. Настроить `hosts.toml` и выпустить сертификат Let's Encrypt (шаг 09)

## У клиента (на выезде)

1. Уточнить список устройств (Windows/macOS/Android)
2. Сгенерировать учетные данные:
   ```bash
   sudo VPN_DOMAIN=vpn.example.com bash scripts/generate_client.sh client_name pro
   ```
3. Скопировать полученную ссылку `tt://....` или QR
4. Установить CLI-клиент или мобильное приложение
5. **Важно:** Проверить, что в Китае/РФ/других зонах с цензурой включен протокол QUIC (HTTP/3) — он быстрее и сложнее блокируется
