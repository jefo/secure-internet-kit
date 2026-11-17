# Стандарты безопасности VPS — Secure Internet Kit

## Требования к безопасности

### Цель

Обеспечить **базовый уровень защиты** нового VPS от распространённых атак:
- Брутфорс SSH ботами
- Сканирование портов
- Эксплуатация открытых сервисов
- DNS-утечки
- Простые DDoS-атаки
- Доступ к файлам конфигурации

**Не цель:** защита от APT-групп, nation-state акторов, физической компрометации сервера.

---

## R1. Доступ к серверу

| № | Требование | Приоритет |
|---|-----------|-----------|
| R1.1 | SSH только по ключам, парольная аутентикация **отключена** | 🔴 Критично |
| R1.2 | SSH на нестандартном порту (не 22) | 🔴 Критично |
| R1.3 | Root-логин через SSH только по ключу (`prohibit-password`) | 🔴 Критично |
| R1.4 | Используется отдельный пользователь с `sudo` | 🔴 Критично |
| R1.5 | Fail2ban установлен и настроен на SSH | 🟡 Важно |
| R1.6 | SSH ключи с passphrase (не голые) | 🟡 Важно |

## R2. Сетевой экран (Firewall)

| № | Требование | Приоритет |
|---|-----------|-----------|
| R2.1 | По умолчанию **все входящие соединения закрыты** | 🔴 Критично |
| R2.2 | Открыты только: SSH (нестандартный порт), 443/tcp, 443/udp | 🔴 Критично |
| R2.3 | IPv6 firewall настроен (или IPv6 отключён) | 🟡 Важно |
| R2.4 | FORWARD chain закрыт (сервер не роутер) | 🟡 Важно |

## R3. Обновления и патчи

| № | Требование | Приоритет |
|---|-----------|-----------|
| R3.1 | `unattended-upgrades` включён для security-пакетов | 🟡 Важно |
| R3.2 | Ядро обновляется и сервер перезагружается при необходимости | 🟡 Важно |

## R4. Сервисы и порты

| № | Требование | Приоритет |
|---|-----------|-----------|
| R4.1 | Нет слушающих сервисов на `0.0.0.0` кроме TrustTunnel | 🔴 Критично |
| R4.2 | Если включён reverse-proxy для приманки — он на `127.0.0.1` | 🟡 Важно |
| R4.3 | Docker не установлен (если не используется) | 🟡 Важно |

## R5. Файлы и логи

| № | Требование | Приоритет |
|---|-----------|-----------|
| R5.1 | Файлы конфигурации TrustTunnel доступны только `root` | 🔴 Критично |
| R5.2 | `credentials.toml` — режим `600`, владелец `root` | 🔴 Критично |
| R5.3 | Логи ротируются (logrotate настроен) | 🟡 Важно |
| R5.4 | Логи не пишут IP-адреса клиентов (или пишут на уровне `error`) | 🟡 Важно |

## R6. DNS и утечки

| № | Требование | Приоритет |
|---|-----------|-----------|
| R6.1 | На сервере нет открытых DNS-резолверов | 🔴 Критично |
| R6.2 | Клиентский конфиг содержит DoH/DoT upstreams | 🟡 Важно |

## R7. TLS и сертификаты

