import subprocess
import shutil
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent.parent.parent / "scripts"


def run_oem_port(work_dir: Path, porting_tool: str, rom_type: str,
                 firmware_url: str = None,
                 samloader_args: tuple = None,
                 log_func=print) -> Path:
    script = SCRIPTS_DIR / "oem_port.sh"
    if not script.exists():
        raise FileNotFoundError(f"oem_port.sh not found at {script}")

    cmd = ["sudo", str(script), str(work_dir), porting_tool, rom_type]
    if firmware_url:
        cmd += ["--url", firmware_url]
    elif samloader_args:
        cmd += ["--samloader", *samloader_args]
    else:
        raise ValueError("Either firmware_url or samloader_args is required")

    log_func(f"$ {' '.join(cmd)}")
    with subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          text=True, bufsize=1) as proc:
        for line in proc.stdout:
            log_func(line.rstrip())
    if proc.returncode != 0:
        raise RuntimeError("oem_port.sh failed")

    custom_img = work_dir / "custom_system.img"
    if not custom_img.exists():
        # oem_port.sh outputs to work_dir/custom_system.img
        alt = work_dir / "custom_system.img"
        if alt.exists():
            return alt
        raise FileNotFoundError("custom_system.img not created by oem_port.sh")
    return custom_img


def run_patch_firmware(super_img: Path, out_dir: Path, log_func=print):
    script = SCRIPTS_DIR / "patch_firmware.sh"
    if not script.exists():
        raise FileNotFoundError(f"patch_firmware.sh not found at {script}")
    cmd = ["sudo", str(script), "--super", str(super_img), str(out_dir)]
    log_func(f"$ {' '.join(cmd)}")
    with subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          text=True, bufsize=1) as proc:
        for line in proc.stdout:
            log_func(line.rstrip())
    if proc.returncode != 0:
        raise RuntimeError("patch_firmware.sh failed")
    return out_dir


def download_gsi(url: str, work_dir: Path, log_func=print) -> Path:
    log_func(f"Downloading GSI from {url}...")
    r = subprocess.run(
        ["wget", "-q", "-O", str(work_dir / "rom_package"), url],
        capture_output=True, text=True, timeout=600)
    if r.returncode != 0:
        raise RuntimeError(f"GSI download failed: {r.stderr}")

    pkg = work_dir / "rom_package"
    log_func("Extracting GSI image...")
    type_result = subprocess.run(
        ["file", "-b", str(pkg)], capture_output=True, text=True)
    ftype = type_result.stdout.strip()

    if "XZ compressed" in ftype:
        subprocess.run(["mv", str(pkg), str(work_dir / "s.xz")], check=True)
        subprocess.run(["unxz", str(work_dir / "s.xz")], check=True)
        subprocess.run(["mv", str(work_dir / "s"), str(work_dir / "custom_system.img")], check=True)
    elif "gzip compressed" in ftype:
        subprocess.run(["mv", str(pkg), str(work_dir / "s.gz")], check=True)
        subprocess.run(["gzip", "-d", str(work_dir / "s.gz")], check=True)
        subprocess.run(["mv", str(work_dir / "s"), str(work_dir / "custom_system.img")], check=True)
    elif "Zip archive" in ftype:
        subprocess.run(["unzip", "-o", str(pkg)], cwd=str(work_dir), check=True)
    elif "7-zip" in ftype:
        subprocess.run(["7z", "x", str(pkg)], cwd=str(work_dir), check=True)
    else:
        subprocess.run(["mv", str(pkg), str(work_dir / "custom_system.img")], check=True)

    custom_img = work_dir / "custom_system.img"
    if not custom_img.exists():
        find = subprocess.run(
            ["find", str(work_dir), "-maxdepth", "2", "-name", "*.img",
             "!", "-name", "stock_super_sparse.img"],
            capture_output=True, text=True)
        results = [f for f in find.stdout.strip().split("\n") if f]
        if results:
            subprocess.run(["mv", results[0], str(custom_img)], check=True)
        else:
            raise FileNotFoundError("Could not find extracted .img file")
    return custom_img
