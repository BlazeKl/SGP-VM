#!/bin/bash
files=.

pkill -9 -u pipe
systemctl stop sddm

echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind

echo -n "0000:03:00.0" > /sys/bus/pci/drivers/amdgpu/unbind
echo -n "0000:03:00.1" > /sys/bus/pci/drivers/snd_hda_intel/unbind

modprobe vfio-pci

echo -n "1002 67df" > /sys/bus/pci/drivers/vfio-pci/new_id
echo -n "1002 aaf0" > /sys/bus/pci/drivers/vfio-pci/new_id

qemu-system-x86_64 \
    -runas vm \
    -nographic -parallel none -serial none \
    -enable-kvm -M q35 -m 8192 -cpu host -smp 6,sockets=1,cores=6,threads=1 
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
    -device vfio-pci,host=03:00.0,bus=root.1,addr=00.0,multifunction=on,x-vga=on,romfile=$files/Ellesmere.rom \
    -device vfio-pci,host=03:00.1,bus=pcie.0 \
    -device virtio-net,netdev=vmnic -netdev user,id=vmnic \
    -hda /dev/sdc \
    -device usb-host,hostbus=6,hostaddr=2,id=hostdev0,bus=usb.0,port=1 \
    -device usb-host,hostbus=6,hostaddr=3,id=hostdev1,bus=usb.0,port=2 \
    -device usb-host,hostbus=8,hostaddr=2,id=hostdev2,bus=usb.0,port=3 
    
#   -drive media=cdrom,file=$files/virtio.iso,id=cd1,if=none \
#   -device ide-cd,bus=ide.1,drive=cd1 \
    
echo -n "0000:03:00.0" > /sys/bus/pci/drivers/vfio-pci/unbind
echo -n "0000:03:00.1" > /sys/bus/pci/drivers/vfio-pci/unbind

echo -n 1002 67df > /sys/bus/pci/drivers/vfio-pci/remove_id
echo -n 1002 aaf0 > /sys/bus/pci/drivers/vfio-pci/remove_id

modprobe -r vfio-pci

echo -n "0000:03:00.1" > /sys/bus/pci/drivers/snd_hda_intel/bind
echo -n "0000:03:00.0" > /sys/bus/pci/drivers/amdgpu/bind

systemctl start sddm
