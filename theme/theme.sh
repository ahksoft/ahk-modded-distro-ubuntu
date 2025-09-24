#!/bin/bash

# --------------------------
# Colors
# --------------------------
R='\e[1;31m'
G='\e[1;32m'
Y='\e[1;33m'
W='\e[0m'
C='\e[1;36m'

# --------------------------
# Determine user home
# --------------------------
if [ -z "$username" ]; then
    username="root"
fi

if [ "$username" = "root" ]; then
    USER_HOME="$HOME"
else
    USER_HOME="/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/ubuntu/home/$username"
fi

echo -e "${G}Installing themes for user: $username${W}"

# --------------------------
# Install necessary packages
# --------------------------
sudo apt update
sudo apt install -y yaru-theme-gtk yaru-theme-icon ubuntu-wallpapers ubuntu-wallpapers-jammy ubuntu-wallpapers-impish \
plank dconf-cli xfce4-panel-profiles xfce4-appmenu-plugin git

# --------------------------
# Clone repo if missing
# --------------------------
THEME_REPO="$USER_HOME/ahk-modded-distro"
if [ ! -d "$THEME_REPO" ]; then
    git clone https://github.com/ahksoft/ahk-modded-distro-ubuntu "$THEME_REPO"
else
    echo -e "${Y}Theme repo already exists, skipping clone${W}"
fi

# --------------------------
# XFCE panel setup
# --------------------------
PANEL_DIR="$THEME_REPO/theme/panel"
if [ -d "$PANEL_DIR" ]; then
    cd "$PANEL_DIR" || exit
    if [ -f "config.txt" ]; then
        tar --sort=name --format ustar -cvjhf ubuntu.tar.bz2 config.txt
        mkdir -p "$USER_HOME/.local/share/xfce4-panel-profiles/"
        mv ubuntu.tar.bz2 "$USER_HOME/.local/share/xfce4-panel-profiles/"
        dbus-launch xfce4-panel-profiles load "$USER_HOME/.local/share/xfce4-panel-profiles/ubuntu.tar.bz2"
        echo -e "${G}XFCE panel profile installed${W}"
    else
        echo -e "${Y}config.txt not found, skipping panel setup${W}"
    fi
else
    echo -e "${Y}Panel folder not found, skipping XFCE panel setup${W}"
fi

# --------------------------
# Plank dock setup
# --------------------------
PLANK_DIR="$THEME_REPO/theme/plank"
if [ -d "$PLANK_DIR" ]; then
    mkdir -p "$USER_HOME/.config/autostart" \
             "$USER_HOME/.local/share/plank/themes" \
             "$USER_HOME/.config/plank/dock1/"

    [ -f "$PLANK_DIR/plank.desktop" ] && mv "$PLANK_DIR/plank.desktop" "$USER_HOME/.config/autostart/"
    [ -d "$PLANK_DIR/launchers" ] && mv "$PLANK_DIR/launchers" "$USER_HOME/.config/plank/dock1/"
    [ -d "$PLANK_DIR/Azeny" ] && mv "$PLANK_DIR/Azeny" "$USER_HOME/.local/share/plank/themes/"

    echo -e "${G}Plank dock installed${W}"
else
    echo -e "${Y}Plank folder not found, skipping dock setup${W}"
fi

# --------------------------
# VNC password setup
# --------------------------
echo
echo -e "${G}Create your VNC password${W}"
vncstart
sleep 60
vncstop

# --------------------------
# XFCE appearance configuration
# --------------------------
sleep 10
dbus-launch xfconf-query -c xfce4-desktop -np '/desktop-icons/style' -t 'int' -s '0'
sleep 10
dbus-launch xfconf-query -c xsettings -p /Net/ThemeName -s "Yaru-dark"
sleep 10
dbus-launch xfconf-query -c xfwm4 -p /general/theme -s "Yaru-dark"
sleep 10
dbus-launch xfconf-query -c xsettings -p /Net/IconThemeName -s "Yaru-dark"
sleep 10
dbus-launch xfconf-query -c xsettings -p /Gtk/CursorThemeName -s "Yaru-dark"
sleep 10
dbus-launch xfconf-query -c xfwm4 -p /general/show_dock_shadow -s false
sleep 10

# Set desktop wallpaper
WALLPAPER_KEY=$(dbus-launch xfconf-query -c xfce4-desktop -l | grep last-image | head -n1)
if [ -n "$WALLPAPER_KEY" ]; then
    dbus-launch xfconf-query -c xfce4-desktop -p "$WALLPAPER_KEY" -s /usr/share/backgrounds/warty-final-ubuntu.png
fi
sleep 10

# Load plank dock settings
if [ -f "$PLANK_DIR/dock.ini" ]; then
    cat "$PLANK_DIR/dock.ini" | dbus-launch dconf load /net/launchpad/plank/docks/dock1/
fi

# --------------------------
# Cleanup
# --------------------------
rm -rf "$THEME_REPO"
echo -e "${G}Theme installation completed successfully!${W}"
