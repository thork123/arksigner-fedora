import os
import glob
import subprocess
import rpm

def get_latest_rpm():
    rpms = glob.glob('arksigner-*.rpm')
    if not rpms:
        rpms = glob.glob('arksigner*.rpm')
    assert rpms, "No arksigner RPM found in directory"
    rpms.sort(key=os.path.getmtime)
    return os.path.abspath(rpms[-1])

def test_firefox_native_messaging_symlink():
    """Verify that the Mozilla 64-bit native messaging symlink resolves to a valid target"""
    rpm_path = get_latest_rpm()
    assert os.path.exists(rpm_path), f"RPM does not exist: {rpm_path}"
    
    # Check link target from rpm query
    cmd = ["rpm", "-qpl", "-v", rpm_path]
    out = subprocess.check_output(cmd, text=True)
    for line in out.splitlines():
        if "/usr/lib64/mozilla/native-messaging-hosts/com.ark.pw.websigner.json" in line:
            parts = line.split("->")
            assert len(parts) == 2, f"Expected symlink format in {line}"
            target = parts[1].strip()
            # The target must be ../../../lib/mozilla/...
            assert target == "../../../lib/mozilla/native-messaging-hosts/com.ark.pw.websigner.json", \
                f"Broken relative symlink target: {target}"
            return
    assert False, "64-bit Mozilla symlink not found in RPM"

def test_rpm_architecture():
    """Verify that the RPM is x86_64 architecture"""
    rpm_path = get_latest_rpm()
    cmd = ["rpm", "-qp", "--qf", "%{ARCH}\n", rpm_path]
    arch = subprocess.check_output(cmd, text=True).strip()
    assert arch == "x86_64", f"Expected x86_64, got {arch}"

def test_spec_symlink():
    """Verify rpmbuild/SPECS/arksigner.spec is symlinked to root arksigner.spec"""
    spec_path = "rpmbuild/SPECS/arksigner.spec"
    assert os.path.islink(spec_path), f"{spec_path} is not a symlink"

if __name__ == '__main__':
    rpm_file = get_latest_rpm()
    print(f"Testing RPM: {os.path.basename(rpm_file)}")
    test_firefox_native_messaging_symlink()
    test_rpm_architecture()
    test_spec_symlink()
    print("All tests passed!")
