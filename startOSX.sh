#!/bin/bash

#Load config file
source "${BASH_SOURCE%/*}/config"

#Get Devices IOMMU IDs
GPUIOMMU=$(lspci -n | grep -oE -m 1 ".{0,100}$GPUVID:$GPUPID.{0,0}" | cut -c 1-7)
HDMIOMMU=$(lspci -n | grep -oE -m 1 ".{0,100}$GPUVID:$HDMIPID.{0,0}" | cut -c 1-7)
CN0IOMMU=$(lspci -n | grep -oE -m 1 ".{0,100}$CONA0VID:$CONA0PID.{0,0}" | cut -c 1-7)
CN1IOMMU=$(lspci -n | grep -oE -m 1 ".{0,100}$CONA0VID:$CONA1PID.{0,0}" | cut -c 1-7)
CN2IOMMU=$(lspci -n | grep -oE -m 1 ".{0,100}$CONA0VID:$CONA2PID.{0,0}" | cut -c 1-7)
CN3IOMMU=$(lspci -n | grep -oE -m 1 ".{0,100}$CONA0VID:$CONA3PID.{0,0}" | cut -c 1-7)
CN4IOMMU=$(lspci -n | grep -oE -m 1 ".{0,100}$CONA0VID:$CONA4PID.{0,0}" | cut -c 1-7)
CN5IOMMU=$(lspci -n | grep -oE -m 1 ".{0,100}$CONA0VID:$CONA5PID.{0,0}" | cut -c 1-7)
CN6IOMMU=$(lspci -n | grep -oE -m 1 ".{0,100}$CONA0VID:$CONA6PID.{0,0}" | cut -c 1-7)
CN7IOMMU=$(lspci -n | grep -oE -m 1 ".{0,100}$CONA0VID:$CONA7PID.{0,0}" | cut -c 1-7)
CN8IOMMU=$(lspci -n | grep -oE -m 1 ".{0,100}$CONB0VID:$CONB0PID.{0,0}" | cut -c 1-7)

#Logout from main user
pkill -9 -u pipe
systemctl stop sddm

#Unbind Devices
echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind

echo -n "0000:$GPUIOMMU" > /sys/bus/pci/drivers/amdgpu/unbind
echo -n "0000:$HDMIOMMU" > /sys/bus/pci/drivers/snd_hda_intel/unbind
echo -n "0000:$CN0IOMMU" > /sys/bus/pci/drivers/uhci_hcd/unbind
echo -n "0000:$CN1IOMMU" > /sys/bus/pci/drivers/uhci_hcd/unbind
echo -n "0000:$CN2IOMMU" > /sys/bus/pci/drivers/uhci_hcd/unbind
echo -n "0000:$CN3IOMMU" > /sys/bus/pci/drivers/ehci-pci/unbind
echo -n "0000:$CN4IOMMU" > /sys/bus/pci/drivers/uhci_hcd/unbind
echo -n "0000:$CN5IOMMU" > /sys/bus/pci/drivers/uhci_hcd/unbind
echo -n "0000:$CN6IOMMU" > /sys/bus/pci/drivers/uhci_hcd/unbind
echo -n "0000:$CN7IOMMU" > /sys/bus/pci/drivers/ehci-pci/unbind
echo -n "0000:$CN8IOMMU" > /sys/bus/pci/drivers/xhci_hcd/unbind

modprobe vfio-pci

echo -n "$GPUVID $GPUPID" > /sys/bus/pci/drivers/vfio-pci/new_id
echo -n "$GPUVID $HDMIPID" > /sys/bus/pci/drivers/vfio-pci/new_id
echo -n "$CONA0VID $CONA0PID" > /sys/bus/pci/drivers/vfio-pci/new_id
echo -n "$CONA0VID $CONA1PID" > /sys/bus/pci/drivers/vfio-pci/new_id
echo -n "$CONA0VID $CONA2PID" > /sys/bus/pci/drivers/vfio-pci/new_id
echo -n "$CONA0VID $CONA3PID" > /sys/bus/pci/drivers/vfio-pci/new_id
echo -n "$CONA0VID $CONA4PID" > /sys/bus/pci/drivers/vfio-pci/new_id
echo -n "$CONA0VID $CONA5PID" > /sys/bus/pci/drivers/vfio-pci/new_id
echo -n "$CONA0VID $CONA6PID" > /sys/bus/pci/drivers/vfio-pci/new_id
echo -n "$CONA0VID $CONA7PID" > /sys/bus/pci/drivers/vfio-pci/new_id
echo -n "$CONB0VID $CONB0PID" > /sys/bus/pci/drivers/vfio-pci/new_id

