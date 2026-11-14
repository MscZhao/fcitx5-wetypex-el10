# EL10 build of libime (input method engine library: pinyin/table/core)
Name:           libime
Version:        1.1.17
Release:        1%{?dist}
Summary:        Input method engine library used by fcitx5

License:        LGPL-2.1-or-later and GPL-3.0-or-later
URL:            https://github.com/fcitx/libime
# _dict tarball carries the kenlm submodule and pretrained data
Source0:        https://download.fcitx-im.org/fcitx5/%{name}/%{name}-%{version}_dict.tar.zst

BuildRequires:  gcc-c++
BuildRequires:  cmake
BuildRequires:  extra-cmake-modules
BuildRequires:  ninja-build
BuildRequires:  fcitx5-devel
BuildRequires:  boost-devel

Requires:       fcitx5%{?_isa}

%description
LibIME implements the input method engine algorithms (trigram language
model, pinyin decoding, table-based input) used by fcitx5 engines.
Required by fcitx5-wetypex.

%package        devel
Summary:        Development files for %{name}
Requires:       %{name}%{?_isa} = %{version}-%{release}
Requires:       fcitx5-devel
Requires:       boost-devel

%description    devel
The %{name}-devel package contains libraries and header files for
developing input method engines that use %{name}.

%package        data
Summary:        Language model and table dictionary data for %{name}
# Data is only consumed by fcitx5-chinese-addons / table engines, which are
# not shipped in the WeTypeX EL10 stack; keep base %{name} small so the
# fcitx5-wetypex bundle stays lean.

%description    data
The zh_CN trigram language model (%{_libdir}/libime) and table
dictionaries (%{_datadir}/libime) used by fcitx5 pinyin/table input
engines.

%prep
%autosetup -p1 -n %{name}-%{version}

%build
%cmake -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DENABLE_TEST=OFF
%cmake_build

%install
%cmake_install
find %{buildroot} -name '*.a' -delete

%files
%license LICENSES/
%doc README.md
%{_libdir}/libIMECore.so.*
%{_libdir}/libIMEPinyin.so.*
%{_libdir}/libIMETable.so.*
%{_bindir}/libime_tabledict
%{_bindir}/libime_pinyindict
%{_bindir}/libime_history
%{_bindir}/libime_prediction
%{_bindir}/libime_slm_build_binary
%{_bindir}/libime_migrate_fcitx4_pinyin
%{_bindir}/libime_migrate_fcitx4_table

%files data
%{_libdir}/libime/
%{_datadir}/libime/

%files devel
%{_includedir}/LibIME/
%{_libdir}/libIMECore.so
%{_libdir}/libIMEPinyin.so
%{_libdir}/libIMETable.so
%{_libdir}/cmake/LibIMECore/
%{_libdir}/cmake/LibIMEPinyin/
%{_libdir}/cmake/LibIMETable/

%changelog
* Fri Nov 13 2026 WeTypeX EL10 build <packaging@wetypex.invalid> - 1.1.17-1
- Initial EL10 build for the fcitx5 stack
