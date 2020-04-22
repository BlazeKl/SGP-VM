#!/bin/bash
keyboard="1a2c:427c"
mouse="1532:0020"
audio="1038:1228"
files=$HOME/VMs

echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind

echo -n "0000:03:00.0" > /sys/bus/pci/drivers/amdgpu/unbind
echo -n "0000:03:00.1" > /sys/bus/pci/drivers/snd_hda_intel/unbind

modprobe vfio-pci

echo -n "1002 67df" > /sys/bus/pci/drivers/vfio-pci/new_id
echo -n "1002 aaf0" > /sys/bus/pci/drivers/vfio-pci/new_id

qemu-system-x86_64 \
    -runas pipe \
    -nographic -vga none -parallel none -serial none \
    -enable-kvm -M q35 -m 8192 -cpu host -smp 8,sockets=1,cores=4,threads=2 \
    -bios /usr/share/qemu/bios.bin -vga none \
    -device ioh3420,bus=pcie.0,addr=1c.0,multifunction=on,port=1,chassis=1,id=root.1 \
    -device vfio-pci,host=03:00.0,bus=root.1,addr=00.0,multifunction=on,x-vga=on,romfile=$files/Ellesmere.rom \
    -device vfio-pci,host=03:00.1,bus=pcie.0 \
    -device virtio-net,netdev=vmnic -netdev user,id=vmnic \
    -hda /dev/sdc \
    -drive media=cdrom,file=$files/virtio.iso,id=cd1,if=none \
    -device ide-cd,bus=ide.1,drive=cd1 \
    -object input-linux,id=kbd,evdev=/dev/input/by-id/usb-COUGAR_Vantar_COUGAR_Vantar-event-kbd,grab_all=on,repeat=on \
    -object input-linux,id=kbd2,evdev=/dev/input/by-id/usb-COUGAR_Vantar_COUGAR_Vantar-if01-event-kbd,grab_all=on,repeat=on \
    -object input-linux,id=mouse-event,evdev=/dev/input/by-id/usb-Razer_Razer_Abyssus_1800-event-mouse \
    -object input-linux,id=kbd3,evdev=/dev/input/by-id/usb-Razer_Razer_Abyssus_1800-if01-event-kbd,grab_all=on,repeat=on
