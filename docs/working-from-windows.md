# Working from Windows 🪟

The whole lab runs in Azure, so the computer you control it from is interchangeable. **Phases 1–2 were built from a MacBook; Phases 3–5 are being done from a Windows PC.** You can switch between the two at any time.

---

## One-time setup (≈15 minutes)

**1. Install the Azure CLI** (PowerShell):

```powershell
winget install -e --id Microsoft.AzureCLI
```

Close and reopen PowerShell. **Before signing in**, turn off the Windows sign-in broker so the login uses a normal browser tab:

```powershell
az config set core.enable_broker_on_windows=false
az login --tenant "<your-tenant-id>"
```

> ⚠️ **Why:** by default on Windows, `az login` uses Windows' account broker, which can try to enroll your **personal PC** in the school's device management (MDM), letting the organization apply policies to it. On a personal machine, never accept "Allow my organization to manage my device". If it was attempted, check **Settings → Accounts → Access work or school** and **Disconnect** the school account.

**2. Remote Desktop is built in.** Start → `mstsc` → enter the DC's public IP → log in as `WAYNE\alfred`. No extra app needed.

**3. Passwords.** If they're in Apple Passwords, install **iCloud for Windows** (Microsoft Store), which includes iCloud Passwords, or read them from your phone.

---

## Command differences: Mac Terminal vs Windows PowerShell

Most `az` commands are identical. The ones that differ are those that look up your current public IP, because Windows PowerShell treats `curl` differently.

| Task | Mac Terminal (zsh) | Windows PowerShell |
|---|---|---|
| Allow your current IP through the RDP rule | `--source-address-prefixes $(curl -s https://api.ipify.org)` | `--source-address-prefixes (Invoke-RestMethod https://api.ipify.org)` |
| Start DC, then Batcomputer | `az vm start ... && az vm start ...` | Run as two lines (or use `&&` in PowerShell 7+) |
| Deallocate everything | `az vm deallocate --ids $(az vm list -g rg-gotham --query "[].id" -o tsv)` | Same command |
| Screenshot | ⌘ + Shift + 4 | Windows + Shift + S |

### Session routine (Windows)

```powershell
# 1. Allow this location through the firewall
az network nsg rule update -g rg-gotham --nsg-name WAYNE-DC01-nsg -n RDP --source-address-prefixes (Invoke-RestMethod https://api.ipify.org)

# 2. Start the DC first (it's DNS for everything), then the rest
az vm start -g rg-gotham -n WAYNE-DC01
az vm start -g rg-gotham -n BATCOMPUTER
az vm start -g rg-gotham -n WAYNE-WS01

# 3. ...work...

# 4. Shut down
az vm deallocate --ids $(az vm list -g rg-gotham --query "[].id" -o tsv)
```

---

## Notes

- **The RDP rule allows one IP at a time.** Run the firewall command on whichever machine you're using, every time you switch machines or locations.
- **Azure sign-ins expire every 7 days** on the school tenant (`AADSTS70043`). Run `az logout`, then `az login --tenant <tenant-id>`.
- **Windows-to-Windows Remote Desktop** shares the clipboard more reliably than macOS → Windows, and Ctrl means Ctrl.
