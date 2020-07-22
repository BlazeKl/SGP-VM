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

### qcow2 options

use the following options for better IO performance on qcow2 images
```
qemu-img create -o lazy_refcounts=on,preallocation=metadata -f qcow2 WHDD.qcow2 64G
```

for max performance do full preallocation
```
qemu-img create -o lazy_refcounts=on,preallocation=full -f qcow2 WHDD.qcow2 64G
```
