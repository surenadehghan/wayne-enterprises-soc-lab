# Phase 2: The Batcomputer 🖥️

**Goal:** a Wazuh SIEM that collects and analyzes logs from every machine in Gotham.

**Status:** ✅ Complete

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

## Step 7: Log into the dashboard

From the DC (or WS01), open Edge → `https://10.0.1.6` → accept the self-signed certificate warning (`NET::ERR_CERT_AUTHORITY_INVALID`) → log in as `admin`.

📸 [`04-wazuh-dashboard-first-login.png`](../screenshots/phase-2/04-wazuh-dashboard-first-login.png)

## Step 8: Deploy agents to both Windows machines

Dashboard → **Deploy new agent** → Windows MSI → server address `10.0.1.6` → agent name `WAYNE-DC01` (then `WAYNE-WS01` for the second). Run the generated command in an **elevated** PowerShell on each machine, then:

```powershell
NET START Wazuh
```

- The **server address never changes**: it is where every agent sends logs (the Batcomputer).
- The **agent name must be unique**: it is how an analyst knows which machine an alert came from.
- Agents **register** on TCP 1515, then **send events** on TCP 1514. "Never connected" means step 2 hasn't happened yet (service not started).

📸 [`05-dc01-agent-active.png`](../screenshots/phase-2/05-dc01-agent-active.png) · [`06-both-agents-active.png`](../screenshots/phase-2/06-both-agents-active.png)

## Step 9: Install Sysmon on both machines

Windows' default logs miss process creation detail, network connections and file creation. Sysmon adds them. Config: [SwiftOnSecurity sysmon-config](https://github.com/SwiftOnSecurity/sysmon-config).

```powershell
New-Item -ItemType Directory -Path C:\Tools\Sysmon -Force
Invoke-WebRequest -Uri https://download.sysinternals.com/files/Sysmon.zip -OutFile C:\Tools\Sysmon\Sysmon.zip -UseBasicParsing
Expand-Archive C:\Tools\Sysmon\Sysmon.zip -DestinationPath C:\Tools\Sysmon -Force
Invoke-WebRequest -Uri https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml -OutFile C:\Tools\Sysmon\sysmonconfig.xml -UseBasicParsing
C:\Tools\Sysmon\Sysmon64.exe -accepteula -i C:\Tools\Sysmon\sysmonconfig.xml
```

Verify: `Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 5`

Sysmon Event ID 16 logs the SHA256 of the active config, so tampering with the config (a common way to blind monitoring) is itself detectable.

📸 [`07`](../screenshots/phase-2/07-ws01-sysmon-installed.png) · [`08`](../screenshots/phase-2/08-ws01-sysmon-first-events.png) · [`09`](../screenshots/phase-2/09-dc01-sysmon-installed.png) · [`10`](../screenshots/phase-2/10-dc01-sysmon-config-hash.png)

## Step 10: Collect Sysmon centrally

Dashboard → **Agents management → Groups → default → Files → agent.conf**:

```xml
<agent_config os="Windows">
  <localfile>
    <location>Microsoft-Windows-Sysmon/Operational</location>
    <log_format>eventchannel</log_format>
  </localfile>
</agent_config>
```

Every Windows agent in the group picks this up and restarts on its own. No per-machine changes. Verify on each machine:

```powershell
Select-String -Path "C:\Program Files (x86)\ossec-agent\ossec.log" -Pattern "Sysmon"
# INFO: (1951): Analyzing event log: 'Microsoft-Windows-Sysmon/Operational'.
```

Both agents picked it up at the same second (20:43:42).

📸 [`11`](../screenshots/phase-2/11-agent-conf-sysmon-collection.png) · [`12`](../screenshots/phase-2/12-dc01-agent-reading-sysmon.png) · [`13`](../screenshots/phase-2/13-ws01-agent-reading-sysmon.png)

## Step 11: Test: catch reconnaissance

On WS01, run the commands an attacker uses right after getting in:

```powershell
whoami /all
net user /domain
net group "Domain Admins" /domain
```

In ~10 seconds these reveal every account in the company and the single domain admin (`alfred`): a target list and a target.

Dashboard → **Threat Hunting → Events** → `rule.groups: sysmon`, last 15 minutes:

