output "vm_ip" { value = var.ip_address }
output "vmid"  { value = proxmox_vm_qemu.authentik.vmid }
