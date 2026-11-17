#!/bin/bash
# Secure Internet Kit TC Rules Persistence
# Применяет правила ограничения скорости при загрузке сервера
# Добавить в crontab: @reboot root /opt/trusttunnel/server/apply_tc_rules.sh

# Авто-определение интерфейса
INTERFACE=$(ip route | grep default | awk '{print $5}')

if [ -z "$INTERFACE" ]; then
    echo "ERROR: Не удалось определить сетевой интерфейс"
    exit 1
fi

echo "Применяю TC rules на интерфейсе $INTERFACE..."

# Очистка
tc qdisc del dev $INTERFACE root 2>/dev/null

# Создание очередей
tc qdisc add dev $INTERFACE root handle 1: htb default 10
tc class add dev $INTERFACE parent 1: classid 1:10 htb rate 1000mbit
tc class add dev $INTERFACE parent 1: classid 1:20 htb rate 2mbit ceil 2mbit

# Фильтр по метке (для Dual-IP стратегии — Lite IP маркируется iptables MARK 20)
tc filter add dev $INTERFACE protocol ip parent 1: prio 1 handle 20 fw flowid 1:20

echo "✅ TC rules applied. Lite traffic (MARK 20) limited to 2 Mbit/s."
