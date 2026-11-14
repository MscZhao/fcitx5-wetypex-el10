# EL10 build of fcitx5-configtool (the real graphical configuration GUI)
Name:           fcitx5-configtool
Version:        5.1.16
Release:        1%{?dist}
Summary:        Graphical configuration tool for fcitx5

License:        GPL-2.0-or-later
URL:            https://github.com/fcitx/fcitx5-configtool
Source0:        https://download.fcitx-im.org/fcitx5/%{name}/%{name}-%{version}.tar.zst

BuildRequires:  gcc-c++
BuildRequires:  cmake
BuildRequires:  ninja-build
BuildRequires:  extra-cmake-modules
BuildRequires:  fcitx5-devel
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtbase-private-devel
BuildRequires:  kf6-kconfig-devel
BuildRequires:  kf6-kcoreaddons-devel
BuildRequires:  kf6-ki18n-devel
BuildRequires:  kf6-kitemmodels-devel
BuildRequires:  kf6-kitemviews-devel
BuildRequires:  kf6-kwidgetsaddons-devel
BuildRequires:  kf6-kdeclarative-devel
BuildRequires:  kf6-kguiaddons-devel
BuildRequires:  kf6-kirigami-devel
BuildRequires:  kf6-kiconthemes-devel
BuildRequires:  kf6-kpackage-devel
BuildRequires:  kf6-ksvg-devel
BuildRequires:  kf6-kcmutils-devel
BuildRequires:  libplasma-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  xkeyboard-config-devel
BuildRequires:  iso-codes-devel

Requires:       fcitx5%{?_isa}

%description
fcitx5-configtool is the KDE/Qt graphical configuration tool for the
fcitx5 input method framework: input method list management, global
hotkey configuration, addon management and profile editing.

%prep
%autosetup -p1 -n %{name}-%{version}

%build
%cmake -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DKDE_INSTALL_USE_QT_SYS_PATHS=ON
%cmake_build

%install
%cmake_install
%find_lang %{name}
%find_lang kcm_fcitx5
cat kcm_fcitx5.lang >> %{name}.lang

%files -f %{name}.lang
%license LICENSES/
%doc README.md
%{_bindir}/fcitx5-config-qt
%{_bindir}/fcitx5-migrator
%{_bindir}/fcitx5-plasma-theme-generator
%{_bindir}/kbd-layout-viewer5
%{_libdir}/libFcitx5Migrator.so
%{_libdir}/libFcitx5Migrator.so.*
%{_qt6_archdatadir}/plugins/plasma/kcms/systemsettings/kcm_fcitx5.so
%{_datadir}/applications/kbd-layout-viewer5.desktop
%{_datadir}/applications/kcm_fcitx5.desktop
%{_datadir}/applications/org.fcitx.fcitx5-config-qt.desktop
%{_datadir}/applications/org.fcitx.fcitx5-migrator.desktop

%changelog
* Fri Nov 13 2026 WeTypeX EL10 build <packaging@wetypex.invalid> - 5.1.16-1
- Initial EL10 build for the fcitx5 stack
