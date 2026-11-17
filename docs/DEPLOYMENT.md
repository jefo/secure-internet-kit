# Руководство по деплою на VPS

Есть **три способа** запустить харденинг и установку TrustTunnel на удалённом сервере.

---

## Способ 1: SCP + запуск вручную (самый простой)

Если у вас уже есть SSH-доступ к свежему VPS:

```bash
# 1. Закачать скрипты на сервер
scp -r scripts/harden/ root@<server_ip>:/tmp/harden/

# 2. Зайти на сервер
ssh root@<server_ip>

# 3. Проверить статус
sudo bash /tmp/harden/run.sh status

# 4. Запустить всё
sudo bash /tmp/harden/run.sh run
```

**Плюсы:** Не нужен ни git, ни Ansible. Просто копируете файлы.

**Минусы:** Ручные действия, нужно дважды логиниться.

---

## Способ 2: Ansible (рекомендуемый для повторного использования)

Если у вас есть `inventory.ini` с данными сервера:

```bash
# Установить Ansible
sudo apt install ansible   # или: pip install ansible

# Проверить связь
ansible -i inventory.ini vpn_servers -m ping

# Задеплоить всё
ansible-playbook -i inventory.ini deploy.yml \
  --extra-vars "ssh_pubkey='$(cat ~/.ssh/id_ed25519.pub)'"

# С кастомными параметрами
ansible-playbook -i inventory.ini deploy.yml \
  --extra-vars "ssh_pubkey='$(cat ~/.ssh/id_ed25519.pub)' ssh_port=3333 admin_user=myadmin"

# Только конкретные шаги
ansible-playbook -i inventory.ini deploy.yml \
  --extra-vars "ssh_pubkey='$(cat ~/.ssh/id_ed25519.pub)'" \
  --tags step01,step02,step03
```

### inventory.ini пример

```ini
[vpn_servers]
203.0.113.50 ansible_user=root ansible_ssh_private_key_file=~/.ssh/id_ed25519

# Или с паролем (только для первичной настройки):
# 203.0.113.50 ansible_user=root ansible_password=yourpassword
```

**Плюсы:** Полностью автоматизировано, можно деплоить на несколько серверов, идемпотентно.

**Минусы:** Нужен Ansible на локальной машине.

---

## Способ 3: One-liner curl (для публичного репозитория)

Если репозиторий публичный на GitHub — одной командой с локальной машины на сервер:

```bash
# Запустить скрипт на удалённом сервере через SSH
ssh root@<server_ip> "curl -fsSL https://raw.githubusercontent.com/jefo/secure-internet-kit/main/bootstrap.sh | bash -s --"
```

Или зайти на сервер и выполнить:

```bash
curl -fsSL https://raw.githubusercontent.com/jefo/secure-internet-kit/main/bootstrap.sh | bash
```

**Плюсы:** Одна команда, ничего качать не надо.

**Минусы:** Репозиторий должен быть публичным (или нужен токен).

---

## Порядок действий для нового VPS

### Вариант A: Ansible (одной командой с вашей машины)

```bash
# 1. Отредактировать inventory.ini
nano inventory.ini
# Вставить: [vpn_servers]
#           <ip> ansible_user=root ansible_password=<password>

# 2. Задеплоить
ansible-playbook -i inventory.ini deploy.yml \
  --extra-vars "ssh_pubkey='$(cat ~/.ssh/id_ed25519.pub)' ssh_port=2222"
```

Ansible сам:
1. Закачает скрипты на сервер
2. Создаст пользователя с вашим SSH ключом
3. Захарденит SSH, настроит фаервол, Fail2ban
4. Установит и настроит TrustTunnel
5. После первого запуска — переключите inventory на SSH по ключу (уберите `ansible_password`)

### Вариант B: Вручную через SCP

```bash
# 1. Закачать скрипты
scp -r scripts/harden/ root@<ip>:/tmp/harden/

# 2. SSH на сервер
ssh root@<ip>

# 3. Посмотреть что нужно
sudo bash /tmp/harden/run.sh status

# 4. Создать пользователя (укажите свой SSH публичный ключ!)
export SSH_PUBKEY="$(cat ~/.ssh/id_ed25519.pub)"  # или вставьте ключ вручную
sudo bash /tmp/harden/run.sh run

# 5. После step02 — НЕ ЗАКРЫВАЙТЕ текущую сессию!
#    Откройте НОВОЕ окно и проверьте:
#    ssh -p 2222 vpnadmin@<ip>
```

---

## Переменные окружения

| Переменная | По умолчанию | Описание |
|------------|-------------|----------|
| `SSH_PORT` | `2222` | Порт SSH |
| `ADMIN_USER` | `vpnadmin` | Админ-пользователь |
| `SSH_PUBKEY` | _(пусто)_ | SSH публичный ключ (обязателен для step01) |
| `INSTALL_DIR` | `/opt/trusttunnel` | Каталог TrustTunnel |
| `TLS_DOMAIN` | _(пусто)_ | Домен для Let's Encrypt |
| `TLS_EMAIL` | _(пусто)_ | Email для Let's Encrypt |
| `TT_USERNAME` | `admin` | Пользователь VPN |
| `TT_PASSWORD` | _(авто)_ | Пароль VPN (генерируется) |

---

## После деплоя

```bash
# Проверить что TrustTunnel работает
ssh -p 2222 vpnadmin@<ip>
sudo systemctl status trusttunnel
sudo journalctl -u trusttunnel -n 20 --no-pager

# Экспортировать клиентский конфиг
cd /opt/trusttunnel/
sudo ./trusttunnel_endpoint vpn.toml hosts.toml -c user1 -a <your_domain>:443

# Удалить скрипты с сервера (опционально)
sudo rm -rf /tmp/harden/
```

## Быстрая шпаргалка

| Ситуация | Команда |
|----------|---------|
| Новый VPS, Ansible | `ansible-playbook -i inventory.ini deploy.yml --extra-vars "ssh_pubkey='$(cat ~/.ssh/id_ed25519.pub)'"` |
| Новый VPS, вручную | `scp -r scripts/harden/ root@<ip>:/tmp/harden/` → `ssh root@<ip>` → `sudo bash /tmp/harden/run.sh run` |
| Проверить безопасность | `sudo bash /tmp/harden/run.sh check` |
| Статус деплоя | `sudo bash /tmp/harden/run.sh status` |
| Один шаг | `sudo bash /tmp/harden/run.sh run 03` |
