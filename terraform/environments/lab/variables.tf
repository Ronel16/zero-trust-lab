variable "proxmox_api_url"  { type = string }
variable "proxmox_user"     { type = string; default = "root@pam" }
variable "proxmox_password" { type = string; sensitive = true }
variable "proxmox_node"     { type = string; default = "pve-node2" }
variable "ubuntu_template"  { type = string; default = "ubuntu-2404-template" }
variable "trust_vlan_tag"   { type = number; default = 20 }
variable "trust_bridge"     { type = string; default = "vmbr0" }
variable "authentik_vmid"   { type = number; default = 200 }
variable "authentik_ip"     { type = string; default = "10.0.20.10/24" }
variable "authentik_gw"     { type = string; default = "10.0.20.1" }
variable "authentik_cores"  { type = number; default = 2 }
variable "authentik_memory" { type = number; default = 4096 }
variable "openbao_vmid"     { type = number; default = 201 }
variable "openbao_ip"       { type = string; default = "10.0.20.11/24" }
variable "openbao_gw"       { type = string; default = "10.0.20.1" }
variable "openbao_cores"    { type = number; default = 2 }
variable "openbao_memory"   { type = number; default = 2048 }
variable "ssh_public_key"   { type = string }
variable "cloud_init_user"  { type = string; default = "ubuntu" }
