#!/bin/bash

#Functions
get_iommu(){
    local iommuID=$(lspci -n | grep -oE -m 1 ".{0,100}$1.{0,0}" | cut -c 1-7)
    echo $iommuID
}

get_kmodule(){
    local kname=$(file /sys/bus/pci/devices/0000:$1/driver | grep -oE "drivers.{0,99}" | cut -b 9-99)
    echo $kname
}

get_usbus(){
    local usbbus=$(lsusb | grep -oE "[1-9].{0,17}$1.{0,0}" | cut -c 1)
    echo $usbbus
}

get_usbid(){
    local usbid=$(lsusb | grep -oE "[1-9].{0,6}$1.{0,0}" | cut -c 1)
    echo $usbid
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

#Set basic VM command, modified later in the script to add devices
if [ "$_is_osx" == "true" ]; then
    start_VM="qemu-system-x86_64 
    -runas vm 
    -nographic -vga none -parallel none -serial none 
    -enable-kvm 
    -m $RAM 
    -machine q35,accel=kvm 
    -smp $(( $CORES * $THREADS )),cores=$CORES,threads=$THREADS,sockets=1 
    -cpu Penryn,vendor=GenuineIntel,kvm=on,+sse3,+sse4.2,+aes,+invtsc 
    -device isa-applesmc,osk=\"ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc\" 
    -smbios type=2 
    -drive if=pflash,format=raw,readonly,file=\"$OVMF/OVMF_CODE.fd\" 
    -drive if=pflash,format=raw,file=\"$OVMF/OVMF_VARS-1024x768.fd\" 
    -device ioh3420,bus=pcie.0,addr=1c.0,multifunction=on,port=1,chassis=1,id=root.1 
    -device pcie-root-port,port=0x10,chassis=2,id=pci.1,bus=pcie.0,multifunction=on,addr=0x2 
    -device pcie-root-port,port=0x12,chassis=4,id=pci.3,bus=pcie.0,addr=0x2.0x2 
    -device pcie-root-port,port=0x13,chassis=5,id=pci.4,bus=pcie.0,addr=0x2.0x3 
    -device pcie-root-port,port=0x14,chassis=6,id=pci.5,bus=pcie.0,addr=0x2.0x4 
    -device pcie-root-port,port=0x8,chassis=7,id=pci.6,bus=pcie.0,multifunction=on,addr=0x1 
    -device pcie-root-port,port=0x9,chassis=8,id=pci.7,bus=pcie.0,addr=0x1.0x1 
    -device pcie-pci-bridge,id=pci.8,bus=pci.5,addr=0x0 
    -netdev user,id=net0 
    -device e1000-82545em,netdev=net0,id=net0,mac=52:54:00:c9:18:27 
    -drive id=ESP,file=\"$_imgs/ESP.qcow2\",format=qcow2,cache=writeback,if=virtio 
    -drive id=SystemDisk,file=\"$_imgs/MHDD.qcow2\",format=qcow2,cache=writeback,if=virtio "
else
    start_VM="qemu-system-x86_64 
    -runas vm 
    -nographic -vga none -parallel none -serial none 
    -enable-kvm -M q35 -m $RAM 
    -cpu host,hv_relaxed,hv_time,kvm=off,hv_vendor_id=null,-hypervisor -smp $(( $CORES * $THREADS )),sockets=1,cores=$CORES,threads=$THREADS 
    -bios /usr/share/qemu/bios.bin -vga none 
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
fi

#Add advanced options
start_VM+="$_ext_parameters "

#Get Devices IOMMU IDs
GPUIOMMU=$(get_iommu $GPUID)
HDMIOMMU=$(get_iommu $HDMID)
start_VM+="-device vfio-pci,host=\"$GPUIOMMU\",bus=root.1,addr=00.0,multifunction=on,x-vga=on,romfile=\"$_vbios\" 
-device vfio-pci,host=\"$HDMIOMMU\",bus=pcie.0 "

if [ "$_pci_devices" == "true" ]; then
    for n in "${PCIID[@]}"; do
        PCIOMMU=$(get_iommu $n)
        start_VM+="-device vfio-pci,host=\"$PCIOMMU\",bus=root.1 "
    done
fi

#Kill Host display
if [ "$_exit_g" == "true" ]; then
    pkill -9 -u $_m_user
    systemctl stop $_d_manager
    echo 0 > /sys/class/vtconsole/vtcon0/bind
    echo 0 > /sys/class/vtconsole/vtcon1/bind
    echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind
fi

#Add USB Devices
if [ "$_usb_devices" == "true" ];then
    if [ "$_is_osx" == "true" ]; then
        start_VM+="-device ich9-usb-ehci1,id=usb,bus=pcie.0,addr=0x1d.0x7 
        -device ich9-usb-uhci1,masterbus=usb.0,firstport=0,bus=pcie.0,multifunction=on,addr=0x1d 
        -device ich9-usb-uhci2,masterbus=usb.0,firstport=2,bus=pcie.0,addr=0x1d.0x1 
        -device ich9-usb-uhci3,masterbus=usb.0,firstport=4,bus=pcie.0,addr=0x1d.0x2 "
    else
        start_VM+="-device qemu-xhci,p2=15,p3=15,id=usb,bus=pci.2,addr=0x0 "
    fi
    port=1
    for n in "${USBID[@]}"; do
        USB_BUS=$(get_usbus $n)
        USB_ID=$(get_usbid $n)
        start_VM+="-device usb-host,hostbus="$USB_BUS",hostaddr="$USB_ID",id=hostdev$port,bus=usb.0,port=$port "
        port=$((port + 1))
    done
fi

#Unbind PCI Devices
GPUKM1=$(get_kmodule $GPUIOMMU)
GPUKM2=$(get_kmodule $HDMIOMMU)
echo -n "0000:$GPUIOMMU" > /sys/bus/pci/devices/0000:$GPUIOMMU/driver/unbind
echo -n "0000:$HDMIOMMU" > /sys/bus/pci/devices/0000:$HDMIOMMU/driver/unbind

if [ "$_pci_devices" == "true" ]; then
    for n in "${PCIID[@]}"; do
        PCIOMMU=$(get_iommu $n)
        PCIKRN+=("$(get_kmodule $PCIOMMU)")
        echo -n "0000:$PCIOMMU" > /sys/bus/pci/devices/0000:$PCIOMMU/driver/unbind
    done
fi

modprobe vfio-pci

echo -n "${GPUID/:/ }" > /sys/bus/pci/drivers/vfio-pci/new_id
echo -n "${HDMID/:/ }" > /sys/bus/pci/drivers/vfio-pci/new_id

if [ "$_pci_devices" == "true" ]; then
    for n in "${PCIID[@]}"; do
        echo -n "${n/:/ }" > /sys/bus/pci/drivers/vfio-pci/new_id
    done
fi

#Start the VM
echo $start_VM > $VMDIR/command
eval $start_VM
     
    
#Rebind Devices to host
echo -n "0000:$GPUIOMMU" > /sys/bus/pci/drivers/vfio-pci/unbind
echo -n "0000:$HDMIOMMU" > /sys/bus/pci/drivers/vfio-pci/unbind

if [ "$_pci_devices" == "true" ]; then
    for n in "${PCIID[@]}"; do
        PCIOMMU=$(get_iommu $n)
        echo -n "0000:$PCIOMMU" > /sys/bus/pci/drivers/vfio-pci/unbind
    done
fi

echo -n "${GPUID/:/ }" > /sys/bus/pci/drivers/vfio-pci/remove_id
echo -n "${HDMID/:/ }" > /sys/bus/pci/drivers/vfio-pci/remove_id

if [ "$_pci_devices" == "true" ]; then
    for n in "${PCIID[@]}"; do
        echo -n "${n/:/ }" > /sys/bus/pci/drivers/vfio-pci/remove_id
    done
fi

modprobe -r vfio-pci

echo -n "0000:$GPUIOMMU" > /sys/bus/pci/drivers/$GPUKM1/bind
echo -n "0000:$HDMIOMMU" > /sys/bus/pci/drivers/$GPUKM2/bind

if [ "$_pci_devices" == "true" ]; then
    num=0
    for n in "${PCIID[@]}"; do
        PCIOMMU=$(get_iommu $n)
        echo -n "0000:$PCIOMMU" > /sys/bus/pci/drivers/${PCIKRN[$num]}/bind
        num=$((num + 1))
    done
fi

#Start display manager if killed
if [ "$_exit_g" == "true" ]; then
    systemctl start $_d_manager
fi
