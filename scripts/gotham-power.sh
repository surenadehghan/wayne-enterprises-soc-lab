#!/usr/bin/env bash
# Start, stop (deallocate), or check every VM in the Gotham lab.
# Usage: ./scripts/gotham-power.sh up | down | status
# Requires the Azure CLI (`brew install azure-cli`) and `az login`.

set -euo pipefail

RG="${GOTHAM_RG:-rg-gotham}"
DC="WAYNE-DC01"

case "${1:-}" in
  up)
    echo "Starting $DC first so DNS is ready..."
    az vm start -g "$RG" -n "$DC"
    ids=$(az vm list -g "$RG" --query "[?name!='$DC'].id" -o tsv)
    if [ -n "$ids" ]; then
      echo "Starting the rest of Gotham..."
      az vm start --ids $ids
    fi
    echo "Gotham is awake. 🦇"
    ;;
  down)
    ids=$(az vm list -g "$RG" --query "[].id" -o tsv)
    if [ -z "$ids" ]; then
      echo "No VMs found in $RG."
      exit 0
    fi
    echo "Deallocating all VMs in $RG (this stops compute charges)..."
    az vm deallocate --ids $ids
    echo "Gotham is asleep. 🌙"
    ;;
  status)
    az vm list -g "$RG" -d --query "[].{Name:name, Power:powerState, PrivateIP:privateIps}" -o table
    ;;
  *)
    echo "Usage: $0 up | down | status"
    exit 1
    ;;
esac
