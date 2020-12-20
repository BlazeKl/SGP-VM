# SGP-VM
Single GPU Passthrough QEMU/KVM script

### Requirements

* A GPU BIOS dump
* QEMU
* OVMF
* Libvirt
* VirtIO drivers for the guest
* Virtualization extensions (IOMMU)

### Usage

The config file needs to be edited first to ensure everything will work, use ```default.cfg``` as a template

To start the VM after editing the config file. do
```sudo nohup ./startVM.sh > ./output.log```

### Config files

To use another custom config files (like ```win.cfg```) do ```sudo nohup ./startVM.sh win > ./output.log```
```default.cfg``` is used if no config file is specified

### Kernel parameters

The following kernel parameters are needed for the VM
```
intel_iommu=on iommu=pt vfio_iommu_type1.allow_unsafe_interrupts=1 kvm.ignore_msrs=1
```

### AMD GPU reset bug on Windows guest

A great fix for the AMD GPU reset bug is available here 
https://github.com/gnif/vendor-reset

if vendor-reset doesn't work, this workaround is still an option
https://forum.level1techs.com/t/linux-host-windows-guest-gpu-passthrough-reinitialization-fix/121097

### qcow2 options

use the following options for better IO performance on qcow2 images
```
qemu-img create -o lazy_refcounts=on,preallocation=metadata -f qcow2 WHDD.qcow2 64G
```

for max performance do full preallocation
```
qemu-img create -o lazy_refcounts=on,preallocation=full -f qcow2 WHDD.qcow2 64G
```
