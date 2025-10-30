sudo dnf groupinstall "Development Tools"
sudo dnf install meson ninja-build wayland-devel \
    libinput-devel libxkbcommon-devel libxml2-devel cairo-devel \
    pango-devel glib2-devel libpng-devel librsvg2-devel \
    expat-devel libpciaccess-devel libatomic_ops-devel \
    libinput-devel mesa-libGLES-devel libdrm-devel libglvnd-devel \
    systemd-devel libcap-devel json-c-devel libudev-devel alsa-lib-devel \
    git mesa-libEGL-devel vulkan-devel cmake libgbm-devel lcms2-devel \
    hwdata-devel atk-devel gobject-introspection-devel python3-devel \
    libXrandr-devel libXinerama-devel libXi-devel libXcursor-devel \
    libXcomposite-devel libXdamage-devel


mkdir -p ~/xfce_RHEL10

# gotta build wayland from source, because it does not exist in the repository
mkdir -p ~/xfce_RHEL10/wayland-build
cd ~/xfce_RHEL10/wayland-build
git clone https://gitlab.freedesktop.org/wayland/wayland.git
cd wayland

meson setup build --prefix=/usr --buildtype=release -Ddocumentation=false

cd build
ninja
sudo ninja install

# gotta build libxkbcommon from source, because dnf version to old
mkdir -p ~/xfce_RHEL10/xkb-build
cd ~/xfce_RHEL10/xkb-build
git clone https://github.com/xkbcommon/libxkbcommon.git
cd libxkbcommon

meson setup build \
    --prefix=/usr \
    --buildtype=release \
    -Denable-docs=false \
    -Denable-x11=false \
    -Dxkb-config-root=/usr/share/X11/xkb

cd build
ninja
sudo ninja install

# gotta build wayland-protocols first, because the dnf version is to old
mkdir -p ~/xfce_RHEL10/protocols-build
cd ~/xfce_RHEL10/protocols-build
git clone https://gitlab.freedesktop.org/wayland/wayland-protocols.git
cd wayland-protocols

meson setup build --prefix=/usr --buildtype=release

cd build
ninja
sudo ninja install

# gotta build libseat first, for whatever reason
mkdir -p ~/xfce_RHEL10/libseat-build
cd ~/xfce_RHEL10/libseat-build
git clone https://git.sr.ht/~kennylevinsen/seatd
cd seatd

meson setup build --prefix=/usr --buildtype=release -Dserver=disabled -Dlibseat-seatd=disabled

cd build
ninja
sudo ninja install

# gotta build libdisplay first, for whatever reason
mkdir -p ~/xfce_RHEL10/libdisplay-build
cd ~/xfce_RHEL10/libdisplay-build
git clone https://gitlab.freedesktop.org/emersion/libdisplay-info.git
cd libdisplay-info

meson setup build --prefix=/usr --buildtype=release

cd build
ninja
sudo ninja install

# gotta build wlroots first, because the dnf version is older then the required
mkdir -p ~/xfce_RHEL10/wlroots-build
cd ~/xfce_RHEL10/wlroots-build
git clone https://gitlab.freedesktop.org/wlroots/wlroots.git
cd wlroots

meson setup build --buildtype=release \
    -Dbackends=drm,libinput \
    -Drenderers=gles2 \
    -Dxwayland=disabled \
    -Dsession=enabled \
    -Dexamples=false

cd build
ninja
sudo ninja install

# Clone the labwc repository and change to the directory
mkdir ~/xfce_RHEL10/labwc-build
cd ~/xfce_RHEL10/labwc-build
git clone https://github.com/labwc/labwc.git
cd labwc

# Build and install (this may require additional dependencies)
meson setup build/
ninja -C build
sudo ninja -C build install

# CLone the glib repository
mkdir -p ~/xfce_RHEL10/glib-build
cd ~/xfce_RHEL10/glib-build
git clone https://gitlab.gnome.org/GNOME/glib.git
cd glib

meson setup build --prefix=/usr --buildtype=release \
    -Dintrospection=disabled \
    -Dtests=false \
    -Dman=false \
    -Dxattr=false \
    -Ddtrace=false \
    -Dselinux=disabled

cd build
ninja
sudo ninja install

sudo gio-querymodules /usr/lib64/gio/modules

# Clone the gtk repository
mkdir -p ~/xfce_RHEL10/gtk-build
cd ~/xfce_RHEL10/gtk-build
git clone https://gitlab.gnome.org/GNOME/gtk.git
cd gtk

meson setup build --prefix=/usr --buildtype=release

cd build
ninja
sudo ninja install

# Clone the xfce repository and change to the directory
mkdir ~/xfce_RHEL10/xfce-build
cd ~/xfce_RHEL10/xfce-build
git clone https://gitlab.xfce.org/xfce/xfce4-session.git
cd xfce4-session

meson setup build/

cd build
ninja
sudo ninja install

cat <<EOF > ~/.local/share/wayland-sessions/xfce-wayland.desktop
[Desktop Entry]
Name=Xfce Session (Wayland Experimental)
Comment=Experimental Wayland session for Xfce
Exec=startxfce4 --wayland labwc
Type=Application
EOF

#rm -rf build
#meson setup build/ &> build.log

#wlroots| Run-time dependency <dependency-name> found: NO (tried pkgconfig and cmake)

#when experiencing runtime errors:
#export LD_LIBRARY_PATH=/usr/lib64:$LD_LIBRARY_PATH
