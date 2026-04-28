# docs/architecture.md
# Zero Trust Lab — Architecture Reference
#
# Framework: NIST SP 800-207 Zero Trust Architecture
# Reference: csrc.nist.gov/publications/detail/sp/800-207/final

---

## Three-Layer Model

```
+-------------------------------------------------------------+
|  NETWORK LAYER                                              |
|  OPNsense 26.1 VM on Node 3 (N100, <NODE3_IP>)            |
|  WAN: ISP  |  LAN trunk: vmbr0  |  Ceph: <CEPH_VLAN_CIDR>    |
|  Policy Enforcement Point (PEP) — NIST SP 800-207          |
+-------------------------------------------------------------+
         |  VLAN 10 mgmt    |  VLAN 20 trust   |  VLAN 30 workloads
+--------v--------+ +-------v--------+ +--------v---------+
| MANAGEMENT VLAN | | TRUST VLAN     | | WORKLOAD VLAN    |
| <MGMT_VLAN_CIDR>    | | <TRUST_VLAN_CIDR>   | | <WORKLOAD_VLAN_CIDR>     |
|                 | |                | |                  |
| Node 1 NUC      | | Authentik VM   | | Application VMs  |
| <NODE1_IP>      | | <AUTHENTIK_IP>     | |                  |
| Node 2 N150     | |                | |                  |
| <NODE2_IP>      | | OpenBao VM     | |                  |
| Node 3 N100     | | <OPENBAO_IP>     | |                  |
| <NODE3_IP>      | |                | |                  |
+-----------------+ +----------------+ +------------------+
```

---

## Component Roles

### OPNsense 26.1 (Policy Enforcement Point)

- Hosted as a VM on Node 3 (N100 4-NIC appliance)
- NIC2: WAN, NIC3: LAN trunk (VLAN tagging), NIC1: Proxmox mgmt
- Firewall rules enforce inter-VLAN traffic policies
- Default deny between trust VLAN and workload VLAN
- Only Authentik-validated sessions permitted through

### Authentik 2024.12 (Policy Decision Point / Identity Provider)

- Hosted as a VM on Node 2 (N150, trust VLAN)
- Provides: OIDC, SAML 2.0, LDAP proxy, RADIUS proxy
- Enforces MFA on all authentication flows
- Issues short-lived OIDC tokens (15 min access, 1 hour refresh)
- Integrates with OpenBao for certificate issuance

### OpenBao 2.1 (Secrets Management / PKI)

- Hosted as a VM on Node 2 (N150, trust VLAN)
- Two-tier PKI: Root CA (10 years) + Intermediate CA (5 years)
- Issues service certificates for mTLS (30-day max, 7-day default)
- Per-service access policies (see policies/openbao/)
- Audit log forwarded to Wazuh

### Tailscale (Remote Access)

- Retained for remote access to the homelab management VLAN
- Does not replace internal ZTA controls — provides encrypted tunnel only
- Future: replace with Authentik OIDC + OPNsense ZTNA proxy

---

## Authentication Flows

### Flow 1 — User authentication to a workload service

```
1. User → OPNsense (HTTPS)
2. OPNsense redirects to Authentik (OIDC Authorization Code flow)
3. Authentik: identity check + MFA
4. Authentik issues OIDC token (15 min TTL)
5. User presents token to OPNsense
6. OPNsense validates token with Authentik (introspection endpoint)
7. OPNsense forwards request to workload
```

### Flow 2 — Service-to-service (mTLS)

```
1. Service A requests certificate from OpenBao PKI
   POST /v1/pki-int/issue/internal-services
   (authenticated with AppRole token, scoped policy)
2. OpenBao issues cert signed by Intermediate CA
3. Service A presents cert to Service B
4. Service B validates cert against Intermediate CA chain
5. Connection established with mutual TLS
```

### Flow 3 — Certificate issuance for HTTPS endpoints

```
1. Ansible playbook calls OpenBao API with service AppRole token
2. OpenBao validates token against service policy
3. OpenBao issues 7-day certificate (CN = service.lab.local)
4. Certificate deployed to service via Ansible
5. Renewal automated via systemd timer (renew at day 6)
```

---

## Network Firewall Rules (OPNsense)

| Source | Destination | Port | Action | Justification |
|---|---|---|---|---|
| any | OPNsense WAN | 443 | ALLOW | HTTPS entry point |
| Management VLAN | Trust VLAN | 8200 | ALLOW | OpenBao API (admin only) |
| Management VLAN | Trust VLAN | 9000,9443 | ALLOW | Authentik UI (admin only) |
| Trust VLAN | Management VLAN | any | DENY | Trust layer cannot reach mgmt |
| Trust VLAN | Workload VLAN | 443 | ALLOW | mTLS service communication |
| Workload VLAN | Trust VLAN | 8200 | ALLOW | Services fetch certs from OpenBao |
| Workload VLAN | Trust VLAN | 9443 | ALLOW | Services validate tokens with Authentik |
| any | any | any | DENY | Default deny |

---

## NIST SP 800-207 Mapping

| SP 800-207 Requirement | Implementation |
|---|---|
| 2.1 All data sources treated as resources | All services behind Authentik OIDC |
| 2.2 All communication secured | mTLS between services, TLS 1.3 minimum |
| 2.3 Per-session access granted | OIDC tokens 15 min TTL, no persistent sessions |
| 2.4 Access determined by dynamic policy | Authentik flows + OPNsense rules |
| 2.5 Monitor and measure asset integrity | Wazuh agent on all VMs, OpenBao audit log |
| 2.6 Strict authentication and authorization | MFA on all Authentik flows |
| 2.7 Collect data to improve posture | Wazuh dashboards, OpenBao metrics |

---

## Deployment Sequence

```
1. terraform apply          # Provision Authentik and OpenBao VMs
2. ansible-playbook ...     # Deploy OpenBao (--tags openbao)
3. bao operator init        # Manual: initialize OpenBao, save unseal keys
4. bao operator unseal (x3) # Manual: unseal
5. ansible-playbook ...     # Configure PKI (--tags pki)
6. ansible-playbook ...     # Deploy Authentik (--tags authentik)
7. Configure OPNsense rules # Manual: apply firewall rules from table above
8. Test authentication flow # See docs/testing.md
```
