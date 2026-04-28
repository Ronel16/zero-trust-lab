resource "proxmox_vm_qemu" "openbao" {
  name        = "openbao"
  desc        = "OpenBao secrets manager and PKI."
  target_node = var.proxmox_node
  clone       = var.ubuntu_template
  vmid        = var.vmid
  full_clone  = true
  agent       = 1
  cores       = var.cores
  sockets     = 1
  memory      = var.memory
  os_type     = "cloud-init"
  ipconfig0   = "ip=${var.ip_address},gw=${var.gateway}"
  ciuser      = var.cloud_init_user
  sshkeys     = var.ssh_public_key
  nameserver  = "1.1.1.1"
  network {
    model  = "virtio"
    bridge = var.bridge
    tag    = var.vlan_tag
  }
  disk {
    storage = "local-lvm"
    size    = "16G"
    type    = "scsi"
    ssd     = 1
    discard = "on"
  }
  tags = "openbao,trust-layer,pki,terraform"
  lifecycle {
    ignore_changes = [network, disk, clone]
  }
}
