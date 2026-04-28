# docs/threat-model-stride.md
# Zero Trust Lab — STRIDE Threat Model
#
# Methodology: STRIDE (Microsoft, 1999 — Shostack 2014 "Threat Modeling: Designing for Security")
# Scope: Trust layer (Authentik + OpenBao) and network enforcement (OPNsense)
# Date: 2026-04
# Reference: NIST SP 800-207 Section 2.3 — Threat Model for ZTA

---

## System Overview

```
[User / Device]
      |
      | HTTPS / Tailscale
      v
[OPNsense]  <-- Policy Enforcement Point (PEP)
      |
      | Trust VLAN <TRUST_VLAN_CIDR>
      +-----------> [Authentik <AUTHENTIK_IP>]  <-- Policy Decision Point (PDP) / IdP
      |
      +-----------> [OpenBao <OPENBAO_IP>]   <-- Secrets / PKI (PDP data plane)
      |
      v
[Workloads on Proxmox cluster]
```

---

## Trust Boundaries

| Boundary | Description |
|---|---|
| TB-1 | External internet → OPNsense WAN |
| TB-2 | OPNsense → Trust VLAN (<TRUST_VLAN_CIDR>) |
| TB-3 | Trust VLAN → Management VLAN (<MGMT_VLAN_CIDR>) |
| TB-4 | Trust VLAN → Workload VLAN |
| TB-5 | Authentik → OpenBao (internal trust layer) |

---

## STRIDE Analysis

### S — Spoofing (usurpation d'identite)

| ID | Component | Threat | Mitigation | Status |
|---|---|---|---|---|
| S-01 | Authentik | Attacker replays a stolen OIDC token to impersonate a user | Short token TTL (15 min), token binding, MFA enforced on all flows | Mitigated |
| S-02 | OpenBao | Attacker uses a stolen OpenBao token from another service | Per-service policies, token use-limit, AppRole auth with secret-id wrap | Mitigated |
| S-03 | OPNsense | Attacker spoofs the management IP to bypass firewall rules | Management VLAN isolated, SSH key-only access, no password auth | Mitigated |
| S-04 | mTLS | Service presents a forged client certificate | All certs issued by OpenBao Intermediate CA only, CRL checked on each connection | Mitigated |

### T — Tampering (modification)

| ID | Component | Threat | Mitigation | Status |
|---|---|---|---|---|
| T-01 | Terraform state | State file modified to alter infrastructure definitions | State stored locally with file permissions 0600; move to encrypted S3 backend for production | Partial |
| T-02 | Ansible playbooks | Playbook modified in transit or in repo to deploy malicious config | Git signed commits, devsecops-pipeline scan on every PR | Mitigated |
| T-03 | OpenBao data | OpenBao data directory modified while service is stopped | File system permissions 0750 owned by openbao user, consider dm-crypt for data-at-rest | Partial |
| T-04 | Docker Compose | Authentik compose file replaced with a malicious version | File deployed via Ansible with checksum validation, devsecops-pipeline scan | Mitigated |

### R — Repudiation (deni d'action)

| ID | Component | Threat | Mitigation | Status |
|---|---|---|---|---|
| R-01 | OpenBao | Admin denies having unsealed and accessed secrets | OpenBao audit log enabled (file backend), logs forwarded to Wazuh | Partial — audit log template present but disabled by default |
| R-02 | Authentik | User denies having authenticated | Authentik event log with IP, user agent, timestamp | Mitigated |
| R-03 | OPNsense | Admin denies firewall rule change | OPNsense syslog forwarded to centralized log (Wazuh) | Mitigated |

### I — Information Disclosure (divulgation)

| ID | Component | Threat | Mitigation | Status |
|---|---|---|---|---|
| I-01 | OpenBao API | Secrets exposed via unauthenticated API call | All endpoints require valid token, network access restricted to trust VLAN | Mitigated |
| I-02 | Authentik .env | PostgreSQL password and secret_key exposed in .env file | File mode 0600, deployed via ansible-vault encrypted variables | Mitigated |
| I-03 | Terraform state | Proxmox password in plaintext in state file | Sensitive = true flag, state file gitignored, avoid storing passwords in state | Partial |
| I-04 | TLS — initial bootstrap | OpenBao starts without TLS on first deploy (tls_disable = true) | TLS disabled only during bootstrap; re-deploy with TLS after PKI is configured | Accepted (lab) |

### D — Denial of Service

| ID | Component | Threat | Mitigation | Status |
|---|---|---|---|---|
| D-01 | Authentik | PostgreSQL disk fill causes Authentik outage | Disk quotas on data directory, Proxmox VM disk alerts | Partial |
| D-02 | OpenBao | OpenBao sealed after host reboot — all services blocked | Manual unseal documented; auto-unseal with cloud KMS as future improvement | Accepted (lab) |
| D-03 | OPNsense VM | Proxmox Node 3 failure brings down OPNsense and network | HA migration via Proxmox cluster — OPNsense VM can be migrated; Ceph ensures disk availability | Mitigated |

### E — Elevation of Privilege

| ID | Component | Threat | Mitigation | Status |
|---|---|---|---|---|
| E-01 | Authentik worker | Worker runs as root (Docker socket access) — container escape gives host root | Acceptable for lab; use rootless Docker or a dedicated socket proxy (dockerproxy) in production | Accepted (lab) |
| E-02 | OpenBao | Compromised service token used to escalate via broad policy | Each service has a scoped policy (see policies/openbao/); no service has admin policy | Mitigated |
| E-03 | Proxmox | Compromised VM escapes to Proxmox host via QEMU vulnerability | Regular Proxmox updates, no VMs with pcie passthrough to critical hardware on trust nodes | Mitigated |

---

## Risk Register

| ID | Risk | Likelihood | Impact | Priority |
|---|---|---|---|---|
| T-01 | Unencrypted Terraform state | Low (lab network) | High | Medium |
| T-03 | OpenBao data at rest unencrypted | Low | High | Medium |
| I-04 | TLS disabled during bootstrap | Low (short window) | Medium | Low |
| D-02 | Manual unseal after reboot | High | High | Medium — document unseal runbook |
| E-01 | Authentik worker runs as root | Medium | High | Medium — mitigate in production |

---

## NIST SP 800-207 ZTA Compliance Summary

| ZTA Principle | Implementation | Control |
|---|---|---|
| Verify explicitly (PE1) | Authentik MFA + OIDC on every access | S-01 |
| Least privilege (PE2) | Per-service OpenBao policies | E-02, S-02 |
| Assume breach (PE3) | OPNsense micro-segmentation, mTLS, audit logs | TB-2, TB-4, R-01 |
| Continuous verification | Authentik session timeout + token TTL | S-01 |
