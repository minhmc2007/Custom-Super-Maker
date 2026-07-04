import subprocess
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent.parent.parent / "scripts"


def compress_erofs(input_img: Path, output_img: Path, log_func=print):
    script = SCRIPTS_DIR / "compress_system_img.sh"
    if not script.exists():
        raise FileNotFoundError(f"compress_system_img.sh not found at {script}")
    cmd = ["sudo", str(script), str(input_img), str(output_img)]
    log_func(f"$ {' '.join(cmd)}")
    with subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          text=True, bufsize=1) as proc:
        for line in proc.stdout:
            log_func(line.rstrip())
    if proc.returncode != 0:
        raise RuntimeError("EROFS compression failed")
    if not output_img.exists() or output_img.stat().st_size == 0:
        raise RuntimeError("Compressed image is missing or empty")


def repack_super(stock_super: Path, custom_system: Path, output_img: Path,
                 patched_dir: Path = None, log_func=print):
    script = SCRIPTS_DIR / "repacksuper_lite.sh"
    if not script.exists():
        raise FileNotFoundError(f"repacksuper_lite.sh not found at {script}")
    cmd = ["sudo", str(script)]
    if patched_dir and patched_dir.exists():
        cmd += ["-P", str(patched_dir)]
    cmd += [str(stock_super), str(custom_system), str(output_img)]
    log_func(f"$ {' '.join(cmd)}")
    with subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          text=True, bufsize=1) as proc:
        for line in proc.stdout:
            log_func(line.rstrip())
    if proc.returncode != 0:
        raise RuntimeError("Repack failed")
    if not output_img.exists():
        raise RuntimeError("Repacked super image not found")
