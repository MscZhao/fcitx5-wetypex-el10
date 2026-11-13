# EL10 build of fcitx5-qt (Qt6-only: platform input context plugin + widgets lib)
Name:           fcitx5-qt
Version:        5.1.16
Release:        1%{?dist}
Summary:        Qt6 input context plugin and library for fcitx5

License:        BSD-3-Clause and LGPL-2.1-or-later
URL:            https://github.com/fcitx/fcitx5-qt
Source0:        https://download.fcitx-im.org/fcitx5/%{name}/%{name}-%{version}.tar.zst

BuildRequires:  gcc-c++
BuildRequires:  cmake
BuildRequires:  ninja-build
BuildRequires:  qt6-qtbase-devel

Requires:       fcitx5

%description
This package provides the Qt6 platform input context plugin that allows
Qt6 applications to communicate with fcitx5, plus the Fcitx5Qt6Widgets
helper library used by input method configuration UIs. Built Qt6-only
for Enterprise Linux 10.

%package        libfcitx5qt6widgets
Summary:        Fcitx5Qt6Widgets library for fcitx5
Requires:       %{name}%{?_isa} = %{version}-%{release}

%description   libfcitx5qt6widgets
The Fcitx5Qt6Widgets helper library, providing input-method-aware
widgets for Qt6 configuration frontends. Required by fcitx5-wetypex.

%package        devel
Summary:        Development files for fcitx5-qt Qt6 libraries
Requires:       %{name}-libfcitx5qt6widgets%{?_isa} = %{version}-%{release}
Requires:       qt6-qtbase-devel

%description    devel
Development files for the Fcitx5Qt6Widgets library.

%prep
%autosetup -p1 -n %{name}-%{version}

%build
%cmake -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DENABLE_QT5=OFF \
  -DENABLE_QT6=ON \
  -DBUILD_ONLY_PLUGIN=OFF
%cmake_build

%install
%cmake_install
find %{buildroot} -name '*.a' -delete
%find_lang %{name}

%files -f %{name}.lang
%license LICENSES/
%doc README.md
%{_qt6_archdatadir}/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so
%{_bindir}/fcitx5-qt6-immodule-probing
%{_libexecdir}/fcitx5-qt6-gui-wrapper
%{_datadir}/applications/org.fcitx.fcitx5-qt6-gui-wrapper.desktop

%files libfcitx5qt6widgets
%{_libdir}/libFcitx5Qt6WidgetsAddons.so.*
%{_libdir}/libFcitx5Qt6DBusAddons.so.*
%{_libdir}/fcitx5/qt6/

%files devel
%{_includedir}/Fcitx5Qt6/
%{_libdir}/libFcitx5Qt6WidgetsAddons.so
%{_libdir}/libFcitx5Qt6DBusAddons.so
%{_libdir}/cmake/Fcitx5Qt6WidgetsAddons/
%{_libdir}/cmake/Fcitx5Qt6DBusAddons/

%changelog
* Fri Nov 13 2026 WeTypeX EL10 build <packaging@wetypex.invalid> - 5.1.16-1
- Initial EL10 build (Qt6-only) for the fcitx5 stack
