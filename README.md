# SGP-VM
Simple GPU Passthrough QEMU/KVM script

### GPU BIOS

A GPU BIOS dump needs to be added to the virtual machine to use it,

### AMDGPU reset bug

Batch script files are needed on the virtual machine to avoid AMDGPU reset bug, Win 10 Pro is needed

more info: https://forum.level1techs.com/t/linux-host-windows-guest-gpu-passthrough-reinitialization-fix/121097

### Config files

to use another custom config files (like win.cfg) do ```sudo ./startVM.sh win```
default.cfg is used if no config file is specified

### Using another user for single GPU passthrough

Using another user on TTY with sudo permissions is useful to avoid errors with some DEs
use ```_exit_g="true"``` to kill the host display

### OSX

Make an usable OSX qcow2 image (MHDD.qcow2) and copy ESP.qcow2 from https://github.com/foxlet/macOS-Simple-KVM
use ```_is_osx="true"``` to enable OSX compatible hardware

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