| № | Требование | Приоритет |
|---|-----------|-----------|
| R7.1 | Сертификаты от publicly trusted CA (Let's Encrypt) | 🔴 Критично |
| R7.2 | Автообновление сертификатов + SIGHUP TrustTunnel | 🟡 Важно |
| R7.3 | Self-signed сертификаты **не используются** в продакшене | 🟡 Важно |

## R8. Пользователи TrustTunnel

| № | Требование | Приоритет |
|---|-----------|-----------|
| R8.1 | У каждого клиента уникальный username/password | 🔴 Критично |
| R8.2 | При компрометации — пароль немедленно отзывается | 🔴 Критично |
| R8.3 | `rules.toml` содержит правила фильтрации (deny для подозрительных IP) | 🟡 Важно |

---

## Автоматизированная настройка

Все шаги из чек-листа реализованы в скриптах `scripts/harden/`. Каждый скрипт поддерживает два режима:

- `--check` — проверяет, применён ли уже этот шаг (возвращает 0 если всё ок, 1 если нужно настраивать)
- `--run` — применяет настройки (идемпотентно — безопасно запускать повторно)

### Мастер-скрипт (рекомендуемый способ)

```bash
# Посмотреть статус всех шагов
sudo bash scripts/harden/run.sh status

# Полный аудит безопасности
sudo bash scripts/harden/run.sh check

# Применить все ожидающие шаги (с проверкой зависимостей)
sudo bash scripts/harden/run.sh run

# Применить один конкретный шаг
sudo bash scripts/harden/run.sh run 03
```

### Отдельные скрипты

```bash
# Проверить конкретный шаг
sudo bash scripts/harden/step03_setup_firewall.sh --check

# Применить конкретный шаг
sudo bash scripts/harden/step03_setup_firewall.sh --run
```

### Переменные окружения (кастомизация)

| Переменная | По умолчанию | Описание |
|------------|-------------|----------|
| `SSH_PORT` | `2222` | Порт SSH |
| `ADMIN_USER` | `vpnadmin` | Имя админ-пользователя |
| `SSH_PUBKEY` | _(пусто)_ | SSH публичный ключ (для шага 01) |
| `INSTALL_DIR` | `/opt/trusttunnel` | Каталог установки TrustTunnel |
| `TLS_DOMAIN` | _(пусто)_ | Домен для Let's Encrypt (шаг 09) |
| `TLS_EMAIL` | _(пусто)_ | Email для Let's Encrypt (шаг 09) |
| `TT_USERNAME` | `admin` | Имя пользователя TrustTunnel (шаг 08) |
| `TT_PASSWORD` | _(авто)_ | Пароль TrustTunnel (генерируется если не задан) |

### Полная автоматическая установка одной командой

```bash
# Всё сразу: пользователь, SSH, фаервол, TrustTunnel, TLS
export SSH_PORT=2222
export ADMIN_USER=vpnadmin
export SSH_PUBKEY="ssh-ed25519 AAAA... ваш_ключ"
export TLS_DOMAIN=cdn.web-assets-provider.com
export TLS_EMAIL=admin@example.com

sudo bash scripts/harden/run.sh run
```

---

## Ручной чек-лист первоначальной настройки

> **Примечание:** Ручная настройка ниже нужна только если автоматические скрипты по какой-то причине не подходят. Используйте `scripts/harden/run.sh run` для типичного сценария.

### Шаг 1: Создаём пользователя

```bash
# Создать пользователя
adduser vpnadmin
usermod -aG sudo vpnadmin

# Переключиться на нового пользователя
su - vpnadmin
```

### Шаг 2: Копируем SSH ключ

```bash
# На локальной машине (НЕ на сервере):
ssh-copy-id -p 2222 vpnadmin@<server_ip>

# Или вручную:
mkdir -p ~/.ssh
chmod 700 ~/.ssh
# Вставить публичный ключ в ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### Шаг 3: Меняем порт SSH

```bash
sudo nano /etc/ssh/sshd_config
```

Находим и меняем:

```
Port 2222
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
MaxAuthTries 3
LoginGraceTime 20
```

Перезапускаем:

```bash
sudo systemctl restart sshd
# НЕ ЗАКРЫВАЕМ текущую сессию! Проверяем в новом окне:
ssh -p 2222 vpnadmin@<server_ip>
```

### Шаг 4: Настраиваем UFW

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 2222/tcp    # SSH (ваш порт)
sudo ufw allow 443/tcp     # TrustTunnel
sudo ufw allow 443/udp     # TrustTunnel QUIC
sudo ufw --force enable
sudo ufw status verbose
```

### Шаг 5: Устанавливаем Fail2ban

```bash
sudo apt install -y fail2ban
```

```bash
sudo nano /etc/fail2ban/jail.local
```

```ini
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 3
banaction = ufw

[sshd]
enabled = true
port = 2222
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 24h
```

```bash
sudo systemctl enable --now fail2ban
sudo fail2ban-client status sshd
```

### Шаг 6: Включаем автоматические обновления

```bash
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

Проверяем:

```bash
cat /etc/apt/apt.conf.d/20auto-upgrades
# Должно содержать:
# APT::Periodic::Update-Package-Lists "1";
# APT::Periodic::Unattended-Upgrade "1";
```

### Шаг 7: Ограничиваем права файлов TrustTunnel

После установки TrustTunnel:

```bash
# Установка владельца
sudo chown -R root:root /opt/trusttunnel/

# Файлы конфигурации — только root
sudo chmod 600 /opt/trusttunnel/credentials.toml
sudo chmod 600 /opt/trusttunnel/rules.toml
sudo chmod 644 /opt/trusttunnel/vpn.toml
sudo chmod 644 /opt/trusttunnel/hosts.toml

# Бинарник — только root может читать/запускать
sudo chmod 700 /opt/trusttunnel/trusttunnel_endpoint
```

### Шаг 8: Отключаем ненужные сервисы

```bash
# Смотрим что слушает
sudo ss -tlnp

# Отключаем всё лишнее (примеры)
sudo systemctl disable --now apache2   # если не нужен
sudo systemctl disable --now postfix   # если не нужен
sudo systemctl disable --now docker    # если не нужен
```

### Шаг 9: sysctl hardening

```bash
sudo nano /etc/sysctl.d/99-hardening.conf
```

```conf
# Защита от IP-спуфинга
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Игнорируем ICMP redirect
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0

# Не отвечаем на ping broadcast
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Защита от SYN-flood
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048

# Отключаем IPv6 (если не используется)
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1

# Логируем подозрительные пакеты
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
```

Применяем:

```bash
sudo sysctl --system
```

### Шаг 10: Лимит подключений (защита от примитивного DDoS)

```bash
sudo nano /etc/iptables/rules.v4
# Или добавить через UFW before.rules:

# Ограничение новых SSH-соединений: 3 в минуту
-A ufw-before-input -p tcp --dport 2222 -m state --state NEW -m recent --set
-A ufw-before-input -p tcp --dport 2222 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 -j DROP

# Ограничение 443 порта (от новых соединений если слишком часто)
-A ufw-before-input -p tcp --dport 443 -m state --state NEW -m recent --set
-A ufw-before-input -p tcp --dport 443 -m state --state NEW -m recent --update --seconds 10 --hitcount 50 -j DROP
```

> **Примечание:** Пороги настраиваются под реальный трафик.

---

## Скрипт автоматической первоначальной настройки

Для удобства всё вышеописанное можно выполнить одним скриптом:

```bash
#!/bin/bash
# scripts/harden_vps.sh
# Запускать сразу после создания VPS под root
# После выполнения — логин только по SSH ключу на порту 2222
set -e

SSH_PORT=2222
ADMIN_USER="vpnadmin"

echo "=== [1/8] Обновление пакетов ==="
apt update && apt upgrade -y

echo "=== [2/8] Создаём админ-пользователя ==="
if ! id "$ADMIN_USER" &>/dev/null; then
    adduser --disabled-password --gecos "" $ADMIN_USER
    usermod -aG sudo $ADMIN_USER
    echo "Пользователь $ADMIN_USER создан. НЕ забудьте установить пароль: passwd $ADMIN_USER"
fi

echo "=== [3/8] Копируем SSH ключ (убедитесь что ~/.ssh/authorized_keys существует) ==="
# Ключ должен быть скопирован ДО отключения парольного входа

echo "=== [4/8] Настраиваем SSH ==="
sed -i "s/^#\?Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/^#\?PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i "s/^#\?PasswordAuthentication .*/PasswordAuthentication no/" /etc/ssh/sshd_config
sed -i "s/^#\?PubkeyAuthentication .*/PubkeyAuthentication yes/" /etc/ssh/sshd_config
sed -i "s/^#\?X11Forwarding .*/X11Forwarding no/" /etc/ssh/sshd_config
# Добавляем если нет
grep -q "MaxAuthTries" /etc/ssh/sshd_config || echo "MaxAuthTries 3" >> /etc/ssh/sshd_config
grep -q "LoginGraceTime" /etc/ssh/sshd_config || echo "LoginGraceTime 20" >> /etc/ssh/sshd_config

systemctl restart sshd
echo "SSH перезапущен на порт $SSH_PORT. Проверьте доступ в новом окне!"

echo "=== [5/8] Настраиваем UFW ==="
ufw default deny incoming
ufw default allow outgoing
ufw allow $SSH_PORT/tcp
ufw allow 443/tcp
ufw allow 443/udp
ufw --force enable

echo "=== [6/8] Устанавливаем Fail2ban ==="
apt install -y fail2ban
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 3
banaction = ufw

[sshd]
enabled = true
port = $SSH_PORT
logpath = /var/log/auth.log
maxretry = 3
bantime = 24h
EOF
systemctl enable --now fail2ban

echo "=== [7/8] Автоматические обновления ==="
apt install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

echo "=== [8/8] Sysctl hardening ==="
cat > /etc/sysctl.d/99-hardening.conf <<'EOF'
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
EOF
sysctl --system

echo ""
echo "=== ГОТОВО ==="
echo "1. Установите пароль для $ADMIN_USER: passwd $ADMIN_USER"
echo "2. Проверьте SSH: ssh -p $SSH_PORT $ADMIN_USER@$(curl -s ifconfig.me)"
echo "3. НЕ ЗАКРЫВАЙТЕ текущую сессию пока не убедитесь что новая работает"
echo "4. После проверки — установите TrustTunnel через deploy.sh"
```

---

## Периодические проверки (Monthly Checklist)

### Автоматическая проверка (рекомендуемый способ)

```bash
# Полный аудит всех 10 шагов безопасности
sudo bash scripts/harden/run.sh check

# Вывод покажет PASS/FAIL по каждому шагу
```

### Ручная проверка

Каждый месяц проверять:

| Проверка | Команда | Ожидаемый результат |
|----------|---------|---------------------|
| Открытые порты | `sudo ss -tlnp` | Только 443/tcp, 443/udp, SSH |
| Забаненные IP | `sudo fail2ban-client status sshd` | Есть забаненные — хорошо |
| Обновления | `apt list --upgradable` | Только несекьюрити пакеты |
| Права на credentials | `ls -la /opt/trusttunnel/credentials.toml` | `-rw------- root root` |
| Активные пользователи TrustTunnel | `cat /opt/trusttunnel/credentials.toml` | Только активные клиенты |
| Сертификат валиден | `openssl x509 -checkend 2592000 -in <cert>` | Не истекает в ближайший месяц |
| Логи на аномалии | `sudo journalctl -u trusttunnel --since "1 week ago" | grep -i error` | Нет массовых auth failure |

---

## См. также

- [infrastructure.md](infrastructure.md) — Выбор VPS, сетевая безопасность
- [CONFIGURATION.md](../CONFIGURATION.md) — Конфигурация TrustTunnel
- [business_model.md](business_model.md) — Модель монетизации
