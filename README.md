# SGP-VM
Single GPU Passthrough script for RX 470

### Windows Scripts

enablegpu.bat and disablegpu.bat are needed on the windows virtual machine to avoid AMDGPU reset bug
https://forum.level1techs.com/t/linux-host-windows-guest-gpu-passthrough-reinitialization-fix/121097

### Using another user

Using another user with sudo permissions is usefull to avoid errors with DEs like Plasma 5

### TODO

- [x] Rebind GPU (Reset bug!)
- [x] Better USB Passthrough
- [x] Audio
