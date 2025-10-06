#!/bin/bash

#init
mccos_ipdevices=0

#loop through all interfaces iwth IPv4
while NIC= read -r line; do
  iface=$(echo "$line" | ask '{print $2}')
  ipaddr=$(echo "$line" | awk '{print $4}')

  eval "mccos_ip($mccos_ipdevices)_port='$iface'"
  eval "mccos_ip($mccos_ipdevices)_address='$ipaddr'"

  ((mccos_ipdevices++))
done < <(ip -o -4 addr show)

echo "Total interfaces with IPv4: $mccos_ipdevices"
for ((i=0; i<mccos_ipdevices; i++)); do
    eval "echo \"Interface \$i: Port=\${mccos_ip($i)_port}, Address=\${mccos_ip($i)_address}\""
done
