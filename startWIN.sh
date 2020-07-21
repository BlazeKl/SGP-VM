#!/bin/bash

#Functions
get_iommu(){
    local iommuID=$(lspci -n | grep -oE -m 1 ".{0,100}$1:$2.{0,0}" | cut -c 1-7)
    echo $iommuID
}

#Load config file
source "${BASH_SOURCE%/*}/config"

#Set basic VM command, modified later in the script to add devices
start_VM="qemu-system-x86_64 \
    -runas vm \
    -nographic -vga none -parallel none -serial none \
    -enable-kvm -M q35 -m $RAM -cpu host,hv_relaxed,hv_time,kvm=off,hv_vendor_id=null,-hypervisor -smp $(( $CORES * $THREADS )),sockets=1,cores=$CORES,threads=$THREADS \
    -bios /usr/share/qemu/bios.bin -vga none \
    -device ioh3420,bus=pcie.0,addr=1c.0,multifunction=on,port=1,chassis=1,id=root.1 \
    -device pcie-root-port,port=0x10,chassis=2,id=pci.1,bus=pcie.0,multifunction=on,addr=0x2 \
    -device pcie-root-port,port=0x12,chassis=4,id=pci.3,bus=pcie.0,addr=0x2.0x2 \
    -device pcie-root-port,port=0x13,chassis=5,id=pci.4,bus=pcie.0,addr=0x2.0x3 \
    -device pcie-root-port,port=0x14,chassis=6,id=pci.5,bus=pcie.0,addr=0x2.0x4 \
    -device pcie-root-port,port=0x8,chassis=7,id=pci.6,bus=pcie.0,multifunction=on,addr=0x1 \
    -device pcie-root-port,port=0x9,chassis=8,id=pci.7,bus=pcie.0,addr=0x1.0x1 \
    -device pcie-pci-bridge,id=pci.8,bus=pci.5,addr=0x0 \
    -device virtio-net,netdev=vmnic -netdev user,id=vmnic \
    -drive file=/dev/sdc,format=raw,cache=writeback,if=virtio \
    -drive file=\"$IMGS/WHDD.qcow2\",format=qcow2,cache=writethrough,if=virtio \
"

#Get Devices IOMMU IDs
GPUIOMMU=$(get_iommu $GPUVID $GPUPID)
HDMIOMMU=$(get_iommu $GPUVID $HDMIPID)
CN0IOMMU=$(get_iommu $CONA0VID $CONA0PID)
CN1IOMMU=$(get_iommu $CONA0VID $CONA1PID)
CN2IOMMU=$(get_iommu $CONA0VID $CONA2PID)
CN3IOMMU=$(get_iommu $CONA0VID $CONA3PID)
CN4IOMMU=$(get_iommu $CONA0VID $CONA4PID)
CN5IOMMU=$(get_iommu $CONA0VID $CONA5PID)
CN6IOMMU=$(get_iommu $CONA0VID $CONA6PID)
CN7IOMMU=$(get_iommu $CONA0VID $CONA7PID)

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

start_VM+="-device vfio-pci,host=\"$GPUIOMMU\",bus=root.1,addr=00.0,multifunction=on,x-vga=on,romfile=\"$VBIOS\" \
    -device vfio-pci,host=\"$HDMIOMMU\",bus=pcie.0 \
    -device vfio-pci,host=\"$CN0IOMMU\",bus=root.1 \
    -device vfio-pci,host=\"$CN1IOMMU\",bus=root.1 \
    -device vfio-pci,host=\"$CN2IOMMU\",bus=root.1 \
    -device vfio-pci,host=\"$CN3IOMMU\",bus=root.1 \
    -device vfio-pci,host=\"$CN4IOMMU\",bus=root.1 \
    -device vfio-pci,host=\"$CN5IOMMU\",bus=root.1 \
    -device vfio-pci,host=\"$CN6IOMMU\",bus=root.1 \
    -device vfio-pci,host=\"$CN7IOMMU\",bus=root.1 \
"

#Start the VM    
eval $start_VM
     
    
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

modprobe -r vfio-pci

echo -n "0000:$GPUIOMMU" > /sys/bus/pci/drivers/amdgpu/bind
echo -n "0000:$HDMIOMMU" > /sys/bus/pci/drivers/snd_hda_intel/bind
echo -n "0000:$CN0IOMMU" > /sys/bus/pci/drivers/uhci_hcd/bind
echo -n "0000:$CN1IOMMU" > /sys/bus/pci/drivers/uhci_hcd/bind
echo -n "0000:$CN2IOMMU" > /sys/bus/pci/drivers/uhci_hcd/bind
echo -n "0000:$CN3IOMMU" > /sys/bus/pci/drivers/ehci-pci/bind
echo -n "0000:$CN4IOMMU" > /sys/bus/pci/drivers/uhci_hcd/bind
echo -n "0000:$CN5IOMMU" > /sys/bus/pci/drivers/uhci_hcd/bind
echo -n "0000:$CN6IOMMU" > /sys/bus/pci/drivers/uhci_hcd/bind
echo -n "0000:$CN7IOMMU" > /sys/bus/pci/drivers/ehci-pci/bind

#Start display manager
systemctl start sddm
