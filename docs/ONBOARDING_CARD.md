# Карта подключения клиента

## Клиент: ____________________  Тариф: PRO / LITE  Дата: __________

---

## 📱 ANDROID (2 минуты)

1. Установи приложение: **TrustTunnel** из Play Store
2. Отсканируй QR → https://trusttunnel.org/qr.html#tt=
3. Нажми «Подключиться»
4. Проверь: открой ifconfig.me в браузере → IP должен быть **YOUR_SERVER_IP**

| Поле | Значение (если вручную) |
|------|--------------------------|
| Адрес | `vpn.example.com` |
| Порт | `443` |
| Пользователь | _см. строку выше_ |
| Пароль | _см. строку выше_ |

---

## 💻 WINDOWS (5 минут)

**Нужно:** права Администратора, флешка с файлами или интернет.

### Вариант A: Флешка (без интернета)

```
1. Вставить флешку
2. Открыть папку Secure Internet Kit
3. ПКМ по install.bat → Запуск от имени Администратора
4. Готово — VPN в системном трее
```

### Вариант B: PowerShell (если есть интернет)

Запустить PowerShell от имени Администратора:

```powershell
# Одна команда — скачать, установить, запустить как службу
iwr -Uri "https://raw.githubusercontent.com/TrustTunnel/TrustTunnelClient/releases/latest/download/trusttunnel_client-x86_64-pc-windows-msvc.zip" -OutFile "$env:TEMP\tt.zip"
Expand-Archive "$env:TEMP\tt.zip" -Dest "C:\Program Files\Secure Internet Kit" -Force
```

Дальше: настроить конфиг через setup_wizard и запустить службу.

### Проверка на Windows

```powershell
Get-Service TrustTunnelClient          # статус службы
curl ifconfig.me                        # должен показать IP VPS
```

---

## 🐧 LINUX (5 минут)

```bash
# Установка
curl -fsSL https://raw.githubusercontent.com/TrustTunnel/TrustTunnelClient/refs/heads/master/scripts/install.sh | sh -s -

# Создать конфиг (замени логин/пароль)
cd /opt/trusttunnel_client/
sudo ./setup_wizard --mode non-interactive \
    --address vpn.example.com:443 \
    --hostname vpn.example.com \
    --creds ЛОГИН:ПАРОЛЬ \
    --settings trusttunnel_client.toml

# Запустить
sudo ./trusttunnel_client -c trusttunnel_client.toml
```

---

## 🚨 Если не работает

| Симптом | Решение |
|---------|---------|
| «Сервер недоступен» | Проверить интернет у клиента, открыть vpn.example.com в браузере |
| «Ошибка авторизации» | Проверить логин/пароль. Заново сгенерировать на сервере |
| Подключается, но интернета нет | Перезагрузить устройство |
| Банк не открывается | Добавить домен банка в exclusions, перевыпустить конфиг |

Сервер: `ssh root@YOUR_SERVER_IP`
Сгенерировать нового клиента: `sudo bash /opt/trusttunnel/scripts/generate_client.sh <имя> pro`
