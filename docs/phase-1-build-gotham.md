# Phase 1: Build Gotham 🏙️

**Goal:** a working Windows domain called `wayne.local` in Azure, with a domain controller, one employee workstation, and a roster of Wayne Enterprises employees.

**When you're done you'll have:**
- `WAYNE-DC01`: domain controller + DNS
- `WAYNE-WS01`: a workstation joined to the domain
- Wayne Enterprises departments (OUs) and employees (users)
- Screenshots proving it all works, for the portfolio

**Time:** 2–4 hours, and it's fine to split it across sessions (just [shut Gotham down](#-end-of-every-session-shut-gotham-down) between them).

> 📸 **Screenshot habit:** every time you see a 📸, take a screenshot and save it in `screenshots/phase-1/`. Crop out anything private (subscription IDs, your public IP, emails). These screenshots become your portfolio evidence.

---

## Step 0: Before you start

- **Password manager.** You'll create several passwords. Store them in a password manager (Bitwarden is free). Don't reuse your real passwords, and never commit passwords to GitHub.
- **Microsoft Windows App** (formerly "Microsoft Remote Desktop") from the Mac App Store. It's how you'll log into the Windows machines.
- **Azure CLI** (for the shutdown script later): in Terminal, run `brew install azure-cli`, then `az login`.
  - No Homebrew? Install it from [brew.sh](https://brew.sh) first.

---

## Step 1: Create the resource group

A resource group is a folder that holds everything in Gotham. That makes it easy to see costs and delete it all in one go if you ever need to.

1. Azure portal → search **Resource groups** → **+ Create**
2. **Subscription:** Azure for Students
3. **Resource group:** `rg-gotham`
4. **Region:** `Canada Central`
5. **Review + create** → **Create**

> ⚠️ **"Disallowed by policy" error?** Student subscriptions only allow certain regions. The error message lists which ones are allowed; pick one of those and use the **same region for everything** in this guide.

---

## Step 2: Create the network

1. Search **Virtual networks** → **+ Create**
2. **Basics** tab:
   - Resource group: `rg-gotham`
   - Name: `vnet-gotham`
   - Region: same as your resource group
3. **IP addresses** tab:
   - Address space: `10.0.0.0/16`
   - Edit the default subnet → name it `snet-wayne`, range `10.0.1.0/24`
4. **Review + create** → **Create**

📸 The virtual network overview page.

---

## Step 3: Create the domain controller (WAYNE-DC01)

1. Search **Virtual machines** → **+ Create** → **Azure virtual machine**
2. **Basics** tab:

   | Setting | Value |
   |---|---|
   | Resource group | `rg-gotham` |
   | Virtual machine name | `WAYNE-DC01` |
   | Region | same as before |
   | Availability options | No infrastructure redundancy required |
   | Security type | Standard |
   | Image | Click **See all images**, search **Windows Server**, and choose **[smalldisk] Windows Server 2022 Datacenter: Azure Edition** (Gen2) |
   | Size | `Standard_B2s` (2 vCPU, 4 GB RAM) |
   | Username | `alfred` 🎩 (Azure blocks names like "admin" and "administrator") |
   | Password | a strong unique password → save it in your password manager |
   | Public inbound ports | **Allow selected ports** → **RDP (3389)** |

   > 💡 **Why "smalldisk"?** Azure charges for disks **even when the VM is off**. The smalldisk image uses a ~30 GB disk instead of 127 GB, which costs a fraction as much per month.

   > ⚠️ **Size unavailable?** Try `Standard_B2as_v2` or `Standard_B2s_v2` instead.

3. **Disks** tab: OS disk type → **Standard SSD**
4. **Networking** tab:
   - Virtual network: `vnet-gotham`
   - Subnet: `snet-wayne`
   - Public IP: leave the new one it suggests
5. **Management** tab: turn on **Auto-shutdown**, pick a time like 11:00 PM in your time zone, and add your email for a notification. This is your safety net if you forget to shut down.
6. **Review + create** → **Create**. It takes a few minutes.

### 🔒 Step 3b: Lock RDP to your IP (do NOT skip this)

Right now, **anyone on the internet** can try to log into your server. Bots scan the whole internet for open RDP ports constantly and will start guessing passwords within minutes. (That's actually useful data for later, but not before your lab is hardened.)

1. Open `WAYNE-DC01` → **Network settings** (under Networking)
2. Click the inbound rule that allows port **3389 (RDP)**
3. **Source:** change from **Any** to **My IP address**
4. **Save**

📸 The inbound rules showing RDP restricted to your IP (blur the IP itself).

> 💡 If you change locations (home → school → café), your IP changes and RDP will stop working. Just come back here and update the rule to **My IP address** again.

### Step 3c: Give the DC a static private IP

A domain controller's address should never change, because every machine uses it to find the domain.

1. `WAYNE-DC01` → **Network settings** → click the **network interface** name
2. **IP configurations** (left menu) → click `ipconfig1`
3. Private IP address allocation: **Static**, address `10.0.1.4` (it probably already has this; you're just making it permanent)
4. **Save**

> ⚠️ In Azure, always set static IPs **here in the portal**, never inside Windows. Changing network settings inside the VM can lock you out.

---

## Step 4: Turn the server into a domain controller

1. `WAYNE-DC01` → **Connect** → download the **RDP file** → open it with Windows App → log in as `alfred`
2. Open **PowerShell as Administrator** (Start → type PowerShell → right-click → Run as administrator)
3. Install Active Directory:

   ```powershell
   Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
   ```

4. Create the `wayne.local` forest:

   ```powershell
   Install-ADDSForest -DomainName "wayne.local" -DomainNetbiosName "WAYNE" -InstallDns
   ```

   - It asks for a **Safe Mode Administrator password**: another new password for your password manager.
   - Answer **Y** to continue. The server reboots automatically; this takes 5–10 minutes.

5. Reconnect with RDP. Your login is now a **domain** account: `WAYNE\alfred` (same password).

📸 **Server Manager** showing **AD DS** and **DNS** roles installed.

---

## Step 5: Point the network's DNS at your DC

Every machine in Gotham needs to ask the DC "where is wayne.local?" By default Azure gives out its own DNS, which has never heard of `wayne.local`, so we change it.

1. Azure portal → `vnet-gotham` → **DNS servers**
2. Select **Custom** → enter `10.0.1.4` → **Save**

---

## Step 6: Hire the employees (users and departments)

On `WAYNE-DC01`, as `WAYNE\alfred`:

1. Copy [`scripts/create-gotham-users.ps1`](../scripts/create-gotham-users.ps1) onto the server. The easiest way is to open the file on GitHub, click **Raw**, copy all of it, paste it into Notepad on the server, and save it as `C:\create-gotham-users.ps1`.
2. In PowerShell as Administrator:

   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   C:\create-gotham-users.ps1
   ```

3. When it asks, enter a starting password for the employees (12+ characters with upper, lower, number, symbol).
4. Open **Active Directory Users and Computers** (Start → type "Active Directory") and expand `wayne.local` → `Wayne Enterprises`.

📸 AD Users and Computers showing the departments and employees.

---

## Step 7: Create the workstation (WAYNE-WS01)

The workstation gets **no public IP**. You'll reach it by hopping through the DC. Fewer doors facing the internet = smaller attack surface. That's a real design decision you can talk about in interviews.

1. Create a second VM exactly like Step 3, except:
   - Name: `WAYNE-WS01`
   - Public IP: **None**
   - Public inbound ports: **None**
   - Still turn on **Auto-shutdown**
2. Once it's running, RDP into `WAYNE-DC01`, then **from inside the DC**, open **Remote Desktop Connection** and connect to `WAYNE-WS01`'s private IP (shown on its Azure overview page, probably `10.0.1.5`). Log in as the local account `alfred`.

> 💡 **Why Windows Server as a "workstation"?** Azure's Windows 10/11 desktop images need special licensing. A Windows Server VM behaves the same way for everything in this lab: logins, processes, PowerShell, event logs.

---

## Step 8: Join the workstation to the domain

On `WAYNE-WS01`, in PowerShell as Administrator:

1. Check that it can find the domain:

   ```powershell
   Resolve-DnsName wayne.local
   ```

   It should return `10.0.1.4`. If it doesn't, restart the VM from the Azure portal so it picks up the new DNS setting from Step 5, then try again.

2. Join the domain (it asks for `WAYNE\alfred`'s password, then reboots):

   ```powershell
   Add-Computer -DomainName "wayne.local" -Credential "WAYNE\alfred" -Restart
   ```

3. After the reboot, RDP back in (from the DC) as `WAYNE\alfred` and let employees log in remotely:

   ```powershell
   Add-LocalGroupMember -Group "Remote Desktop Users" -Member "WAYNE\Domain Users"
   ```

4. Back on the **DC**, file the workstation in the right department:

   ```powershell
   $root = "OU=Wayne Enterprises," + (Get-ADDomain).DistinguishedName
   Get-ADComputer "WAYNE-WS01" | Move-ADObject -TargetPath "OU=Workstations,$root"
   ```

---

## Step 9: Prove it works ✅

From the DC, RDP to `WAYNE-WS01` and log in as **Bruce Wayne**: `WAYNE\bwayne` with the employee password you set. Then run:

```powershell
whoami
whoami /groups
nltest /dsgetdc:wayne.local
```

📸 A screenshot showing `whoami` returning `wayne\bwayne`. **This is the Phase 1 money shot.**

Then tick **Phase 1** in the README roadmap. 🎉

---

## 🌙 End of every session: shut Gotham down

**Shutting down from inside Windows does NOT stop the charges.** The VM must be **deallocated** in Azure.

Either:
- **Portal:** each VM → **Stop** (status must say **Stopped (deallocated)**)
- **Terminal on your Mac:** `./scripts/gotham-power.sh down`

Starting again: `./scripts/gotham-power.sh up` (it starts the DC first so DNS is ready before the workstation boots).

---

## 💰 What this costs (roughly)

| Item | When you pay | Approx. cost |
|---|---|---|
| 2 × Windows B2s VMs | only while running | ~$0.10–0.15 USD/hour each |
| 2 × small Standard SSD disks | always, even when stopped | a few dollars/month total |
| 1 × public IP | always | ~$3–4 USD/month |

With ~10 hours of lab time a week, expect roughly **$15–25/month**. Check your real numbers under **Cost Management → Cost analysis** after the first week and adjust.

---

## 🧰 Troubleshooting

| Problem | Fix |
|---|---|
| RDP suddenly won't connect | Your IP changed. Update the RDP rule to **My IP address** (Step 3b). |
| `Resolve-DnsName wayne.local` fails on WS01 | Check the VNet DNS is `10.0.1.4` (Step 5), make sure the DC is running, then restart WS01 from the portal. |
| "Disallowed by policy" | Your student subscription limits regions. Use one listed in the error. |
| "Operation could not be completed as it results in exceeding quota" | Student subscriptions cap vCPUs. Check **Subscriptions → Usage + quotas**; run fewer VMs at once or use smaller sizes. |
| Domain join says "access denied" | Use `WAYNE\alfred` (with the `WAYNE\`), not just `alfred`. |

---

## ✍️ Write it up

Before moving on, write a short paragraph in your own words for the README or a blog post: what you built, one thing that broke, and how you fixed it. Hiring managers care about *how you troubleshoot* as much as what you built.

**Next up → Phase 2: The Batcomputer** (Wazuh SIEM + Sysmon).
