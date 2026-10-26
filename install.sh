#!/bin/sh
# Install (or upgrade) the plasmoid for the current user.
cd "$(dirname "$0")" && kpackagetool6 -t Plasma/Applet -u package 2>/dev/null || kpackagetool6 -t Plasma/Applet -i package
