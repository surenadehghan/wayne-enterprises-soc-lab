# Case File: The Riddler — Domain Account Discovery

| | |
|---|---|
| **Case ID** | GCPD-SOC-001 |
| **Analyst** | Oracle (Surena Dehghan) |
| **Date opened** | 2026-10-27 |
| **Severity** | High (after tuning) — originally detected as Low |
| **Status** | Closed — detection gap remediated |
| **MITRE ATT&CK** | [T1087.002 — Account Discovery: Domain Account](https://attack.mitre.org/techniques/T1087/002/) |
| **Affected host** | WAYNE-WS01 (10.0.1.5) |
| **Account used** | WAYNE\alfred |
| **Detecting rules** | Built-in 92031 / 92033 / 92039 (level 3) → custom **100100** (level 12) |

---

## 1. Executive Summary

An endpoint in the Wayne Enterprises domain was used to enumerate Active Directory — listing every user account, every group, and specifically the membership of the **Domain Admins** group. This is classic pre-attack reconnaissance: it reveals the full list of targets and, critically, identifies the single privileged account (`alfred`) an attacker would need to compromise to control the domain.

Wazuh detected the activity, but its built-in rules rated it **low severity (level 3)** — low enough to be lost in day-to-day noise. A custom detection rule was written to raise enumeration of the Domain Admins group to **high severity (level 12)**, so that this specific high-value reconnaissance now stands out and would page an analyst. The gap is closed.

## 2. The Villain's Plan (Attack Description)

The Riddler's signature is reconnaissance — gathering intelligence before the real attack. On a domain-joined workstation, an attacker can map the entire organization using only **built-in Windows commands**, which look innocent and require no special tools.

Simulated with [Atomic Red Team](https://github.com/redcanaryco/atomic-red-team), technique **T1087.002**, tests 1, 3, 9, and 13:

| Test | Command (built-in) | Intelligence gained |
|---|---|---|
| 1 | `net user /domain`, `net group /domain` | Every account and group in `wayne.local` |
| 3 | `quser` | Who is currently logged in (session hijack targets) |
| 9 | `net user administrator /domain` | Probing the default admin account |
| 13 | `[adsisearcher]` (PowerShell/LDAP) | Directory policy info, quietly |

The decisive command, run to confirm the targeted detection:

```
net group "Domain Admins" /domain
```

This returned the sole domain administrator: **`alfred`** — in an attacker's hands, the one account worth stealing.

> **Lab condition:** Windows Defender real-time protection was disabled on WAYNE-WS01 before testing (itself MITRE **T1562 — Impair Defenses**) so the simulation would reach the SIEM rather than being blocked at the endpoint. In production this would be a controlled, authorized change; here it isolates the test to Wazuh's detection.

## 3. Timeline (UTC)

| Time | Event | Source |
|---|---|---|
| Oct 27 00:33 | Atomic Red Team T1087.002 recon suite executed on WAYNE-WS01 | Attacker console |
| Oct 27 00:33 | 4 account-discovery alerts raised (level 3) | Wazuh rules 92031/92033/92039 |
| Oct 27 ~00:45 | Custom rule 100100 authored and deployed to the manager | Detection-as-code (GitHub → SIEM) |
| Oct 27 00:50 | `net group "Domain Admins" /domain` executed | WAYNE-WS01 |
| Oct 27 00:50 | **2 high-severity alerts raised (level 12)** | Wazuh rule **100100** |

## 4. Detection

**Before tuning:** Sysmon (Event ID 1, process creation) forwarded the commands to Wazuh, which matched built-in discovery rules **92031, 92033, 92039** — all **level 3 (low)**. Accurate, but under-prioritized: listing the Domain Admins group was rated the same as routine background activity.

**After tuning:** a custom rule was added to `/var/ossec/etc/rules/local_rules.xml` (version-controlled at [`detections/local_rules.xml`](../detections/local_rules.xml)):

```xml
<rule id="100100" level="12">
  <if_sid>61603</if_sid>
  <field name="win.eventdata.commandLine" type="pcre2">(?i)\bnet1?\b.*\bgroup\b.*domain admins</field>
  <description>Oracle/Gotham: Domain Admins group enumeration on $(win.system.computer) - high-value reconnaissance (T1087.002)</description>
  <mitre><id>T1087.002</id></mitre>
</rule>
```

It fires on Sysmon process creation (rule 61603) when a command matches `net[1] group ... domain admins`, raising the alert to level 12.

📸 Evidence: [`08-custom-rule-100100-fired-events.png`](../screenshots/phase-3/08-custom-rule-100100-fired-events.png) · [`09-custom-rule-100100-dashboard.png`](../screenshots/phase-3/09-custom-rule-100100-dashboard.png)

## 5. Investigation & Evidence

Filtering the SIEM to `rule.id: 100100` returned 2 hits on WAYNE-WS01, both level 12:

> *"Oracle/Gotham: Domain Admins group enumeration on WAYNE-WS01.wayne.local — high-value reconnaissance (T1087.002)"*

Two hits for one command is expected: `net group` spawns both `net.exe` and `net1.exe`, and each executes the command, so Sysmon records two process-creation events. Supporting evidence (the raw enumeration output and the broader alert picture) is in [`screenshots/phase-3/`](../screenshots/phase-3/).

In a real investigation the next questions would be: **is `alfred` supposed to be running these commands from a workstation?** and **was this interactive, or scripted?** Here it was authorized testing; in production, an unexpected answer would escalate this to an active-intrusion investigation.

## 6. Response

Had this been a real detection, the SOC response would be:
1. **Verify the source** — confirm whether the account and host are expected to perform AD enumeration (most endpoints never should).
2. **Contain if unexplained** — isolate WAYNE-WS01 from the network and suspend the account session.
3. **Hunt for follow-on activity** — look for what usually comes next: credential theft (T1003), lateral movement (T1021), or privilege escalation targeting `alfred`.
4. **Reset credentials** for any account observed being enumerated or used.

## 7. Lessons Learned & Prevention

- **Default detections are a starting point, not the finish line.** The built-in rules *saw* the recon but *under-rated* it. Tuning severity to business context (Domain Admins = crown jewels) is what makes a SIEM useful.
- **Reduce the attack surface:** keep Domain Admins membership minimal (here it is a single account) and avoid logging into workstations with privileged accounts.
- **Endpoint protection matters:** with Defender enabled, much of this would have been blocked at the host. Defense in depth (endpoint + SIEM) beats either alone.
- **Detection-as-code:** storing rules in Git and deploying them to the SIEM gives version history, review, and repeatability — the same rigor as application code.

## 8. What I Learned

> *(Surena — write this in your own words before the event; this is a placeholder.)*
>
> The thing that clicked for me was that the attacker didn't use any "hacking tools" — just `net group`, a built-in Windows command — and that's exactly why it's dangerous and easy to miss. I learned to read a SIEM alert, spot that "it's detected" isn't the same as "it's prioritized," and actually write and test a rule to fix that. Seeing rule 100100 fire at level 12 after I built it was the moment detection engineering made sense to me.
