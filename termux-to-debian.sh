#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# Termux Debian XFCE Desktop with Hardware Acceleration - One Click Installer
# Author: Custom setup script
# Description: Installs and configures Debian with XFCE4 desktop and HW accel
###############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Change Termux repository for faster downloads
termux-change-repo

clear
echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Termux to Debian OS Linux Environment Auto Installer      ║"
echo "║  with Hardware Acceleration Support and more powerful.     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

print_warning "This script will install:"
echo "  • Termux X11 with hardware acceleration"
echo "  • Debian Linux (proot-distro)"
echo "  • XFCE4 Desktop Environment"
echo "  • Audio support (PulseAudio)"
echo "  • Auto-start configuration"
echo ""
read -p "Continue with installation? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "Installation cancelled"
    exit 1
fi

###############################################################################
# STEP 1: Update Termux and Install Base Packages
###############################################################################
echo ""
print_status "Step 1/7: Checking for proot-distro..."
sleep 2
if ! command -v proot-distro &> /dev/null; then
    print_status "proot-distro not found. Installing..."
    sleep 2
    pkg update -y && pkg upgrade -y
    pkg install -y proot-distro
    print_success "proot-distro installed"
else
    print_success "proot-distro already installed"
    sleep 2
    pkg update -y
fi

###############################################################################
# STEP 2: Install X11 and Required Packages
###############################################################################
echo ""
print_status "Step 2/7: Installing X11 and hardware acceleration packages..."
sleep 2
pkg install -y x11-repo
pkg install -y termux-x11-nightly proot-distro pulseaudio

# Try to install hardware acceleration packages (some may not be available)
print_status "Installing hardware acceleration support..."
sleep 2
pkg install -y virglrenderer-android 2>/dev/null || print_warning "virglrenderer-android not available"
pkg install -y mesa 2>/dev/null || print_warning "mesa not available"
pkg install -y vulkan-loader-android 2>/dev/null || print_warning "vulkan-loader-android not available"

# Alternative package names
pkg install -y libvirglrenderer 2>/dev/null || true
pkg install -y mesa-vulkan-icd-freedreno 2>/dev/null || true

print_success "X11 and available acceleration packages installed"
sleep 2

###############################################################################
# STEP 3: Check and Install Debian
###############################################################################
echo ""
print_status "Step 3/7: Checking for existing Debian installation..."
sleep 2

CHROOT=$PREFIX/var/lib/proot-distro/installed-rootfs/debian

if [ -d "$CHROOT" ]; then
    print_warning "Debian is already installed!"
    sleep 2
    echo ""
    echo "Options:"
    echo -e "${GREEN}yes  ✓  Reset Debian (clean install - recommended)${NC}"
    echo -e "${RED}no   X  Continue with existing Debian${NC}"
    echo ""
    read -p "Choose option (y/n): " -n 1 -r DEBIAN_CHOICE
    echo ""
    
    case $DEBIAN_CHOICE in
        n|N)
            print_success "Continuing with existing Debian installation"
            DEBIAN_EXISTS=true
            ;;
        y|Y)
            print_warning "Resetting Debian... This will delete all data!"
            proot-distro reset debian
            sleep 2
            print_status "Fresh Debian installed after reset"
            print_success "Fresh Debian ready"
            DEBIAN_EXISTS=false
            ;;
        *)
            print_error "Invalid option. Continuing with existing Debian."
            DEBIAN_EXISTS=true
            ;;
    esac
else
    print_status "Installing Debian Linux..."
    proot-distro install debian
    print_success "Debian installed"
    sleep 2
    DEBIAN_EXISTS=false
fi

###############################################################################
# STEP 4: Install XFCE4 in Debian
###############################################################################
echo ""
if [ "$DEBIAN_EXISTS" = true ]; then
    print_status "Step 4/7: Checking XFCE4 installation..."
    print_warning "Using existing Debian - skipping package installation"
    print_success "Will use existing packages"
else
    print_status "Step 4/7: Installing XFCE4 Desktop Environment (this may take a while)..."
    sleep 3

    proot-distro login debian -- bash -c "
        # Fix any broken dependencies first
        apt --fix-broken install -y || true
        dpkg --configure -a || true
        
        # Update package lists
        apt update && apt upgrade -y
        
        # Install core packages first (without xfce4-goodies to avoid dependency issues)
        DEBIAN_FRONTEND=noninteractive apt install -y \
            xfce4 \
            dbus-x11 \
            mesa-utils \
            libgl1-mesa-dri \
            libglx-mesa0 \
            mesa-vulkan-drivers \
            xfce4-terminal \
            nano \
            wget \
            curl
        
        # Install Firefox ESR separately (may not be available in all repos)
        DEBIAN_FRONTEND=noninteractive apt install -y firefox-esr || \
        DEBIAN_FRONTEND=noninteractive apt install -y firefox || \
        echo 'Firefox not available, skipping...'
        
        # Try to install optional xfce4 components individually
        # This avoids dependency issues
        for pkg in xfce4-screenshooter xfce4-taskmanager xfce4-clipman thunar-archive-plugin; do
            DEBIAN_FRONTEND=noninteractive apt install -y \$pkg 2>/dev/null || true
        done
        
        # Clean up
        apt autoremove -y
        apt clean
    "
    print_success "XFCE4 and applications installed"
fi
sleep 3

###############################################################################
# STEP 5: Create Startup Script
###############################################################################
echo ""
print_status "Step 5/7: Creating startup script..."
sleep 3

