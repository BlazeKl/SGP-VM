# SGP-VM
Single GPU Passthrough VM script for RX 470

### Windows Scripts

Included batch files are needed on the virtual machine to avoid AMDGPU reset bug, Win 10 Pro is needed

https://forum.level1techs.com/t/linux-host-windows-guest-gpu-passthrough-reinitialization-fix/121097

### Using another user

Using another user on TTY with sudo permissions is useful to avoid errors with DEs like Plasma 5

### TODO

- [x] Rebind GPU (Reset bug)
- [x] Better USB Passthrough
- [x] Audio (USB)
