#!/usr/bin/env bash
# Fundamental Friday Week 4 lab setup.
# Builds a second, separate "machine" inside your Kali VM called "attacker",
# connected to your Kali by a virtual cable. Your Kali side is 10.10.10.1,
# the attacker side is 10.10.10.2. Run:  sudo bash lab-setup.sh up
# Open a terminal as the attacker:       sudo bash lab-setup.sh shell
# Check that it exists:                  sudo bash lab-setup.sh status
# Tear it all down afterwards with:     sudo bash lab-setup.sh down

set -e
NS=attacker
HOST_IF=veth-lab
NS_IF=veth-atk
HOST_IP=10.10.10.1
NS_IP=10.10.10.2

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this with sudo:  sudo bash $0 up"
  exit 1
fi

case "$1" in
  up)
    if ip netns list | grep -qw "$NS"; then
      echo "The attacker machine already exists. Run 'sudo bash $0 down' first if you want a fresh one."
      exit 0
    fi
    ip netns add "$NS"
    ip link add "$HOST_IF" type veth peer name "$NS_IF"
    ip link set "$NS_IF" netns "$NS"
    ip addr add "$HOST_IP/24" dev "$HOST_IF"
    ip link set "$HOST_IF" up
    ip netns exec "$NS" ip addr add "$NS_IP/24" dev "$NS_IF"
    ip netns exec "$NS" ip link set "$NS_IF" up
    ip netns exec "$NS" ip link set lo up
    echo ""
    echo "Lab network is up."
    echo "  Your Kali (the defender) is  $HOST_IP  on interface $HOST_IF"
    echo "  The attacker machine is      $NS_IP"
    echo ""
    echo "Testing the cable with one ping from the attacker to you:"
    if ip netns exec "$NS" ping -c 1 -W 2 "$HOST_IP" >/dev/null 2>&1; then
      echo "  Ping worked. The cable is connected."
    else
      echo "  Ping failed. If you already turned ufw on, that can be normal. Otherwise tell Andrew."
    fi
    echo ""
    echo "Now open a NEW terminal and run:  sudo bash $0 shell"
    echo "That terminal becomes the attacker. Its prompt starts with ATTACKER."
    ;;
  shell)
    if ! ip netns list | grep -qw "$NS"; then
      echo "The attacker machine does not exist yet. Run:  sudo bash $0 up"
      exit 1
    fi
    echo "You are now the attacker machine (10.10.10.2). Type exit to leave."
    exec ip netns exec "$NS" env PS1='ATTACKER 10.10.10.2 \w # ' bash --norc
    ;;
  down)
    ip netns del "$NS" 2>/dev/null || true
    ip link del "$HOST_IF" 2>/dev/null || true
    echo "Lab network removed. Your Kali is back to normal."
    ;;
  status)
    ip netns list | grep -qw "$NS" && echo "Attacker machine exists." || echo "Attacker machine does not exist."
    ip -brief addr show "$HOST_IF" 2>/dev/null || echo "No $HOST_IF interface."
    ;;
  *)
    echo "Usage: sudo bash $0 up | shell | status | down"
    exit 1
    ;;
esac
