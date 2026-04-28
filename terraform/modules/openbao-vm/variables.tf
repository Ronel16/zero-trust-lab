variable "proxmox_node"    { type = string }
variable "ubuntu_template" { type = string }
variable "vmid"            { type = number }
variable "cores"           { type = number; default = 2 }
variable "memory"          { type = number; default = 2048 }
variable "bridge"          { type = string }
variable "vlan_tag"        { type = number }
variable "ip_address"      { type = string }
variable "gateway"         { type = string }
variable "ssh_public_key"  { type = string }
variable "cloud_init_user" { type = string; default = "ubuntu" }
