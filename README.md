# SGP-VM
Single GPU Passthrough QEMU/KVM script

### Requirements

* A GPU BIOS dump
* QEMU
* OVMF
* Libvirt
* VirtIO drivers for the guest
* Virtualization extensions (IOMMU)

### AMD GPU reset bug on Windows guest

A great fix for the AMD GPU reset bug is available here 
https://github.com/gnif/vendor-reset

if vendor-reset doesn't work, this workaround is still an option
https://forum.level1techs.com/t/linux-host-windows-guest-gpu-passthrough-reinitialization-fix/121097

### Config files

To use another custom config files (like win.cfg) do ```sudo ./startVM.sh win```
default.cfg is used if no config file is specified

### Using another user for single GPU passthrough

For single GPU passthrough to work, the script needs to be run through another user on TTY to be able to kill the host display completely, the name of the user that runs the graphical environment needs to be specified on ```_logout_user=""```, use ```_exit_display="true"``` to kill the host display

Remember to save anything before starting the VM

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