# Create x11 command in Debian to launch Termux X11 app
echo "# Launch Termux X11 main activity
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1
sleep 1" > $PREFIX/var/lib/proot-distro/installed-rootfs/debian/bin/x11
chmod +x $PREFIX/var/lib/proot-distro/installed-rootfs/debian/bin/x11

cat > ~/start-debian-x11.sh << 'STARTUP_SCRIPT'
#!/data/data/com.termux/files/usr/bin/bash

# Cleanup any existing processes
pkill -f com.termux.x11 2>/dev/null
pkill -f pulseaudio 2>/dev/null
pkill -f virgl_test_server 2>/dev/null
sleep 1

# Check if virgl_test_server is available
if command -v virgl_test_server >/dev/null 2>&1; then
    # Start VirGL server for hardware acceleration
    virgl_test_server --use-egl-surfaceless --use-gles >/dev/null 2>&1 &
    sleep 2
    HW_ACCEL="enabled"
else
    HW_ACCEL="not available (software rendering)"
fi

# Start Termux X11
termux-x11 :0 -ac -extension MIT-SHM >/dev/null 2>&1 &
sleep 3

# Start PulseAudio
pulseaudio --start --exit-idle-time=-1 >/dev/null 2>&1
pacmd load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 >/dev/null 2>&1
sleep 1

# Start XFCE in background silently using the working command
proot-distro login debian --shared-tmp -- /bin/bash -c 'export PULSE_SERVER=127.0.0.1 && export XDG_RUNTIME_DIR=${TMPDIR} && su - root -c "env DISPLAY=:0 startxfce4"' >/dev/null 2>&1 &

sleep 3

clear
echo "════════════════════════════════════════════════════════"
echo "  Termux to Debian - Ready!"
echo "════════════════════════════════════════════════════════"
echo ""
echo "✓ Termux X11 started"
echo "✓ Hardware Acceleration: $HW_ACCEL"
echo "✓ XFCE4 Desktop Environment running"
echo "✓ Debian shell ready"
echo ""
echo "IMPORTANT: Open the 'Termux:X11' app to see the desktop!"
echo "Or type 'x11' - it will automatically switch to Termux X11"
echo ""
echo "Useful commands:"
echo "  • x11              - Launch Termux X11 app"
echo "  • glxinfo | grep renderer - Test GPU"
echo "  • pkill startxfce4 - Stop desktop"
echo "  • exit             - Close session"
echo ""
echo "════════════════════════════════════════════════════════"
echo ""

# Login to Debian shell
proot-distro login debian --shared-tmp
STARTUP_SCRIPT

chmod +x ~/start-debian-x11.sh
print_success "Startup script created"

###############################################################################
# STEP 6: Configure Auto-start on Termux Launch
###############################################################################
echo ""
sleep 3
print_status "Step 6/7: Configuring auto-start..."

# Backup existing bashrc if exists
if [ -f ~/.bashrc ]; then
    cp ~/.bashrc ~/.bashrc.backup
    print_warning "Existing .bashrc backed up to .bashrc.backup"
fi

# Add auto-start to bashrc
cat >> ~/.bashrc << 'BASHRC_CONFIG'

# Auto-start Debian XFCE Desktop
if [ -z "$DEBIAN_STARTED" ]; then
    export DEBIAN_STARTED=1
    if [ -f ~/start-debian-x11.sh ]; then
        exec ~/start-debian-x11.sh
    fi
fi
BASHRC_CONFIG

print_success "Auto-start configured"

###############################################################################
# STEP 7: Fix Notification Daemon Issue
###############################################################################
echo ""
print_status "Step 7/7: Fixing notification daemon conflicts..."
proot-distro login debian -- bash -c "
    apt remove -y notification-daemon notify-osd 2>/dev/null || true
    apt install -y --reinstall xfce4-notifyd 2>/dev/null || true
" >/dev/null 2>&1
print_success "Notification daemon fixed"

###############################################################################
# Installation Complete
###############################################################################
echo ""
echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                 INSTALLATION COMPLETE!                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
print_success "All components installed successfully!"
echo ""
echo -e "${YELLOW}NEXT STEPS:${NC}"
echo ""
echo "1. Install 'Termux:X11' app from F-Droid or GitHub:"
echo -e "   ${BLUE}https://github.com/termux/termux-x11/releases${NC}"
echo ""
echo "2. Close and reopen Termux - it will auto-start Debian XFCE"
echo ""
echo -e "${YELLOW}3. Open the Termux:X11 app to see your desktop${NC}"
echo ""
echo -e "${GREEN}   • Or type 'x11' inside Debian - it will automatically switch to Termux X11${NC}"
echo ""
echo ""
echo -e "${YELLOW}MANUAL START (if needed):${NC}"
echo "   ./start-debian-x11.sh"
echo ""
echo -e "${YELLOW}TO DISABLE AUTO-START:${NC}"
echo "   Edit ~/.bashrc and remove the auto-start section"
echo ""
echo -e "${YELLOW}USEFUL COMMANDS IN DEBIAN:${NC}"
echo "   x11                      - Launch Termux X11 app"
echo "   glxinfo | grep renderer  - Check GPU acceleration"
echo "   htop                     - System monitor"
echo "   firefox-esr              - Web browser"
echo "   pkill startxfce4         - Stop desktop"
echo ""
print_warning "Press Enter to start Debian XFCE now, or Ctrl+C to exit"
read

# Start the desktop
exec ~/start-debian-x11.sh
