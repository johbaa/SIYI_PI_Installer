# FlightCore Control Platform

Current release candidate: 4.3.0 RC5 / Factory V64.

Fresh install from macOS:
```bash
cd ~/Downloads
curl -fsSL -o FlightCore_Install.command https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/main/install.sh
chmod +x FlightCore_Install.command
./FlightCore_Install.command
```
The launcher confirms the Pi IP, waits for SSH, pins GitHub main, prestarts/verifies the live port-8090 Progress WebUI, and opens it automatically. Existing FlightCore systems upgrade through System -> Software update.
