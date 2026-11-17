#!/bin/bash
# Secure Internet Kit Dual-IP QoS Setup
# Настройка ограничения скорости для второго IP через iptables MARK + tc
# Замените eth0 и IP_LITE на ваши значения.
# ВАЖНО: проверьте, что исходящий трафик действительно выбирает Lite IP
# как source (ip route get). Иначе MARK не сработает. См. README → Ограничения.

INTERFACE="eth0"
IP_LITE="198.51.100.11"

# Помечаем трафик, исходящий с Lite IP, меткой "20"
iptables -t mangle -A OUTPUT -s $IP_LITE -j MARK --set-mark 20

# Очистка и создание очереди
tc qdisc del dev $INTERFACE root 2>/dev/null
tc qdisc add dev $INTERFACE root handle 1: htb default 10

# Быстрый класс (по умолчанию)
tc class add dev $INTERFACE parent 1: classid 1:10 htb rate 1000mbit

# Медленный класс (2 Мбит/с)
tc class add dev $INTERFACE parent 1: classid 1:20 htb rate 2mbit ceil 2mbit

# Привязываем метку 20 к медленному классу
tc filter add dev $INTERFACE protocol ip parent 1: prio 1 handle 20 fw flowid 1:20

echo "✅ Dual-IP QoS настроен."
echo "Lite IP ($IP_LITE) ограничен до 2 Мбит/с через MARK + tc."
echo "Premium IP работает на полной скорости."
