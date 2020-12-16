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
    echo "Config file not found"
    exit 1
fi

#Set QEMU arguments, modified later in the script to add devices
args="-runas $_current_user
    -nographic -vga none -parallel none -serial none
    -enable-kvm -M q35 -m $RAM -mem-prealloc -no-hpet
    -cpu host,hv_time,hv_relaxed,hv_vapic,hv_spinlocks=0x1fff,hv_vendor_id=null,kvm=off,-hypervisor,migratable=no,+invtsc
    -smp $(( $CORES * $THREADS )),sockets=1,cores=$CORES,threads=$THREADS
    -drive if=pflash,format=raw,readonly,file=/usr/share/ovmf/x64/OVMF_CODE.fd
    -device ioh3420,bus=pcie.0,addr=1c.0,multifunction=on,port=1,chassis=1,id=root.1
    -device pcie-root-port,port=0x10,chassis=2,id=pci.1,bus=pcie.0,multifunction=on,addr=0x2
    -device pcie-root-port,port=0x11,chassis=3,id=pci.2,bus=pcie.0,addr=0x2.0x1
    -device pcie-root-port,port=0x12,chassis=4,id=pci.3,bus=pcie.0,addr=0x2.0x2
    -device pcie-root-port,port=0x13,chassis=5,id=pci.4,bus=pcie.0,addr=0x2.0x3
    -device pcie-root-port,port=0x14,chassis=6,id=pci.5,bus=pcie.0,addr=0x2.0x4
    -device pcie-root-port,port=0x8,chassis=7,id=pci.6,bus=pcie.0,multifunction=on,addr=0x1
    -device pcie-root-port,port=0x9,chassis=8,id=pci.7,bus=pcie.0,addr=0x1.0x1
    -device pcie-pci-bridge,id=pci.8,bus=pci.5,addr=0x0
    -device virtio-net,netdev=vmnic -netdev user,id=vmnic "

#Add advanced options
args+="$_ext_parameters "

#Get Devices IOMMU IDs
GPUIOMMU=$(get_iommu $GPUID)
HDMIOMMU=$(get_iommu $HDMID)
args+="-device vfio-pci,host=\"$GPUIOMMU\",bus=root.1,addr=00.0,multifunction=on,romfile=\"$_vbios\"
-device vfio-pci,host=\"$HDMIOMMU\",bus=pcie.0 "

if [ "$_pci_devices" == "true" ]; then
    for n in "${PCIID[@]}"; do
        PCIOMMU=$(get_iommu $n)
        if [ -z "$PCIOMMU" ]; then
            echo "[$n]Device not found"
        else
            args+="-device vfio-pci,host=\"$PCIOMMU\",bus=root.1 "
        fi
    done
fi

#Kill Host display
if [ "$_exit_display" == "true" ]; then
    pkill -9 -u $_logout_user
    systemctl isolate multi-user.target
    sleep 5
    echo -n "0" > /sys/class/vtconsole/vtcon0/bind
    echo -n "0" > /sys/class/vtconsole/vtcon1/bind
    echo -n "efi-framebuffer.0" > /sys/bus/platform/drivers/efi-framebuffer/unbind
fi

#Add USB Devices
if [ "$_usb_devices" == "true" ]; then
    args+="-device qemu-xhci,p2=15,p3=15,id=usb,bus=pci.2,addr=0x0 "
    port=1
    for n in "${USBID[@]}"; do
        USB_BUS=$(get_usbus $n)
        USB_ID=$(get_usbid $n)
        if [ -z "$USB_BUS" ] || [ -z "$USB_ID" ]; then
            echo "[$n]Device not found"
        else
            args+="-device usb-host,hostbus="$USB_BUS",hostaddr="$USB_ID",id=hostdev$port,bus=usb.0,port=$port "
            port=$((port + 1))
        fi
    done
fi

#Unbind PCI Devices
modprobe vfio-pci

GPUKM1=$(get_kmodule $GPUIOMMU)
GPUKM2=$(get_kmodule $HDMIOMMU)

echo -n "0000:$GPUIOMMU" > /sys/bus/pci/devices/0000:$GPUIOMMU/driver/unbind
echo -n "0000:$HDMIOMMU" > /sys/bus/pci/devices/0000:$HDMIOMMU/driver/unbind

echo -n "${GPUID/:/ }" > /sys/bus/pci/drivers/vfio-pci/new_id
echo -n "${HDMID/:/ }" > /sys/bus/pci/drivers/vfio-pci/new_id

if [ "$_pci_devices" == "true" ]; then
    for n in "${PCIID[@]}"; do
        PCIOMMU=$(get_iommu $n)
        if [ -n "$PCIOMMU" ]; then
            PCIKRN+=("$(get_kmodule $PCIOMMU)")
            echo -n "0000:$PCIOMMU" > /sys/bus/pci/devices/0000:$PCIOMMU/driver/unbind
            echo -n "${n/:/ }" > /sys/bus/pci/drivers/vfio-pci/new_id
        fi
    done
fi

#Start the VM
echo $args > $VMDIR/arguments
qemu-system-x86_64 $args

#Rebind Devices to host
echo -n "0000:$GPUIOMMU" > /sys/bus/pci/drivers/vfio-pci/unbind
echo -n "0000:$HDMIOMMU" > /sys/bus/pci/drivers/vfio-pci/unbind

echo -n "${GPUID/:/ }" > /sys/bus/pci/drivers/vfio-pci/remove_id
echo -n "${HDMID/:/ }" > /sys/bus/pci/drivers/vfio-pci/remove_id

echo -n "0000:$GPUIOMMU" > /sys/bus/pci/drivers/$GPUKM1/bind
echo -n "0000:$HDMIOMMU" > /sys/bus/pci/drivers/$GPUKM2/bind

if [ "$_pci_devices" == "true" ]; then
    num=0
    for n in "${PCIID[@]}"; do
        PCIOMMU=$(get_iommu $n)
        if [ -n "$PCIOMMU" ]; then
            echo -n "0000:$PCIOMMU" > /sys/bus/pci/drivers/vfio-pci/unbind
            echo -n "${n/:/ }" > /sys/bus/pci/drivers/vfio-pci/remove_id
            echo -n "0000:$PCIOMMU" > /sys/bus/pci/drivers/${PCIKRN[$num]}/bind
            num=$((num + 1))
        fi
    done
fi

modprobe -r vfio-pci

#Start display manager if killed
if [ "$_exit_display" == "true" ]; then
    sleep 5
    systemctl isolate graphical.target
fi