# EL10 build of LLVM libc++/libc++abi/libunwind runtimes
# Needed by fcitx5-wetypex's transport bridge (-stdlib=libc++), absent from EL10.
# Built standalone from the llvm-project monorepo using the system clang
# (llvm-toolset), compiling ONLY the runtimes subtree.
Name:           libcxx
Version:        21.1.8
Release:        1%{?dist}
Summary:        C++ standard library from LLVM (libc++, libc++abi, libunwind)

License:        Apache-2.0 WITH LLVM-exception
URL:            https://llvm.org
Source0:        https://github.com/llvm/llvm-project/archive/refs/tags/llvmorg-%{version}.tar.gz#/llvm-project-llvmorg-%{version}.tar.gz

BuildRequires:  clang
BuildRequires:  cmake
BuildRequires:  ninja-build
BuildRequires:  python3

%description
LLVM libc++ is a modern, conforming implementation of the C++ standard
library. This package builds the libc++, libc++abi and LLVM libunwind
runtimes from the llvm-project monorepo with the system clang, and is
required by fcitx5-wetypex whose transport bridge is linked with
-stdlib=libc++.

%package        devel
Summary:        Headers and libraries for %{name} development
Requires:       %{name}%{?_isa} = %{version}-%{release}
Requires:       clang

%description    devel
Headers and linker scripts for developing applications that link
against LLVM libc++.

%prep
%autosetup -n llvm-project-llvmorg-%{version} -p1

%build
mkdir -p redhat-linux-build && pushd redhat-linux-build
cmake -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" \
  -DLLVM_LIBDIR_SUFFIX=64 \
  -DCMAKE_INSTALL_PREFIX=%{_prefix} \
  -DCMAKE_INSTALL_LIBDIR=%{_lib} \
  -DLIBCXX_INCLUDE_BENCHMARKS=OFF \
  -DLIBCXX_INCLUDE_TESTS=OFF \
  -DLIBCXXABI_ENABLE_TESTS=OFF \
  -DLIBUNWIND_ENABLE_TESTS=OFF \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_ENABLE_ASSERTIONS=OFF \
  ../runtimes
ninja
popd

%install
pushd redhat-linux-build
DESTDIR=%{buildroot} ninja install
popd

%files
%license llvm-project/LICENSE.TXT libcxx/LICENSE.TXT libcxxabi/LICENSE.TXT libunwind/LICENSE.TXT
%{_libdir}/libc++.so.1*
%{_libdir}/libc++abi.so.1*
%{_libdir}/libunwind.so.1*
%{_libdir}/libc++.modules.json
%{_includedir}/c++/v1/
%{_includedir}/unwind.h
%{_includedir}/unwind_arm_ehabi.h
%{_includedir}/unwind_itanium.h
%{_includedir}/__libunwind_config.h
%{_includedir}/libunwind.h
%{_includedir}/libunwind.modulemap
%{_includedir}/mach-o/
%{_datadir}/libc++/

%files devel
%{_libdir}/libc++.so
%{_libdir}/libc++abi.so
%{_libdir}/libunwind.so
%{_libdir}/libc++.a
%{_libdir}/libc++abi.a
%{_libdir}/libc++experimental.a
%{_libdir}/libunwind.a

%changelog
* Fri Nov 13 2026 WeTypeX EL10 build <packaging@wetypex.invalid> - 19.1.7-1
- Initial EL10 build of LLVM 19 runtimes for the fcitx5-wetypex stack
