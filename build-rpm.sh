#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== ArkSigner Fedora Universal RPM Build Automation ==="

# 1. Find Debian package (.deb)
DEB_FILE="${1:-}"
if [ -z "$DEB_FILE" ]; then
    DEB_FILE=$(ls -t arksigner*.deb 2>/dev/null | head -n 1)
fi

if [ -z "$DEB_FILE" ] || [ ! -f "$DEB_FILE" ]; then
    # Try any deb containing arksigner
    DEB_FILE=$(ls -t *arksigner*.deb 2>/dev/null | head -n 1)
fi

if [ -z "$DEB_FILE" ] || [ ! -f "$DEB_FILE" ]; then
    echo "HATA: Dizin içinde arksigner .deb paketi bulunamadı!"
    echo "Kullanım: ./build-rpm.sh [arksigner_paketi.deb]"
    echo "Veya herhangi bir arksigner deb paketini bu betiğin yanına koyup './build-rpm.sh' çalıştırın."
    exit 1
fi

echo "--> Bulunan Debian paketi: $DEB_FILE"

# 2. Extract version dynamically from the .deb package
read -r PKG_VERSION RAW_VERSION < <(python3 - << PYEOF
import subprocess, tempfile, os, re, sys

deb_path = "$DEB_FILE"
tmp_dir = tempfile.mkdtemp()
try:
    subprocess.run(['ar', '-x', os.path.abspath(deb_path)], cwd=tmp_dir, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    control_tar = None
    for f in os.listdir(tmp_dir):
        if f.startswith('control.tar'):
            control_tar = f
            break
    raw_ver = ""
    if control_tar:
        subprocess.run(['tar', '-xf', control_tar], cwd=tmp_dir, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        control_file = os.path.join(tmp_dir, 'control')
        if os.path.exists(control_file):
            with open(control_file, 'r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    if line.startswith('Version:'):
                        raw_ver = line.split(':', 1)[1].strip()
                        break
    if not raw_ver:
        m = re.search(r'([0-9]+(?:\.[0-9]+)+)', os.path.basename(deb_path))
        raw_ver = m.group(1) if m else '3.0.0'

    # Format version for RPM (numbers and dots)
    m = re.match(r'^([0-9]+(?:\.[0-9]+)*)', raw_ver)
    clean_ver = m.group(1) if m else raw_ver.split('~')[0].split('-')[0].split('+')[0]
    clean_ver = re.sub(r'[^a-zA-Z0-9.]', '.', clean_ver).strip('.')
    print(f"{clean_ver} {raw_ver}")
finally:
    subprocess.run(['rm', '-rf', tmp_dir], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
PYEOF
)

if [ -z "$PKG_VERSION" ]; then
    echo "HATA: .deb paketinden sürüm bilgisi okunamadı!"
    exit 1
fi

echo "--> Algılanan Sürüm (Debian): $RAW_VERSION"
echo "--> Hedef RPM Sürümü: $PKG_VERSION"

# 3. Ensure rpmbuild directory tree
mkdir -p rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
mkdir -p "rpmbuild/BUILD/arksigner-${PKG_VERSION}-build"

# 4. Prepare source tarball if not already existing for this version
SOURCE_TARBALL="rpmbuild/SOURCES/arksigner-${PKG_VERSION}.tar.gz"
if [ ! -f "$SOURCE_TARBALL" ]; then
    echo "--> $DEB_FILE içeriği çıkarılarak kaynak arşivi hazırlanıyor ($SOURCE_TARBALL)..."
    TMP_DIR=$(mktemp -d)
    ar -x "$(realpath "$DEB_FILE")" --output "$TMP_DIR"
    
    DATA_TAR=$(find "$TMP_DIR" -name "data.tar*" | head -n 1)
    if [ -z "$DATA_TAR" ] || [ ! -f "$DATA_TAR" ]; then
        echo "HATA: .deb paketi içerisinde data.tar arşivi bulunamadı!"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    
    mkdir -p "rpmbuild/SOURCES/arksigner-${PKG_VERSION}"
    tar -xf "$DATA_TAR" -C "rpmbuild/SOURCES/arksigner-${PKG_VERSION}"
    tar -czf "$SOURCE_TARBALL" -C rpmbuild/SOURCES "arksigner-${PKG_VERSION}"
    rm -rf "$TMP_DIR"
    echo "--> Kaynak arşivi oluşturuldu: $SOURCE_TARBALL"
fi

# 5. Synchronize spec file symlink
if [ ! -L "rpmbuild/SPECS/arksigner.spec" ]; then
    ln -sf ../../arksigner.spec rpmbuild/SPECS/arksigner.spec
fi

# 6. Build RPM
echo "--> RPM paketi derleniyor..."
if command -v rpmbuild >/dev/null 2>&1; then
    rpmbuild --define "_topdir $SCRIPT_DIR/rpmbuild" --define "pkg_version $PKG_VERSION" -ba rpmbuild/SPECS/arksigner.spec
else
    python3 - << PYEOF
import ctypes, rpm, os, sys

def load_lib(candidates):
    for name in candidates:
        try:
            return ctypes.CDLL(name)
        except OSError:
            continue
    raise RuntimeError(f"Could not load any of: {candidates}")

librpmbuild = load_lib(['librpmbuild.so.10', 'librpmbuild.so.9', 'librpmbuild.so'])
librpm = load_lib(['librpm.so.10', 'librpm.so.9', 'librpm.so'])

librpm.rpmReadConfigFiles(None, None)

topdir = os.path.abspath('rpmbuild')
rpm.addMacro('_topdir', topdir)
rpm.addMacro('_tmppath', topdir + '/BUILD')
rpm.addMacro('pkg_version', '$PKG_VERSION')

librpm.rpmtsCreate.restype = ctypes.c_void_p
ts = librpm.rpmtsCreate()

class rpmBuildArguments_s(ctypes.Structure):
    _fields_ = [
        ('pkgFlags', ctypes.c_int),
        ('buildAmount', ctypes.c_int),
        ('buildRootOverride', ctypes.c_char_p),
        ('targets', ctypes.c_char_p),
    ]

librpmbuild.rpmSpecParse.restype = ctypes.c_void_p
librpmbuild.rpmSpecParse.argtypes = [ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p]
librpmbuild.rpmSpecBuild.restype = ctypes.c_int
librpmbuild.rpmSpecBuild.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(rpmBuildArguments_s)]

spec_path = os.path.join(topdir, 'SPECS', 'arksigner.spec').encode()
# flags=0x10 prevents premature finalizeSpec before rpmSpecBuild
spec = librpmbuild.rpmSpecParse(spec_path, 0x10, None)
if not spec:
    print("Error: Failed to parse spec file", file=sys.stderr)
    sys.exit(1)

ba = rpmBuildArguments_s()
ba.pkgFlags = 0
ba.buildAmount = rpm.RPMBUILD_PREP | rpm.RPMBUILD_BUILD | rpm.RPMBUILD_INSTALL | rpm.RPMBUILD_PACKAGEBINARY
ba.buildRootOverride = None
ba.targets = None

rc = librpmbuild.rpmSpecBuild(ts, spec, ctypes.byref(ba))
if rc != 0:
    print(f"Error: rpmSpecBuild failed with exit code {rc}", file=sys.stderr)
    sys.exit(rc)
PYEOF
fi

# 7. Copy built RPM to workspace root
BUILT_RPM=$(find rpmbuild/RPMS -type f -name "arksigner-${PKG_VERSION}-*.rpm" | sort -n | tail -1)
if [ -n "$BUILT_RPM" ] && [ -f "$BUILT_RPM" ]; then
    cp -f "$BUILT_RPM" "$SCRIPT_DIR/"
    RPM_NAME=$(basename "$BUILT_RPM")
    echo "============================================="
    echo "=== Derleme Başarılı! ==="
    echo "Algılanan Debian Paketi: $DEB_FILE"
    echo "Paket Sürümü:            $PKG_VERSION"
    echo "Üretilen RPM:            $SCRIPT_DIR/$RPM_NAME"
    ls -lh "$SCRIPT_DIR/$RPM_NAME"
    echo "============================================="
else
    echo "HATA: RPM paketi rpmbuild/RPMS içinde bulunamadı!"
    exit 1
fi
