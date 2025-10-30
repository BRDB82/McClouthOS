sudo dnf groupinstall "Development Tools"
sudo dnf install meson ninja-build wayland-devel wayland-protocols-devel \
    libinput-devel libxkbcommon-devel libxml2-devel cairo-devel \
    pango-devel glib2-devel libpng-devel librsvg2-devel \
    expat-devel libpciaccess-devel libatomic_ops-devel \
    libinput-devel mesa-libGLES-devel libdrm-devel libglvnd-devel \
    systemd-devel libcap-devel json-c-devel libudev-devel alsa-lib-devel

# Clone the repository and change to the directory
git clone https://github.com/labwc/labwc.git
cd labwc

# Build and install (this may require additional dependencies)
meson setup build/
ninja -C build
sudo ninja -C build install

git clone https://gitlab.xfce.org/xfce/xfce4-session.git
cd xfce4-session
meson setup build/
ninja -C build
sudo ninja -C build install

cat <<EOF > ~/.local/share/wayland-sessions/xfce-wayland.desktop
[Desktop Entry]
Name=Xfce Session (Wayland Experimental)
Comment=Experimental Wayland session for Xfce
Exec=startxfce4 --wayland labwc
Type=Application
EOF

