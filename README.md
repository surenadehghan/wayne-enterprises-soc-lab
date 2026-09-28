# 🦇 Wayne Enterprises SOC Lab

> *"Gotham's biggest company is under attack. Every villain has a technique. Every technique leaves evidence. My job is to find it."*

A hands-on **Security Operations Center (SOC) home lab** built in Microsoft Azure. I built a small corporate network for the fictional **Wayne Enterprises**, attacked it with real adversary techniques (each one played by a Gotham villain), then **detected, investigated, and documented** every attack the way a SOC analyst would.

The Batman theme is the story. The skills are real: Active Directory, SIEM engineering, attack simulation mapped to **MITRE ATT&CK**, detection engineering, and incident reporting.

---

## 🗺️ Lab Architecture

```mermaid
flowchart LR
  you["💻 Analyst laptop<br/>(macOS)"] -->|"RDP, locked to my IP only"| dc

  subgraph azure["Azure · rg-gotham"]
    subgraph vnet["vnet-gotham · 10.0.1.0/24"]
      dc["WAYNE-DC01<br/>Domain Controller + DNS<br/>10.0.1.4"]
      ws["WAYNE-WS01<br/>Employee workstation"]
      bat["BATCOMPUTER<br/>Wazuh SIEM<br/>(Phase 2)"]
      kali["ARKHAM<br/>Kali attacker<br/>(Phase 3)"]
    end
  end

  dc --- ws
  ws -.->|logs| bat
  dc -.->|logs| bat
  kali -.->|attacks| ws
```

| Machine | Role | OS |
|---|---|---|
| `WAYNE-DC01` | Domain controller for `wayne.local`, DNS | Windows Server 2022 |
| `WAYNE-WS01` | Employee workstation (the villains' favourite target) | Windows Server 2022 |
| `BATCOMPUTER` | SIEM: collects and analyzes every log in Gotham | Ubuntu + Wazuh |
| `ARKHAM` | Attacker machine | Kali Linux |

---

## 🃏 The Rogues Gallery: Attacks Simulated

Each villain represents a real attacker technique from the [MITRE ATT&CK](https://attack.mitre.org/) framework.

| Villain | Attack style | MITRE ATT&CK techniques | Case file |
|---|---|---|---|
| 🎭 **Scarecrow** | Phishing and malicious documents: fear makes users click | T1566 Phishing, T1204 User Execution | *coming soon* |
| ❓ **The Riddler** | Reconnaissance: mapping the network, one clue at a time | T1087 Account Discovery, T1018 Remote System Discovery, T1482 Domain Trust Discovery | *coming soon* |
| 🐧 **The Penguin** | Credential theft: password spraying and dumping | T1110.003 Password Spraying, T1003 OS Credential Dumping | *coming soon* |
| 🪙 **Two-Face** | Persistence: a hidden second identity on the network | T1136 Create Account, T1053 Scheduled Task | *coming soon* |
| 🌿 **Poison Ivy** | Lateral movement: spreading from machine to machine | T1021 Remote Services | *coming soon* |
| 🤡 **The Joker** | Ransomware-style impact: chaos | T1490 Inhibit System Recovery, T1486 Data Encrypted for Impact | *coming soon* |

> All attacks are run **only against machines I own in this isolated lab**, using controlled simulation tools such as [Atomic Red Team](https://github.com/redcanaryco/atomic-red-team).

---

## 🛠️ Roadmap

- [ ] **Phase 1: Build Gotham.** Azure network, domain controller, `wayne.local` domain, users, and workstation → [guide](docs/phase-1-build-gotham.md)
- [ ] **Phase 2: The Batcomputer.** Deploy Wazuh SIEM, install Sysmon and agents, get logs flowing
- [ ] **Phase 3: The villains attack.** Kali attacker and Atomic Red Team simulations
- [ ] **Phase 4: Oracle responds.** Write a detection rule for every attack
- [ ] **Phase 5: Case files.** A professional incident report per villain

---

## 🧠 Skills Demonstrated

- **Cloud infrastructure:** Azure VMs, virtual networks, network security groups, cost management
- **Identity:** Active Directory Domain Services, DNS, OUs, users and groups, domain joins
- **Security monitoring:** SIEM deployment, log collection, Sysmon, alert triage
- **Threat-informed defense:** attack simulation mapped to MITRE ATT&CK
- **Detection engineering:** writing and tuning custom detection rules
- **Communication:** incident reports written for both technical and non-technical readers

---

## 📁 Repository Layout

```
docs/          Step-by-step build guides for each phase
scripts/       PowerShell and shell scripts used to build and run the lab
detections/    Custom detection rules (Phase 4)
case-files/    Incident reports, one per villain (Phase 5)
screenshots/   Evidence and build screenshots
```

---

## 💰 Running It on a Student Budget

The whole lab runs on an **Azure for Students** subscription. To make the credit last:
- VMs are **deallocated** whenever I'm not using them ([`scripts/gotham-power.sh`](scripts/gotham-power.sh))
- **Auto-shutdown** is enabled on every VM as a safety net
- Budget alerts at 50%, 80%, and 90% of the credit
- Small-disk OS images and burstable B-series VM sizes

---

## ⚠️ Disclaimer

This is an educational lab. Every attack technique here was run in an isolated environment I own and control. Wayne Enterprises, Gotham, and all characters are fictional (and belong to DC Comics); no real organizations or people are involved.
