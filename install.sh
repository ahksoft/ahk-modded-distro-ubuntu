#!/data/data/com.termux/files/usr/bin/sh

# --------------------------
# Colors
# --------------------------
C='\e[1;36m'   # Cyan
Y='\e[1;33m'   # Yellow
G='\e[1;32m'   # Green
R='\e[1;31m'   # Red
W='\e[0m'      # Reset

banner(){
    clear
    printf "${C} █████╗  ██╗  ██╗██╗  ██╗\n"
    printf "██╔══██╗ ██║  ██║██║ ██╔╝\n"
    printf "███████║ ███████║█████╔╝ \n"
    printf "██╔══██║ ██╔══██║██╔═██╗ \n"
    printf "██║  ██║ ██║  ██║██║  ██╗\n"
    printf "╚═╝  ╚═╝ ╚═╝  ╚═╝╚═╝  ╚═╝\n${W}"
    printf "${Y}                Developed By Abir Hasan AHK\n${W}"
}

# --------------------------
# Detect shell
# --------------------------
detect_shell(){
    CURRENT_SHELL=$(basename "$SHELL")
    if [ "$CURRENT_SHELL" = "zsh" ]; then
        SHELL_RC="$HOME/.zshrc"
    else
        SHELL_RC="$HOME/.bashrc"
    fi
}
detect_shell

CHROOT=$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu
username="root"

# --------------------------
# Ubuntu install / reset
# --------------------------
install_ubuntu(){
    echo
    if [[ -d "$CHROOT" ]]; then
        echo -e "${Y}Reset recommended. Reset Ubuntu? (y/n):${W}"
        read reset_choice
        if [ "$reset_choice" = "y" ]; then
            echo -e "${G}Resetting Ubuntu...${W}"
            proot-distro reset ubuntu
        else
            echo -e "${G}Skipping reset. Using existing installation...${W}"
        fi
    else
        echo -e "${G}Installing Ubuntu...${W}"
        pkg update -y
        pkg install -y proot-distro
        proot-distro install ubuntu
    fi
}

# --------------------------
# Install XFCE Desktop
# --------------------------
install_desktop(){
    echo -e "${G}Installing XFCE Desktop...${W}"
    cat > $CHROOT/root/.bashrc <<- EOF
apt-get update
apt install -y udisks2
rm -rf /var/lib/dpkg/info/udisks2.postinst
echo "" >> /var/lib/dpkg/info/udisks2.postinst
dpkg --configure -a
apt-mark hold udisks2
apt-get install -y xfce4 gnome-terminal nautilus dbus-x11 tigervnc-standalone-server pulseaudio
echo "vncserver -geometry 1280x720 -xstartup /usr/bin/startxfce4" >> /usr/local/bin/vncstart
echo "vncserver -kill :* ; rm -rf /tmp/.X1-lock ; rm -rf /tmp/.X11-unix/X1" >> /usr/local/bin/vncstop
chmod +x /usr/local/bin/vncstart
chmod +x /usr/local/bin/vncstop
sleep 2
exit
EOF
    proot-distro login ubuntu
    rm -rf $CHROOT/root/.bashrc
}

# --------------------------
# Add user (ubuntu default)
# --------------------------
adding_user(){
    echo -e "${G}Adding a User...${W}"
    cat > $CHROOT/root/.bashrc <<- EOF
apt-get update
apt-get install -y sudo wget
sleep 2
useradd -m -s /bin/bash ubuntu
echo "ubuntu:ubuntu" | chpasswd
echo "ubuntu  ALL=(ALL:ALL) ALL" >> /etc/sudoers.d/ubuntu
sleep 2
exit
EOF
    proot-distro login ubuntu
    echo "proot-distro login --user ubuntu ubuntu" > $PREFIX/bin/ubuntu
    chmod +x $PREFIX/bin/ubuntu
    rm $CHROOT/root/.bashrc
    username="ubuntu"
}

# --------------------------
# Install Theme
# --------------------------
install_theme(){
    echo -e "${G}Installing Theme...${W}"
    user_home="$CHROOT/home/$username"
    [ -f "$user_home/.bashrc" ] && mv "$user_home/.bashrc" "$user_home/.bashrc.bak"

    echo "wget https://raw.githubusercontent.com/ahksoft/ahk-modded-distro-ubuntu/main/theme/theme.sh ; bash theme.sh; exit" >> "$user_home/.bashrc"

    ubuntu

    rm -f "$user_home/theme.sh"*
    rm -f "$user_home/.bashrc"
    [ -f "$user_home/.bashrc.bak" ] && mv "$user_home/.bashrc.bak" "$user_home/.bashrc"

    cp "$user_home/.bashrc" "$CHROOT/root/.bashrc"
    sed -i 's/32/31/g' "$CHROOT/root/.bashrc"
}

# --------------------------
# Sound fix
# --------------------------
sound_fix(){
    echo -e "${G}Fixing Sound...${W}"
    pkg update -y
    pkg install -y x11-repo pulseaudio
    cat > $HOME/.bashrc <<- EOF
pulseaudio --start \
    --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" \
    --exit-idle-time=-1
EOF
}

# --------------------------
# Create x11start / x11stop
# --------------------------
create_x11start(){
    echo -e "${G}Creating x11start and x11stop commands...${W}"
    cat > $PREFIX/bin/x11start <<- 'EOF'
#!/data/data/com.termux/files/usr/bin/sh
# Launch Termux:X11 app if installed
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 &
sleep 4
# Start pulseaudio
pulseaudio --start \
    --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" \
    --exit-idle-time=-1 >/dev/null 2>&1 &
# Export display and start XFCE
export DISPLAY=:0
proot-distro login --user ubuntu ubuntu -- /usr/bin/startxfce4 >/dev/null 2>&1 &
EOF
    chmod +x $PREFIX/bin/x11start

    cat > $PREFIX/bin/x11stop <<- 'EOF'
#!/data/data/com.termux/files/usr/bin/sh
# Kill pulseaudio
pkill pulseaudio
# Kill proot-distro XFCE session
pkill -f startxfce4
# Kill Termux:X11 if possible
am force-stop com.termux.x11 >/dev/null 2>&1
EOF
    chmod +x $PREFIX/bin/x11stop
}

# --------------------------
# Final Banner
# --------------------------
final_banner(){
    banner
    echo
    echo -e "${G}Installation completed${W}\n"
    echo -e "${Y}Commands:${W}"
    echo -e "  ${C}ubuntu${W}    - To start Ubuntu shell"
    echo -e "  ${C}vncstart${W}  - To start VNC server (inside Ubuntu)"
    echo -e "  ${C}vncstop${W}   - To stop VNC server (inside Ubuntu)"
    echo -e "  ${C}x11start${W}  - To start XFCE on Termux:X11"
    echo -e "  ${C}x11stop${W}   - To stop XFCE + Termux:X11"
    rm -rf ~/install.sh
}

# --------------------------
# Script execution
# --------------------------
banner
install_ubuntu
install_desktop
adding_user
install_theme
sound_fix
create_x11start
final_banner
