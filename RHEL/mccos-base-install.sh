#!/bin/bash

#init
mccos_ipdevices=0
declare -a mccos_ip_port
declare -a mccos_ip_address

#loop through all interfaces iwth IPv4
while NIC= read -r line; do
  iface=$(echo "$line" | awk '{print $2}')
  ipaddr=$(echo "$line" | awk '{print $4}')

  mccos_ip_port+=("'$iface'")
  mccos_ip_address+=("'$ipaddr'")
done < <(ip -o -4 addr show)
mccos_ipdevices=${#mccos_ip_port[@]}

echo "Total interfaces with IPv4: $mccos_ipdevices"
for ((i=0; i<mccos_ipdevices; i++)); do
    echo "Interface $i: Port=${mccos_ip_port[$i]}, Address=${mccos_ip_address[$i]}"
done
