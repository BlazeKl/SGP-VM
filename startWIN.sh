#!/bin/bash

#Load config file
source "${BASH_SOURCE%/*}/config"

#Get GPU IOMMU Group
GPUIOMMU=$(lspci -n | grep -oE -m 1 ".{0,100}$GPUVID:$GPUPID.{0,0}" | cut -c 1-7)
HDMIOMMU=$(lspci -n | grep -oE -m 1 ".{0,100}$GPUVID:$HDMIPID.{0,0}" | cut -c 1-7)

#Get USB Bus and ID
BUS0=$(lsusb | grep -oE "[1-9].{0,17}$USB0.{0,0}" | cut -c 1)
ID0=$(lsusb | grep -oE "[1-9].{0,6}$USB0.{0,0}" | cut -c 1)

BUS1=$(lsusb | grep -oE "[1-9].{0,17}$USB1.{0,0}" | cut -c 1)
ID1=$(lsusb | grep -oE "[1-9].{0,6}$USB1.{0,0}" | cut -c 1)

BUS2=$(lsusb | grep -oE "[1-9].{0,17}$USB2.{0,0}" | cut -c 1)
ID2=$(lsusb | grep -oE "[1-9].{0,6}$USB2.{0,0}" | cut -c 1)

BUS3=$(lsusb | grep -oE "[1-9].{0,17}$USB3.{0,0}" | cut -c 1)
ID3=$(lsusb | grep -oE "[1-9].{0,6}$USB3.{0,0}" | cut -c 1)

BUS4=$(lsusb | grep -oE "[1-9].{0,17}$USB4.{0,0}" | cut -c 1)
ID4=$(lsusb | grep -oE "[1-9].{0,6}$USB4.{0,0}" | cut -c 1)

#Logout from main user
pkill -9 -u pipe
systemctl stop sddm

#Unbind GPU
echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind

echo -n "0000:$GPUIOMMU" > /sys/bus/pci/drivers/amdgpu/unbind
echo -n "0000:$HDMIOMMU" > /sys/bus/pci/drivers/snd_hda_intel/unbind

modprobe vfio-pci

echo -n "$GPUVID $GPUPID" > /sys/bus/pci/drivers/vfio-pci/new_id
echo -n "$GPUVID $HDMIPID" > /sys/bus/pci/drivers/vfio-pci/new_id

#Start the VM
qemu-system-x86_64 \
    -runas vm \
    -nographic -vga none -parallel none -serial none \
    -enable-kvm -M q35 -m 8192 -cpu host,hv_relaxed,hv_time,kvm=off,hv_vendor_id=null,-hypervisor -smp 10,sockets=1,cores=5,threads=2 \
    -bios /usr/share/qemu/bios.bin -vga none \
    -device ioh3420,bus=pcie.0,addr=1c.0,multifunction=on,port=1,chassis=1,id=root.1 \
    -device pcie-root-port,port=0x10,chassis=2,id=pci.1,bus=pcie.0,multifunction=on,addr=0x2 \
    -device pcie-root-port,port=0x11,chassis=3,id=pci.2,bus=pcie.0,addr=0x2.0x1 \
    -device pcie-root-port,port=0x12,chassis=4,id=pci.3,bus=pcie.0,addr=0x2.0x2 \
    -device pcie-root-port,port=0x13,chassis=5,id=pci.4,bus=pcie.0,addr=0x2.0x3 \
    -device pcie-root-port,port=0x14,chassis=6,id=pci.5,bus=pcie.0,addr=0x2.0x4 \
    -device pcie-root-port,port=0x8,chassis=7,id=pci.6,bus=pcie.0,multifunction=on,addr=0x1 \
    -device pcie-root-port,port=0x9,chassis=8,id=pci.7,bus=pcie.0,addr=0x1.0x1 \
    -device pcie-pci-bridge,id=pci.8,bus=pci.5,addr=0x0 \
    -device qemu-xhci,p2=15,p3=15,id=usb,bus=pci.2,addr=0x0 \
    -device vfio-pci,host="$GPUIOMMU",bus=root.1,addr=00.0,multifunction=on,x-vga=on,romfile="$VBIOS/Ellesmere.rom" \
    -device vfio-pci,host="$HDMIOMMU",bus=pcie.0 \
    -device virtio-net,netdev=vmnic -netdev user,id=vmnic \
    -drive file=/dev/sdc,format=raw,cache=writeback,if=virtio \
    -drive file="$IMGS/WHDD.qcow2",format=qcow2,cache=writethrough,if=virtio \
    -device usb-host,hostbus="$BUS0",hostaddr="$ID0",id=hostdev0,bus=usb.0,port=1 \
    -device usb-host,hostbus="$BUS1",hostaddr="$ID1",id=hostdev1,bus=usb.0,port=2 \
    -device usb-host,hostbus="$BUS2",hostaddr="$ID2",id=hostdev2,bus=usb.0,port=3 \
    -device usb-host,hostbus="$BUS3",hostaddr="$ID3",id=hostdev3,bus=usb.0,port=4 \
    -device usb-host,hostbus="$BUS4",hostaddr="$ID4",id=hostdev4,bus=usb.0,port=5 

#Rebind GPU to host
echo -n "0000:$GPUIOMMU" > /sys/bus/pci/drivers/vfio-pci/unbind
echo -n "0000:$HDMIOMMU" > /sys/bus/pci/drivers/vfio-pci/unbind

echo -n "$GPUVID $GPUPID" > /sys/bus/pci/drivers/vfio-pci/remove_id
echo -n "$GPUVID $HDMIPID" > /sys/bus/pci/drivers/vfio-pci/remove_id

modprobe -r vfio-pci

echo -n "0000:$HDMIOMMU" > /sys/bus/pci/drivers/snd_hda_intel/bind
echo -n "0000:$GPUIOMMU" > /sys/bus/pci/drivers/amdgpu/bind

#Start display manager
systemctl start sddm