| Rule ID | Description | Level |
|---|---|---|
| 92039 | A net.exe account discovery command was initiated | 3 |
| 92031 | Discovery activity executed | 3 |
| 92033 | Discovery activity spawned via PowerShell | 3 |

**Observation for Phase 4:** enumerating Domain Admins from a workstation is a strong early-warning sign, yet the built-in rules rate it level 3 (low). A custom rule should raise its severity.

📸 [`14`](../screenshots/phase-2/14-test-recon-net-user.png) · [`15`](../screenshots/phase-2/15-test-recon-domain-admins.png) · [`16`](../screenshots/phase-2/16-sysmon-alerts-in-wazuh.png) · [`17`](../screenshots/phase-2/17-caught-recon-discovery-alerts.png)

## Step 12: Rotate the exposed admin credential

The original `admin` password appeared in screenshots during setup. Exposed credentials get rotated, even when the risk is low (the dashboard has no public IP).

```bash
read -s -p "New admin password: " NEWPW; echo     # keeps it off screen and out of ~/.bash_history
sudo bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/wazuh-passwords-tool.sh -u admin -p "$NEWPW"
unset NEWPW
sudo filebeat test output                          # expect "talk to server... OK"
sudo systemctl restart filebeat
```

Wazuh requires 8–64 characters with upper, lower, a number and one of `.*+?-`. On an all-in-one server the tool also updates Filebeat's keystore; the dashboard and manager use other internal accounts. Verified by logging into the dashboard with the new password and confirming alerts kept arriving after the change.

📸 [`18`](../screenshots/phase-2/18-admin-credential-rotated-filebeat-ok.png) · [`19`](../screenshots/phase-2/19-threat-hunting-mitre-after-rotation.png)

## What the Batcomputer already sees

The Threat Hunting dashboard maps the session's own activity to MITRE ATT&CK:

| Technique | Where it came from |
|---|---|
| Valid Accounts (T1078) | Domain logons: RDP into DC01 and WS01 |
| Account Discovery (T1087) | `net user /domain`, `net group "Domain Admins" /domain` |
| Remote Services (T1021) | RDP from DC01 to WS01 |
| Windows Command Shell / PowerShell (T1059) | Every admin command run today |
| Sudo and Sudo Caching (T1548.003) | `sudo` on the Batcomputer itself (the manager monitors its own host) |

Every one of these was legitimate admin work, which is the core problem in detection: attackers use the same techniques. Telling them apart is what Phases 3–4 are about.

---

## 🧰 Troubleshooting

| Problem | Fix |
|---|---|
| `curl` prints the script to the screen instead of saving it | The flag is `-O` (capital letter O), not `-0` (zero). Using `wget` avoids the ambiguity. |
| PowerShell window looks frozen; title says "Select ..." | Clicking the window starts text selection and pauses output. Press **Esc**. |
| Typed commands do nothing after `tail -f` | `tail -f` follows the log forever. Press **Ctrl+C** to stop it. |
| RDP to the DC fails from a new location | Your public IP changed: `az network nsg rule update -g rg-gotham --nsg-name WAYNE-DC01-nsg -n RDP --source-address-prefixes $(curl -s https://api.ipify.org)` |
| `AADSTS70043: The refresh token has expired` on any `az` command | The school tenant's Conditional Access policy forces re-authentication every 7 days. Run `az logout`, then `az login --tenant <tenant-id>`. |
| Remote Desktop login to WS01 fails with the right password | RDP remembered a different saved account (e.g. `WAYNE\bwayne`). Check the username in the prompt; use **More choices → Use a different account**. `Get-ADUser <name> -Properties BadLogonCount,LastBadPasswordAttempt` on the DC shows which account actually received the failures. |
| Windows commands return `command not found` | You're in the SSH session to the Batcomputer (`oracle@BATCOMPUTER:~$`), which is Linux. Use a Windows PowerShell (`PS C:\>`). |
| Browser can't reach the dashboard (`ERR_CONNECTION_TIMED_OUT`) | Check the address: everything in Gotham is `10.0.1.x`. |
| Agent shows "never connected" | It registered (1515) but isn't sending (1514). Run `NET START Wazuh` and check `ossec.log`. |
| Ubuntu suggests `do-release-upgrade` to 24.04 | Ignore it. Major OS upgrades on a working security server need planning. |
