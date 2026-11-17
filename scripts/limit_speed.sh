#!/bin/bash
# Secure Internet Kit Speed Limiter

INTERFACE="eth0" # Узнайте через 'ip link' (может быть ens3)
CLIENT_IP=$1     # IP клиента, который нужно ограничить
LIMIT="2mbit"    # Скорость (например, 2 Мбит/с)

if [ -z "$CLIENT_IP" ]; then
    echo "Использование: $0 <IP_клиента> [лимит]"
    exit 1
fi

# 1. Очистка старых правил для этого интерфейса (если нужно)
# tc qdisc del dev $INTERFACE root 2>/dev/null

# 2. Создаем "очередь" (htb)
tc qdisc add dev $INTERFACE root handle 1: htb default 10

# 3. Создаем класс с ограничением скорости
tc class add dev $INTERFACE parent 1: classid 1:1 htb rate $LIMIT ceil $LIMIT

# 4. Направляем трафик к IP клиента в этот класс
tc filter add dev $INTERFACE protocol ip parent 1: prio 1 u32 match ip dst $CLIENT_IP/32 flowid 1:1

echo "✅ Скорость для $CLIENT_IP ограничена до $LIMIT"
