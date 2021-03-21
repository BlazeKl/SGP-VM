#!/bin/bash

#Functions
get_iommu(){
    local iommuID=$(lspci -n | grep -oE -m 1 ".{0,100}$1.{0,0}" | cut -c 1-7)
    echo -n $iommuID
}

get_kmodule(){
    local kname=$(file /sys/bus/pci/devices/0000:$1/driver | grep -oE "drivers.{0,99}" | cut -b 9-99)
    echo -n $kname
}

get_usbus(){
    local usbbus=$(lsusb | grep -oE "[1-9].{0,17}$1.{0,0}" | cut -c 1)
    echo -n $usbbus
}

get_usbid(){
    local usbid=$(lsusb | grep -oE "[1-9].{0,6}$1.{0,0}" | cut -c 1)
    echo -n $usbid
}

#Load config file
if [ "$1" == "" ] && [ -f "${BASH_SOURCE%/*}/default.cfg" ]; then
    source "${BASH_SOURCE%/*}/default.cfg"
elif [ -f "${BASH_SOURCE%/*}/$1.cfg" ]; then
    source "${BASH_SOURCE%/*}/$1.cfg"
else
    echo "Config file not found, exiting"
    exit 1
fi

#Set QEMU arguments, modified later in the script to add devices
args="-name sgpvm,debug-threads=on
    -runas $_current_user
    -nographic -vga none -parallel none -serial none -nodefaults
    -enable-kvm -M q35 -m $_RAM -mem-prealloc -no-hpet
    -cpu $_CPU
    -smp $(( $_CORES * $_THREADS )),sockets=1,cores=$_CORES,threads=$_THREADS
    -drive if=pflash,format=raw,readonly,file=/usr/share/ovmf/x64/OVMF_CODE.fd
    -device ioh3420,bus=pcie.0,addr=1c.0,multifunction=on,port=1,chassis=1,id=root.1
    -device virtio-net,netdev=vmnic -netdev user,id=vmnic "

#Add config file arguments
args+="$_ext_parameters "

#Get Devices IOMMU IDs
GPUIOMMU=$(get_iommu $GPUID)
HDMIOMMU=$(get_iommu $HDMID)
if [ -n "$GPUIOMMU" ] && [ -n "$HDMIOMMU" ]; then 
    args+="-device vfio-pci,host=$GPUIOMMU,bus=root.1,addr=00.0,multifunction=on,romfile=$_vbios
    -device vfio-pci,host=$HDMIOMMU,bus=root.1,addr=00.1 "
else
    echo "[$GPUID/$HDMID]GPU not found, exiting"
    exit 1
fi

if [ "$_pci_devices" == "true" ]; then
    for n in "${PCIID[@]}"; do
        PCIOMMU=$(get_iommu $n)
        if [ -n "$PCIOMMU" ]; then
            args+="-device vfio-pci,host=$PCIOMMU,bus=root.1 "
        else
            echo "[$n]Device not found"
        fi
    done
fi

#Kill Host display
if [ "$_exit_display" == "true" ]; then
    systemctl stop $_display_manager.service
    if [ "$_display_manager" == "gdm" ]; then
        killall gdm-x-session
    fi
    echo -n "0" > /sys/class/vtconsole/vtcon0/bind
    echo -n "0" > /sys/class/vtconsole/vtcon1/bind
    echo -n "efi-framebuffer.0" > /sys/bus/platform/drivers/efi-framebuffer/unbind
    sleep 5
fi

#Add USB Devices
if [ "$_usb_devices" == "true" ]; then
    args+="-device qemu-xhci,p2=15,p3=15,id=usb "
    port=1
    for n in "${USBID[@]}"; do
        USB_BUS=$(get_usbus $n)
        USB_ID=$(get_usbid $n)
        if [ -n "$USB_BUS" ] && [ -n "$USB_ID" ]; then
            args+="-device usb-host,hostbus=$USB_BUS,hostaddr=$USB_ID,id=hostdev$port,bus=usb.0,port=$port "
            port=$((port + 1))
        else
            echo "[$n]Device not found"
        fi
    done
fi

#Bind PCI Devices to vfio-pci if needed
modprobe vfio-pci
GPUKM1=$(get_kmodule $GPUIOMMU)
GPUKM2=$(get_kmodule $HDMIOMMU)

if [ "$GPUKM1" != "vfio-pci" ] && [ "$GPUKM2" != "vfio-pci" ]; then
    if [ "$GPUKM1" == "nvidia" ]; then
        echo "Nvidia driver detected, removing modules..."
        modprobe -r nvidia_drm
        modprobe -r nvidia_modeset
        modprobe -r nvidia_uvm
        modprobe -r nvidia
    fi
    virsh nodedev-detach pci_0000_${GPUIOMMU//[:.]/_}
    virsh nodedev-detach pci_0000_${HDMIOMMU//[:.]/_}
fi

if [ "$_pci_devices" == "true" ]; then
    for n in "${PCIID[@]}"; do
        PCIOMMU=$(get_iommu $n)
        if [ -n "$PCIOMMU" ]; then
            PCIKRN+=("$(get_kmodule $PCIOMMU)")
            if [ "$(get_kmodule $PCIOMMU)" != "vfio-pci" ]; then
                virsh nodedev-detach pci_0000_${PCIOMMU//[:.]/_}
            fi
        fi
    done
fi

#Start the VM
echo $args > $VMDIR/arguments
qemu-system-x86_64 $args

#Rebind Devices to host if needed
if [ "$GPUKM1" != "vfio-pci" ] && [ "$GPUKM2" != "vfio-pci" ]; then
    virsh nodedev-reattach pci_0000_${HDMIOMMU//[:.]/_}
    virsh nodedev-reattach pci_0000_${GPUIOMMU//[:.]/_}
    if [ "$GPUKM1" == "nvidia" ]; then
        echo "Nvidia driver detected, reloading modules..."
        modprobe nvidia_drm
        modprobe nvidia_modeset
        modprobe nvidia_uvm
        modprobe nvidia
    fi
fi

if [ "$_pci_devices" == "true" ]; then
    num=0
    for n in "${PCIID[@]}"; do
        PCIOMMU=$(get_iommu $n)
        if [ -n "$PCIOMMU" ]; then
            if [ "${PCIKRN[$num]}" != "vfio-pci" ]; then
                virsh nodedev-reattach pci_0000_${PCIOMMU//[:.]/_}
            fi
            num=$((num + 1))
        fi
    done
fi

#Start display manager if killed
if [ "$_exit_display" == "true" ]; then
    echo 1 > /sys/class/vtconsole/vtcon0/bind
    echo 1 > /sys/class/vtconsole/vtcon1/bind
    echo -n "efi-framebuffer.0" > /sys/bus/platform/drivers/efi-framebuffer/bind
    systemctl isolate graphical.target
fi