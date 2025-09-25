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
# Add user (optional)
# --------------------------
adding_user(){
    echo -e "${Y}Do you want to add a new Ubuntu user? (y/n): ${W}"
    read create_user
    if [ "$create_user" = "y" ]; then
        echo -ne "${Y}Enter username: ${W}"
        read input_user
        username="$input_user"
    else
        username="root"
    fi

    echo -e "${G}Adding user $username...${W}"
    cat > $CHROOT/root/.bashrc <<- EOF
apt-get update
apt-get install -y sudo wget
sleep 2
if [ "$username" != "root" ]; then
    useradd -m -s /bin/bash $username
    echo "$username:ubuntu" | chpasswd
    echo "$username  ALL=(ALL:ALL) ALL" >> /etc/sudoers.d/$username
fi
sleep 2
exit
EOF
    proot-distro login ubuntu

    if [ "$username" != "root" ]; then
        echo "proot-distro login --user $username ubuntu" > $PREFIX/bin/ubuntu
    else
        echo "proot-distro login ubuntu" > $PREFIX/bin/ubuntu
    fi
    chmod +x $PREFIX/bin/ubuntu
    rm -rf $CHROOT/root/.bashrc
}

# --------------------------
# Install Theme
# --------------------------
install_theme(){
    echo -e "${G}Installing Theme...${W}"
    if [ "$username" = "root" ]; then
        user_home="$CHROOT/root"
    else
        user_home="$CHROOT/home/$username"
    fi

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

    if [ "$username" = "root" ]; then
        user_home="$CHROOT/root"
    else
        user_home="$CHROOT/home/$username"
    fi

    [ -f "$user_home/.bashrc" ] && mv "$user_home/.bashrc" "$user_home/.bashrc.bak"

    cat > "$user_home/.bashrc" <<- EOF
vncstart
sleep 4
DISPLAY=:1 firefox &
sleep 10
pkill -f firefox
vncstop
sleep 4
exit
EOF

    ubuntu
    rm -f "$user_home/.bashrc"
    [ -f "$user_home/.bashrc.bak" ] && mv "$user_home/.bashrc.bak" "$user_home/.bashrc"

    FIREFOX_DIR=$(find $user_home/.mozilla/firefox -name "*.default-esr" 2>/dev/null | head -n1)
    if [ -n "$FIREFOX_DIR" ]; then
        wget -O "$FIREFOX_DIR/user.js" https://raw.githubusercontent.com/ahksoft/ahk-modded-distro-ubuntu/main/fixes/user.js
    fi
}

# --------------------------
# Final Banner
# --------------------------
final_banner(){
    banner
    echo
    echo -e "${G}Installation completed${W}\n"
    echo -e "${Y}Commands:${W}"
    echo -e "  ${C}ubuntu${W}   - To start Ubuntu"
    echo -e "  ${C}vncstart${W} - To start VNC server (inside Ubuntu)"
    echo -e "  ${C}vncstop${W}  - To stop VNC server (inside Ubuntu)"
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
final_banner
