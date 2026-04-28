# zero-trust-lab

[![DevSecOps Pipeline](https://github.com/Ronel16/zero-trust-lab/actions/workflows/devsecops.yml/badge.svg)](https://github.com/Ronel16/zero-trust-lab/actions/workflows/devsecops.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

Implementation of a Zero Trust Architecture on a three-node Proxmox homelab.
Provisions and configures the complete trust layer: Authentik (IdP), OpenBao
(secrets management and PKI), and OPNsense (network enforcement).

Aligned with NIST SP 800-207 Zero Trust Architecture.

---

## Architecture

```
[User / Device]
      |
      v HTTPS / Tailscale
[OPNsense 26.1]         -- Policy Enforcement Point (PEP)
      |
      +---> [Authentik 2024.12]  10.0.20.10  -- Identity Provider / PDP
      |
      +---> [OpenBao 2.1]        10.0.20.11  -- Secrets / PKI
      |
      v
[Proxmox workloads]     10.0.30.0/24
```

Full architecture documentation: [docs/architecture.md](docs/architecture.md)
STRIDE threat model: [docs/threat-model-stride.md](docs/threat-model-stride.md)

---

## Deployment

### Prerequisites

- Three-node Proxmox VE cluster
- Ubuntu 24.04 cloud-init template on Proxmox
- Terraform >= 1.9, Ansible >= 2.15
- SSH key pair

### 1. Provision VMs

```bash
cd terraform/environments/lab
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
# Set Proxmox password: export TF_VAR_proxmox_password="..."

terraform init
terraform plan
terraform apply
```

### 2. Deploy OpenBao

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/deploy-trust-layer.yml \
  --tags openbao
```

### 3. Initialize OpenBao (manual step)

```bash
ssh ubuntu@10.0.20.11
bao operator init -key-shares=5 -key-threshold=3
# Save the 5 unseal keys and root token securely (offline storage)

bao operator unseal   # run 3 times with different keys
export BAO_TOKEN=<root_token>
```

### 4. Configure PKI

```bash
ansible-playbook -i inventory/hosts.yml playbooks/deploy-trust-layer.yml \
  --tags pki --extra-vars "openbao_token=<root_token>"
```

### 5. Deploy Authentik

```bash
# Set secrets via ansible-vault
ansible-vault encrypt_string 'your_secret_key' --name 'authentik_secret_key'
ansible-vault encrypt_string 'your_pg_password' --name 'authentik_postgres_password'

ansible-playbook -i inventory/hosts.yml playbooks/deploy-trust-layer.yml \
  --tags authentik --ask-vault-pass
```

### 6. First Authentik login

Navigate to `http://10.0.20.10:9000/if/flow/initial-setup/` to set the
admin password.

---

## NIST SP 800-207 Compliance

| Requirement | Implementation |
|---|---|
| Verify explicitly | Authentik MFA + OIDC, short token TTL |
| Least privilege | Per-service OpenBao policies |
| Assume breach | OPNsense micro-segmentation, mTLS, Wazuh audit |
| Continuous verification | Token introspection on each request |

---

## Project Structure

```
zero-trust-lab/
├── terraform/
│   ├── environments/lab/     # Lab environment (Authentik + OpenBao VMs)
│   └── modules/
│       ├── authentik-vm/
│       └── openbao-vm/
├── ansible/
│   ├── inventory/
│   ├── roles/
│   │   ├── authentik/        # Deploy via Docker Compose
│   │   ├── openbao/          # Install and configure OpenBao
│   │   └── openbao-pki/      # Two-tier PKI (Root CA + Intermediate CA)
│   └── playbooks/
│       └── deploy-trust-layer.yml
├── policies/
│   └── openbao/              # Per-service HCL policies
├── docs/
│   ├── architecture.md
│   └── threat-model-stride.md
└── .github/workflows/
    └── devsecops.yml
```

---

## License

Apache License 2.0 — see [LICENSE](LICENSE).