#Start the VM
qemu-system-x86_64 \
    -runas vm \
    -nographic -vga none -parallel none -serial none \
    -enable-kvm \
    -m 8G \
    -machine q35,accel=kvm \
    -smp 8,cores=4,threads=2,sockets=1 \
    -cpu Penryn,vendor=GenuineIntel,kvm=on,+sse3,+sse4.2,+aes,+invtsc \
    -device isa-applesmc,osk="$OSK" \
    -smbios type=2 \
    -drive if=pflash,format=raw,readonly,file="$OVMF/OVMF_CODE.fd" \
    -drive if=pflash,format=raw,file="$OVMF/OVMF_VARS-1024x768.fd" \
    -device ioh3420,bus=pcie.0,addr=1c.0,multifunction=on,port=1,chassis=1,id=root.1 \
    -device pcie-root-port,port=0x10,chassis=2,id=pci.1,bus=pcie.0,multifunction=on,addr=0x2 \
    -device pcie-root-port,port=0x12,chassis=4,id=pci.3,bus=pcie.0,addr=0x2.0x2 \
    -device pcie-root-port,port=0x13,chassis=5,id=pci.4,bus=pcie.0,addr=0x2.0x3 \
    -device pcie-root-port,port=0x14,chassis=6,id=pci.5,bus=pcie.0,addr=0x2.0x4 \
    -device pcie-root-port,port=0x8,chassis=7,id=pci.6,bus=pcie.0,multifunction=on,addr=0x1 \
    -device pcie-root-port,port=0x9,chassis=8,id=pci.7,bus=pcie.0,addr=0x1.0x1 \
    -device pcie-pci-bridge,id=pci.8,bus=pci.5,addr=0x0 \
    -device vfio-pci,host="$GPUIOMMU",bus=root.1,addr=00.0,multifunction=on,x-vga=on,romfile="$VBIOS/Ellesmere.rom" \
    -device vfio-pci,host="$HDMIOMMU",bus=pcie.0 \
    -device vfio-pci,host="$CN0IOMMU",bus=root.1 \
    -device vfio-pci,host="$CN1IOMMU",bus=root.1 \
    -device vfio-pci,host="$CN2IOMMU",bus=root.1 \
    -device vfio-pci,host="$CN3IOMMU",bus=root.1 \
    -device vfio-pci,host="$CN4IOMMU",bus=root.1 \
    -device vfio-pci,host="$CN5IOMMU",bus=root.1 \
    -device vfio-pci,host="$CN6IOMMU",bus=root.1 \
    -device vfio-pci,host="$CN7IOMMU",bus=root.1 \
    -device vfio-pci,host="$CN8IOMMU",bus=root.1 \
    -netdev user,id=net0 \
    -device e1000-82545em,netdev=net0,id=net0,mac=52:54:00:c9:18:27 \
    -drive id=ESP,file="$IMGS/ESP.qcow2",format=qcow2,cache=writeback,if=virtio \
    -drive id=SystemDisk,file="$IMGS/MHDD.qcow2",format=qcow2,cache=writeback,if=virtio
    
#Rebind Devices to host
echo -n "0000:$GPUIOMMU" > /sys/bus/pci/drivers/vfio-pci/unbind
echo -n "0000:$HDMIOMMU" > /sys/bus/pci/drivers/vfio-pci/unbind
echo -n "0000:$CN0IOMMU" > /sys/bus/pci/drivers/vfio-pci/unbind
echo -n "0000:$CN1IOMMU" > /sys/bus/pci/drivers/vfio-pci/unbind
echo -n "0000:$CN2IOMMU" > /sys/bus/pci/drivers/vfio-pci/unbind
echo -n "0000:$CN3IOMMU" > /sys/bus/pci/drivers/vfio-pci/unbind
echo -n "0000:$CN4IOMMU" > /sys/bus/pci/drivers/vfio-pci/unbind
echo -n "0000:$CN5IOMMU" > /sys/bus/pci/drivers/vfio-pci/unbind
echo -n "0000:$CN6IOMMU" > /sys/bus/pci/drivers/vfio-pci/unbind
echo -n "0000:$CN7IOMMU" > /sys/bus/pci/drivers/vfio-pci/unbind
echo -n "0000:$CN8IOMMU" > /sys/bus/pci/drivers/vfio-pci/unbind

echo -n "$GPUVID $GPUPID" > /sys/bus/pci/drivers/vfio-pci/remove_id
echo -n "$GPUVID $HDMIPID" > /sys/bus/pci/drivers/vfio-pci/remove_id
echo -n "$CONA0VID $CONA0PID" > /sys/bus/pci/drivers/vfio-pci/remove_id
echo -n "$CONA0VID $CONA1PID" > /sys/bus/pci/drivers/vfio-pci/remove_id
echo -n "$CONA0VID $CONA2PID" > /sys/bus/pci/drivers/vfio-pci/remove_id
echo -n "$CONA0VID $CONA3PID" > /sys/bus/pci/drivers/vfio-pci/remove_id
echo -n "$CONA0VID $CONA4PID" > /sys/bus/pci/drivers/vfio-pci/remove_id
echo -n "$CONA0VID $CONA5PID" > /sys/bus/pci/drivers/vfio-pci/remove_id
echo -n "$CONA0VID $CONA6PID" > /sys/bus/pci/drivers/vfio-pci/remove_id
echo -n "$CONA0VID $CONA7PID" > /sys/bus/pci/drivers/vfio-pci/remove_id
echo -n "$CONB0VID $CONB0PID" > /sys/bus/pci/drivers/vfio-pci/remove_id

modprobe -r vfio-pci

echo -n "0000:$HDMIOMMU" > /sys/bus/pci/drivers/snd_hda_intel/bind
echo -n "0000:$GPUIOMMU" > /sys/bus/pci/drivers/amdgpu/bind
echo -n "0000:$CN0IOMMU" > /sys/bus/pci/drivers/uhci_hcd/bind
echo -n "0000:$CN1IOMMU" > /sys/bus/pci/drivers/uhci_hcd/bind
echo -n "0000:$CN2IOMMU" > /sys/bus/pci/drivers/uhci_hcd/bind
echo -n "0000:$CN3IOMMU" > /sys/bus/pci/drivers/ehci-pci/bind
echo -n "0000:$CN4IOMMU" > /sys/bus/pci/drivers/uhci_hcd/bind
echo -n "0000:$CN5IOMMU" > /sys/bus/pci/drivers/uhci_hcd/bind
echo -n "0000:$CN6IOMMU" > /sys/bus/pci/drivers/uhci_hcd/bind
echo -n "0000:$CN7IOMMU" > /sys/bus/pci/drivers/ehci-pci/bind
echo -n "0000:$CN8IOMMU" > /sys/bus/pci/drivers/xhci_hcd/bind

#Start display manager
systemctl start sddm
