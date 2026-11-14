# EL10 build of fcitx5-gtk (GTK3/GTK4 input method modules)
Name:           fcitx5-gtk
Version:        5.1.7
Release:        1%{?dist}
Summary:        GTK input method module for fcitx5

License:        LGPL-2.1-or-later
URL:            https://github.com/fcitx/fcitx5-gtk
Source0:        https://download.fcitx-im.org/fcitx5/%{name}/%{name}-%{version}.tar.zst

BuildRequires:  gcc-c++
BuildRequires:  cmake
BuildRequires:  extra-cmake-modules
BuildRequires:  ninja-build
BuildRequires:  pkgconf-pkg-config
BuildRequires:  gtk3-devel
BuildRequires:  gtk4-devel
BuildRequires:  gobject-introspection-devel
BuildRequires:  fcitx5-devel

Requires:       fcitx5%{?_isa}
Requires:       gtk3

%description
This package provides the GTK3 and GTK4 input method modules that allow
GTK applications to communicate with fcitx5, enabling CJK input inside
all GTK-based applications on Enterprise Linux 10.

%package        devel
Summary:        Development files for fcitx5-gtk GClient library
Requires:       %{name}%{?_isa} = %{version}-%{release}

%description   devel
Development files for the Fcitx5GClient library, needed by frontends
that integrate fcitx5 through GObject-based APIs.

%prep
%autosetup -p1 -n %{name}-%{version}

%build
%cmake -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DENABLE_GTK2_IM_MODULE=OFF \
  -DENABLE_GTK3_IM_MODULE=ON \
  -DENABLE_GTK4_IM_MODULE=ON
%cmake_build

%install
%cmake_install

%files
%license LICENSES/
%doc README.md
%{_libdir}/gtk-3.0/3.0.0/immodules/im-fcitx5.so
%{_libdir}/gtk-4.0/4.0.0/immodules/libim-fcitx5.so
%{_bindir}/fcitx5-gtk3-immodule-probing
%{_bindir}/fcitx5-gtk4-immodule-probing
%{_libdir}/libFcitx5GClient.so.*
%{_libdir}/girepository-1.0/FcitxG-1.0.typelib

%files devel
%{_includedir}/Fcitx5/GClient/
%{_libdir}/libFcitx5GClient.so
%{_libdir}/cmake/Fcitx5GClient/
%{_libdir}/pkgconfig/Fcitx5GClient.pc
%{_datadir}/gir-1.0/FcitxG-1.0.gir

%post
if [ -x %{_bindir}/gtk-query-immodules-3.0 ]; then
  %{_bindir}/gtk-query-immodules-3.0 --update-cache >/dev/null 2>&1 || :
fi

%postun
if [ -x %{_bindir}/gtk-query-immodules-3.0 ]; then
  %{_bindir}/gtk-query-immodules-3.0 --update-cache >/dev/null 2>&1 || :
fi

%changelog
* Fri Nov 13 2026 WeTypeX EL10 build <packaging@wetypex.invalid> - 5.1.7-1
- Initial EL10 build for the fcitx5 stack
