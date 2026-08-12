# FlightCore Control Platform

Current release candidate: 4.3.0 RC4 / Factory V63.

## Fresh install from macOS

```bash
cd ~/Downloads
curl -fsSL -o FlightCore_Install.command https://raw.githubusercontent.com/johbaa/SIYI_PI_Installer/main/install.sh
chmod +x FlightCore_Install.command
./FlightCore_Install.command
```

The launcher asks you to confirm/edit the Pi IP, waits for SSH automatically, pins the current GitHub main commit, starts the fresh installer and automatically opens the live FlightCore installation Progress WebUI on port 8090. After the Pi reboots, continue in the First Setup Wizard.

Existing FlightCore systems upgrade through System -> Software update.
