# SGP-VM
Single GPU Passthrough QEMU/KVM script for AMD Radeon RX 470 4GB

### Windows Scripts

Included batch files are needed on the virtual machine to avoid AMDGPU reset bug, Win 10 Pro is needed

https://forum.level1techs.com/t/linux-host-windows-guest-gpu-passthrough-reinitialization-fix/121097

### Using another user

Using another user on TTY with sudo permissions is useful to avoid errors with DEs like Plasma 5

### OSX Script

Thanks to https://github.com/foxlet/macOS-Simple-KVM

### Kernel parameters

The following kernel parameters are needed for the VM
```
intel_iommu=on iommu=pt vfio_iommu_type1.allow_unsafe_interrupts=1 kvm.ignore_msrs=1
```
### TODO

- [x] Rebind GPU (Reset bug)
- [x] Better USB Passthrough
- [x] Audio (USB)
- [x] Fix OSX USB
- [ ] Fix secondary vga monitor corruption (OSX)
