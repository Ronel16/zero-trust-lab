# terraform/environments/lab/main.tf
#
# Provisions the Zero Trust trust layer on Node 2 (N150):
#   - Authentik VM  (IdP / SSO / OIDC provider)
#   - OpenBao VM    (secrets management / PKI)
#
# Both VMs are placed on the trust VLAN (10.0.20.0/24) and isolated
# from the management network (10.0.10.0/24) via OPNsense firewall rules.

module "authentik" {
  source = "../../modules/authentik-vm"

  proxmox_node    = var.proxmox_node
  ubuntu_template = var.ubuntu_template
  vmid            = var.authentik_vmid
  cores           = var.authentik_cores
  memory          = var.authentik_memory

  bridge       = var.trust_bridge
  vlan_tag     = var.trust_vlan_tag
  ip_address   = var.authentik_ip
  gateway      = var.authentik_gw

  ssh_public_key  = var.ssh_public_key
  cloud_init_user = var.cloud_init_user
}

module "openbao" {
  source = "../../modules/openbao-vm"

  proxmox_node    = var.proxmox_node
  ubuntu_template = var.ubuntu_template
  vmid            = var.openbao_vmid
  cores           = var.openbao_cores
  memory          = var.openbao_memory

  bridge       = var.trust_bridge
  vlan_tag     = var.trust_vlan_tag
  ip_address   = var.openbao_ip
  gateway      = var.openbao_gw

  ssh_public_key  = var.ssh_public_key
  cloud_init_user = var.cloud_init_user
}
