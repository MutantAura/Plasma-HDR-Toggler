# Plasma HDR Toggler

A KDE Plasma 6 widget that lists each connected display with a checkbox to toggle HDR on or off, plus its current HDR state and calibrated max nits.

HDR and wide colour gamut are switched together, as System Settings does.

## Requirements

- KDE Plasma 6 (Wayland) with `kscreen-doctor` (part of libkscreen)
- `python3`

## Install

No build step is needed. From the repo root:

```sh
./install.sh
```

This installs the widget for the current user with `kpackagetool6`. Then right-click the panel or desktop, choose **Add Widgets**, and search for "HDR Toggle". If it doesn't appear, restart the shell:

```sh
systemctl --user restart plasma-plasmashell
```

To uninstall: `kpackagetool6 -t Plasma/Applet -r org.mutantaura.hdrtoggle`

## Notes

- Monitor names are read from the display EDID.
- Max nits comes from the HDR calibration in `~/.config/kwinoutputconfig.json`.
