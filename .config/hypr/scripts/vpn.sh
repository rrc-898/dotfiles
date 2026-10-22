#!/bin/bash
# VPNs para la página Network de Ajustes (quickshell).
#   vpn.sh list            -> una línea por VPN: nombre|tipo|activa(yes/no)|detalle
#   vpn.sh up|down NOMBRE  -> conectar / desconectar
# Tipos: "upv" (swanctl, vía ~/.local/bin/vpn-upv) y "nm" (VPN/WireGuard de NetworkManager)
VPN_UPV="$HOME/.local/bin/vpn-upv"

case "$1" in
  list)
    if [ -x "$VPN_UPV" ]; then
      st=$("$VPN_UPV" estado)
      ip=$(grep -oP 'IP interna \K[0-9.]+' <<<"$st")
      if [ -n "$ip" ]; then echo "UPV|upv|yes|$ip"; else echo "UPV|upv|no|vpn.upv.es"; fi
    fi
    nmcli -t -f NAME,TYPE,ACTIVE connection show 2>/dev/null |
      awk -F: '$2=="vpn" || $2=="wireguard" {print $1 "|nm|" $3 "|" $2}'
    ;;
  up|down)
    name=$2
    if [ "$name" = "UPV" ]; then
      [ "$1" = up ] && exec "$VPN_UPV" on || exec "$VPN_UPV" off
    fi
    exec nmcli connection "$1" id "$name"
    ;;
  *) echo "Uso: vpn.sh list | up NOMBRE | down NOMBRE" >&2; exit 2 ;;
esac
