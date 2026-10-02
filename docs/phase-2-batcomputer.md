# Phase 2: The Batcomputer 🖥️

**Goal:** a Wazuh SIEM that collects and analyzes logs from every machine in Gotham.

**Status:** 🟡 In progress. Wazuh is installed; agents and Sysmon are next.

---

## Why a SIEM?

Every Windows machine already writes logs (logins, processes started, changes made), but each machine keeps them to itself and nobody reads them. A **SIEM** (Security Information and Event Management) **collects** logs into one place, **analyzes** them against detection rules, and **alerts** when something looks like an attack.

Wazuh has three parts, all running on one server here:

| Component | Job |
|---|---|
| **Wazuh indexer** | Stores and searches all logs |
| **Wazuh server (manager)** | Receives logs from agents and checks them against rules |
| **Wazuh dashboard** | The web interface for alerts and searching (HTTPS, port 443) |

---

## Step 1: Start the DC first

The VNet's DNS points at the DC (`10.0.1.4`). If the DC is off, the new server can't resolve `packages.wazuh.com` ("Could not resolve host").

```bash
az vm start -g rg-gotham -n WAYNE-DC01
```

## Step 2: Check vCPU quota

```bash
az vm list-usage --location northcentralus \
  --query "[?contains(name.value,'cores') || contains(name.value,'Cores')].{Name:localName, Used:currentValue, Limit:limit}" -o table
```

My student subscription allows **6 regional vCPUs**: DC01 (2) + WS01 (2) + BATCOMPUTER (2) = 6/6. There is no room for a separate attacker VM, so Phase 3 runs Atomic Red Team directly on WS01.

## Step 3: Create BATCOMPUTER

```bash
az vm create -g rg-gotham -n BATCOMPUTER \
  --location northcentralus \
  --image Ubuntu2204 \
  --size Standard_B2as_v2 \
  --vnet-name vnet-gotham --subnet snet-wayne \
  --private-ip-address 10.0.1.6 \
  --public-ip-address "" --nsg "" \
  --os-disk-size-gb 64 --storage-sku StandardSSD_LRS \
  --os-disk-delete-option Delete --nic-delete-option Delete \
  --admin-username oracle --authentication-type password

az vm auto-shutdown -g rg-gotham -n BATCOMPUTER --time 0300 --location northcentralus
```

| Setting | Why |
|---|---|
| `Standard_B2as_v2` (8 GB RAM) | The Wazuh indexer is memory-hungry |
| `--private-ip-address 10.0.1.6` | Agents need a fixed address to send logs to |
| No public IP | No inbound door from the internet; reached via the DC jump host |
| 64 GB disk | Logs accumulate quickly |

**How does it download software with no public IP?** The subnet was created with `--default-outbound-access true`, so outbound connections work while inbound ones from the internet are impossible.

📸 [`01-batcomputer-created.png`](../screenshots/phase-2/01-batcomputer-created.png)

## Step 4: SSH in through the jump host

From the DC (RDP as `WAYNE\alfred`), in PowerShell:

```powershell
ssh oracle@10.0.1.6
```

Accept the host fingerprint on first connect. 📸 [`02-ssh-into-batcomputer.png`](../screenshots/phase-2/02-ssh-into-batcomputer.png)

## Step 5: Update the system

```bash
sudo apt update && sudo apt upgrade -y
```

If a "Pending kernel upgrade" dialog appears, press Enter. Deallocating and restarting the VM later loads the new kernel.

## Step 6: Install Wazuh (all-in-one)

From the official [Wazuh Quickstart](https://documentation.wazuh.com/current/quickstart.html):

```bash
wget https://packages.wazuh.com/4.14/wazuh-install.sh
ls -l wazuh-install.sh          # verify the download (~215 KB)
sudo bash ./wazuh-install.sh -a
```

Takes about 10 minutes. Watch detailed progress from a second SSH session with `sudo tail -f /var/log/wazuh-install.log` (Ctrl+C to stop following).

The summary prints the dashboard `admin` password: store it in a password manager, never in screenshots. If lost:

```bash
sudo tar -O -xf wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt
```

📸 [`03-wazuh-install-finished.png`](../screenshots/phase-2/03-wazuh-install-finished.png)

## Next

- [ ] Log into the dashboard at `https://10.0.1.6` from the DC
- [ ] Rotate the `admin` password
- [ ] Install Wazuh agents on WAYNE-DC01 and WAYNE-WS01
- [ ] Install Sysmon and forward its logs to Wazuh
- [ ] Verify events from both machines appear in the dashboard

---

## 🧰 Troubleshooting

| Problem | Fix |
|---|---|
| `curl` prints the script to the screen instead of saving it | The flag is `-O` (capital letter O), not `-0` (zero). Using `wget` avoids the ambiguity. |
| PowerShell window looks frozen; title says "Select ..." | Clicking the window starts text selection and pauses output. Press **Esc**. |
| Typed commands do nothing after `tail -f` | `tail -f` follows the log forever. Press **Ctrl+C** to stop it. |
| RDP to the DC fails from a new location | Your public IP changed: `az network nsg rule update -g rg-gotham --nsg-name WAYNE-DC01-nsg -n RDP --source-address-prefixes $(curl -s https://api.ipify.org)` |
| Ubuntu suggests `do-release-upgrade` to 24.04 | Ignore it. Major OS upgrades on a working security server need planning. |
