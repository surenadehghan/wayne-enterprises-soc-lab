# Phase 3 & 4: The Villains Attack, Oracle Responds 🃏🛡️

**Goal:** attack the lab with real adversary techniques, check whether the SIEM catches them, and write custom detection rules where it falls short.

**Status:** 🟡 In progress — The Riddler complete; more villains to come.

> All attacks run **only inside this isolated lab, on machines I own**, using [Atomic Red Team](https://github.com/redcanaryco/atomic-red-team) — a controlled adversary-emulation framework. Nothing here targets any real system.

---

## The loop (run once per villain)

1. 🃏 **Attack** — run the atomic test(s) on WAYNE-WS01
2. 👀 **Hunt** — Threat Hunting → Events in Wazuh: did it fire, and at what severity?
3. 🔍 **Find the gap** — is the severity right for the business impact?
4. 🛡️ **Write a rule** — add to [`detections/local_rules.xml`](../detections/local_rules.xml), deploy, reload
5. ✅ **Verify** — re-run the attack and confirm the new rule fires
6. 📝 **Document** — write the case file

---

## Setup: Atomic Red Team on WAYNE-WS01

```powershell
# Defender would quarantine the test files, so stand it down on this lab box
# (disabling AV is itself MITRE T1562 - note it in the case file)
Set-MpPreference -DisableRealtimeMonitoring $true
Add-MpPreference -ExclusionPath "C:\AtomicRedTeam"

# Install the framework + the atomics library (~349 techniques)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing)
Install-AtomicRedTeam -getAtomics -Force
```

Each new session, re-import the module:

```powershell
Import-Module "C:\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1" -Force
```

> ⚠️ With real-time protection **on**, Defender deletes `C:\AtomicRedTeam` between sessions. Keeping it off on this isolated lab box is a deliberate, documented choice.

---

## Detection-as-code

Custom rules live in version control at [`detections/local_rules.xml`](../detections/local_rules.xml) and are pulled onto the Wazuh manager — the same workflow real SOCs use (rules reviewed in Git, deployed to the SIEM):

```bash
# On the Batcomputer (SSH as oracle)
sudo cp /var/ossec/etc/rules/local_rules.xml /var/ossec/etc/rules/local_rules.xml.bak   # back up
wget -O gotham.xml https://raw.githubusercontent.com/surenadehghan/wayne-enterprises-soc-lab/main/detections/local_rules.xml
cat gotham.xml                                                                            # verify
sudo cp gotham.xml /var/ossec/etc/rules/local_rules.xml
sudo systemctl restart wazuh-manager          # a clean restart = valid XML + rule loaded
sudo systemctl status wazuh-manager           # expect: active (running)
```

Custom rule IDs use the **100100–100199** range (Wazuh reserves 100000+ for user rules, so they never clash with updates).

---

## ❓ Villain 1: The Riddler — Account Discovery (T1087.002)

**Attack** (built-in Windows commands only — no tools needed):
```powershell
Invoke-AtomicTest T1087.002 -TestNumbers 1,3,9,13
net group "Domain Admins" /domain
```

**Finding:** Wazuh caught it (rules 92031/92033/92039) but at **level 3 (low)** — enumerating the Domain Admins group was rated the same as background noise.

**The rule** ([rule 100100](../detections/local_rules.xml)) raises Domain Admins enumeration to **level 12 (high)**:
```xml
<rule id="100100" level="12">
  <if_sid>61603</if_sid>
  <field name="win.eventdata.commandLine" type="pcre2">(?i)\bnet1?\b.*\bgroup\b.*domain admins</field>
  <description>Oracle/Gotham: Domain Admins group enumeration on $(win.system.computer) - high-value reconnaissance (T1087.002)</description>
  <mitre><id>T1087.002</id></mitre>
</rule>
```

**Verified:** re-running the command fired rule 100100 at level 12. 📸 [`08`](../screenshots/phase-3/08-custom-rule-100100-fired-events.png) · [`09`](../screenshots/phase-3/09-custom-rule-100100-dashboard.png)

**Full write-up:** [Case File 001 — The Riddler](../case-files/01-the-riddler.md)

### Anatomy of a Wazuh rule

| Part | Meaning |
|---|---|
| `id` | Unique rule ID (yours: 100100–100199) |
| `level` | Severity 0–15; 12+ counts as high |
| `if_sid` | Only evaluate when this parent rule fired (61603 = Sysmon process creation) |
| `field ... pcre2` | Regex match against a decoded field (here, the command line) |
| `description` | What the analyst sees; `$(field)` substitutes live values |
| `mitre` | Maps the alert to an ATT&CK technique |

---

## Next villains (planned)

- 🐧 **The Penguin** — password spraying (T1110.003): many accounts, one password, short burst
- 🤡 **The Joker** — ransomware behaviour (T1490 inhibit recovery, T1486 encryption)
- 🪙 **Two-Face** — persistence (T1136 create account, T1053 scheduled task)
