# EL10 build of fcitx-im xcb-imdkit (adapted from Fedora packaging)
# Built for the fcitx5-on-EL10 stack, see packaging/el10/README.md
Name:           xcb-imdkit
Version:        1.0.9
Release:        1%{?dist}
Summary:        XIM protocol implementation based on XCB

License:        LGPL-2.1-or-later and MIT and BSD-3-Clause
URL:            https://github.com/fcitx/xcb-imdkit
# No upstream distribution tarball; recreate with:
#   git clone --depth 1 --recurse-submodules -b %{version} https://github.com/fcitx/xcb-imdkit %{name}-%{version}
#   tar --xz -cf %{name}-%{version}.tar.xz %{name}-%{version}
Source0:        %{name}-%{version}.tar.xz

BuildRequires:  gcc-c++
BuildRequires:  cmake
BuildRequires:  ninja-build
BuildRequires:  pkgconf-pkg-config
BuildRequires:  libxcb-devel
BuildRequires:  xcb-util-keysyms-devel
BuildRequires:  zlib-devel

%description
xcb-imdkit is an implementation of XIM protocol in XCB library, based on
the IMDKit reference implementation. It is used by fcitx5 to provide the
XIM (X Input Method) server frontend for XWayland and X11 applications.

%package        devel
Summary:        Development files for %{name}
Requires:       %{name}%{?_isa} = %{version}-%{release}
Requires:       libxcb-devel

%description    devel
The %{name}-devel package contains libraries and header files for
developing applications that use %{name}.

%prep
%autosetup -p1 -n %{name}-%{version}

%build
%cmake -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DUSE_SYSTEM_UTHASH=OFF
%cmake_build

%install
%cmake_install

%files
%license LICENSES/
%doc README.md
%{_libdir}/libxcb-imdkit.so.1*

%files devel
%{_includedir}/xcb-imdkit/
%{_libdir}/libxcb-imdkit.so
%{_libdir}/cmake/XCBImdkit/
%{_libdir}/pkgconfig/xcb-imdkit.pc

%changelog
* Fri Nov 13 2026 WeTypeX EL10 build <packaging@wetypex.invalid> - 1.0.9-1
- Initial EL10 build for the fcitx5 stack
