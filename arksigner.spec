%{!?pkg_version: %global pkg_version 3.0.0}
Name:           arksigner
Version:        %{pkg_version}
Release:        1%{?dist}
Summary:        ArkSigner Management, Service and Browser Extensions
License:        Proprietary
URL:            https://www.arksigner.com
ExclusiveArch:  x86_64

Source0:        arksigner-%{version}.tar.gz

Requires:       qt5-qtbase >= 5.15
Requires:       qt5-qtbase-gui >= 5.15
Requires:       qt5-qtsvg >= 5.15
Requires:       poppler-qt5
Requires:       pcsc-lite
Requires:       pcsc-lite-ccid
Requires:       nss-tools
Requires:       python3
Requires:       libcurl
Requires:       qpdf-libs

Provides:       arksigner = %{version}-%{release}
Obsoletes:      arksigner-pub < %{version}-%{release}
Conflicts:      arksigner-pub

# Disable debuginfo, binary stripping, and internal build checks for proprietary package
%global debug_package %{nil}
%global __strip /bin/true
%global __os_install_post %{nil}
%global __check_files %{nil}

%description
ArkSigner Management, Service and Browser Extensions for electronic signature operations.
Native signing application with local HTTPS, PC/SC smartcard service and browser native messaging integration.
Repackaged and configured natively for Fedora Linux.

%prep
rm -rf arksigner-%{version}
tar -xzf %{SOURCE0}
cd arksigner-%{version}
chmod -Rf a+rX,u+w,g-w,o-w .

%build
# Precompiled binary package, no compilation step needed

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
cd arksigner-%{version}

# Copy etc, opt, usr directories
cp -a etc %{buildroot}/
cp -a opt %{buildroot}/
cp -a usr %{buildroot}/

# Ensure 64-bit Mozilla directory also has the native messaging host manifest
mkdir -p %{buildroot}%{_libdir}/mozilla/native-messaging-hosts
if [ "%{_libdir}" != "/usr/lib" ]; then
    ln -sf ../../../lib/mozilla/native-messaging-hosts/com.ark.pw.websigner.json \
        %{buildroot}%{_libdir}/mozilla/native-messaging-hosts/com.ark.pw.websigner.json
fi

# Ensure executable permissions on binaries and scripts
chmod 755 %{buildroot}%{_bindir}/arksigner-* || true
chmod 755 %{buildroot}/usr/lib/arksigner/arksigner-*
chmod 755 %{buildroot}/usr/lib/arksigner/*.py
chmod 755 %{buildroot}/usr/lib/arksigner/drivers/akis/x64/libakisp11.so
chmod 755 %{buildroot}/usr/lib/arksigner/truststore

%post
chmod 755 /usr/lib/arksigner/truststore || true
if [ -x /usr/bin/python3 ] && [ -f /usr/lib/arksigner/firefox-policy.py ]; then
    /usr/bin/python3 /usr/lib/arksigner/firefox-policy.py install || true
fi
if command -v systemctl >/dev/null 2>&1; then
    if systemctl cat arksignerd.service >/dev/null 2>&1; then
        systemctl disable --now arksignerd.service || true
    fi
    systemctl start pcscd.socket || true
fi

%preun
if [ $1 -eq 0 ]; then
    if [ -x /usr/bin/python3 ] && [ -f /usr/lib/arksigner/stop-runtime.py ]; then
        /usr/bin/python3 /usr/lib/arksigner/stop-runtime.py || true
    fi
    if [ -x /usr/bin/python3 ] && [ -f /usr/lib/arksigner/firefox-policy.py ]; then
        /usr/bin/python3 /usr/lib/arksigner/firefox-policy.py remove || true
    fi
fi

%files
%{_bindir}/arksigner-bes
%{_bindir}/arksigner-management
%{_bindir}/arksigner-service
/usr/lib/arksigner/
/usr/lib/mozilla/native-messaging-hosts/com.ark.pw.websigner.json
%{_libdir}/mozilla/native-messaging-hosts/com.ark.pw.websigner.json
/etc/chromium/native-messaging-hosts/com.ark.pw.websigner.json
/etc/opt/chrome/native-messaging-hosts/com.ark.pw.websigner.json
/etc/opt/edge/native-messaging-hosts/com.ark.pw.websigner.json
/etc/xdg/autostart/arksigner-management.desktop
/etc/xdg/autostart/arksigner-service.desktop
/opt/google/chrome/extensions/pllcidbcfbamjfbfpemnnjohnfcliakf.json
%{_datadir}/applications/arksigner-management.desktop
%{_datadir}/pixmaps/arksigner.png
