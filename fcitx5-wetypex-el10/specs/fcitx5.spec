# EL10 build of fcitx5 core (adapted from Fedora packaging)
Name:           fcitx5
Version:        5.1.23
Release:        1%{?dist}
Summary:        Input method framework with addon support

License:        LGPL-2.1-or-later and GPL-2.0-or-later
URL:            https://github.com/fcitx/fcitx5
# _dict tarball carries dictionaries and git submodules
Source0:        https://download.fcitx-im.org/fcitx5/%{name}-%{version}_dict.tar.zst

BuildRequires:  gcc-c++
BuildRequires:  cmake
BuildRequires:  ninja-build
BuildRequires:  pkgconf-pkg-config
BuildRequires:  gettext
BuildRequires:  dbus-devel
BuildRequires:  glib2-devel
BuildRequires:  libuuid-devel
BuildRequires:  libuv-devel
BuildRequires:  fmt-devel
BuildRequires:  expat-devel
BuildRequires:  json-c-devel
BuildRequires:  json-devel
BuildRequires:  libxcb-devel
BuildRequires:  xcb-util-devel
BuildRequires:  xcb-util-wm-devel
BuildRequires:  xcb-util-keysyms-devel
BuildRequires:  xcb-imdkit-devel
BuildRequires:  libxkbcommon-devel
BuildRequires:  libxkbcommon-x11-devel
BuildRequires:  libX11-devel
BuildRequires:  libxkbfile-devel
BuildRequires:  enchant2-devel
BuildRequires:  iso-codes-devel
BuildRequires:  xkeyboard-config
BuildRequires:  xkeyboard-config-devel
BuildRequires:  wayland-devel
BuildRequires:  wayland-protocols-devel
BuildRequires:  plasma-wayland-protocols-devel
BuildRequires:  gdk-pixbuf2-devel
# 5.1.23: cairo/pango/gdk-pixbuf/gio-unix become REQUIRED, plus new librsvg
BuildRequires:  cairo-devel
BuildRequires:  pango-devel
BuildRequires:  glib2-devel
BuildRequires:  librsvg2-devel
BuildRequires:  desktop-file-utils

Requires:       iso-codes
Requires:       xkeyboard-config
Requires:       xcb-imdkit%{?_isa}

%description
Fcitx 5 is a generic input method framework. This package provides the
core libraries, daemon, addons (XIM, Wayland input method, DBus,
classic UI, spell, clipboard, emoji, quickphrase, unicode) and data for
Enterprise Linux 10. It is required by fcitx5-wetypex.

%package        devel
Summary:        Development files for %{name}
Requires:       %{name}%{?_isa} = %{version}-%{release}

%description    devel
The %{name}-devel package contains libraries and header files for
developing fcitx5 input method addons and frontends.

%prep
%autosetup -p1 -n %{name}-%{version}
# EL10 ships wayland-protocols 1.45; all protocol XMLs used by 5.1.20
# (incl. ext-background-effect-v1) are present, so lower upstream's 1.46 floor.
sed -i 's/find_package(WaylandProtocols 1.46 REQUIRED)/find_package(WaylandProtocols 1.45 REQUIRED)/' CMakeLists.txt

%build
%cmake -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DENABLE_X11=ON \
  -DENABLE_WAYLAND=ON \
  -DENABLE_ENCHANT=ON \
  -DUSE_SYSTEM_XCB_IMDKIT=ON \
  -DENABLE_TEST=OFF
%cmake_build

%install
%cmake_install
find %{buildroot} -name '*.a' -delete
%find_lang %{name}

%files -f %{name}.lang
%license LICENSES/
%doc README.md
%{_bindir}/fcitx5
%{_bindir}/fcitx5-remote
%{_bindir}/fcitx5-diagnose
%{_bindir}/fcitx5-configtool
%{_libexecdir}/fcitx5-wayland-launcher
%{_libdir}/libFcitx5Core.so.*
%{_libdir}/libFcitx5Config.so.*
%{_libdir}/libFcitx5Utils.so.*
%{_libdir}/fcitx5/
%{_datadir}/fcitx5/
%{_datadir}/applications/org.fcitx.Fcitx5.desktop
%{_datadir}/applications/fcitx5-configtool.desktop
%{_datadir}/applications/fcitx5-wayland-launcher.desktop
%{_datadir}/dbus-1/services/org.fcitx.Fcitx5.service
%{_datadir}/icons/hicolor/*/apps/*.png
%{_datadir}/icons/hicolor/*/apps/*.svg
%{_datadir}/metainfo/*.xml
%{_sysconfdir}/xdg/autostart/org.fcitx.Fcitx5.desktop
%{_sysconfdir}/xdg/Xwayland-session.d/

%files devel
%{_includedir}/Fcitx5/
%{_libdir}/libFcitx5Core.so
%{_libdir}/libFcitx5Config.so
%{_libdir}/libFcitx5Utils.so
%{_libdir}/cmake/Fcitx5*/
%{_libdir}/pkgconfig/Fcitx5*.pc

%changelog
* Fri Nov 13 2026 WeTypeX EL10 build <packaging@wetypex.invalid> - 5.1.17-1
- Initial EL10 build for the fcitx5 stack
