import subprocess
import shutil
import os
from pathlib import Path


def check_samloader() -> bool:
    return shutil.which("python3") is not None


def checkupdate(model: str, csc: str, imei: str, log_func=print) -> str:
    cmd = ["python3", "-m", "samloader", "-m", model, "-r", csc, "-i", imei, "checkupdate"]
    log_func(f"$ {' '.join(cmd)}")
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        log_func(f"samloader checkupdate failed:\n{r.stderr}")
        raise RuntimeError(f"Failed to fetch firmware version: {r.stderr.strip()}")
    version = r.stdout.strip()
    log_func(f"Firmware version: {version}")
    return version


def download(model: str, csc: str, imei: str, version: str, out_dir: Path, log_func=print) -> Path:
    cmd = ["python3", "-m", "samloader", "-m", model, "-r", csc, "-i", imei,
           "download", "-v", version, "-O", str(out_dir)]
    log_func(f"$ {' '.join(cmd)}")
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    if r.returncode != 0:
        log_func(f"samloader download failed:\n{r.stderr}")
        raise RuntimeError(f"Download failed: {r.stderr.strip()}")
    enc = list(out_dir.glob("*.enc*"))
    if enc:
        enc_file = enc[0]
        log_func("Decrypting firmware...")
        dec = ["python3", "-m", "samloader", "-m", model, "-r", csc, "-i", imei,
               "decrypt", "-v", version, "-i", str(enc_file), "-o", str(out_dir / "stock_firmware.zip")]
        r2 = subprocess.run(dec, capture_output=True, text=True, timeout=600)
        if r2.returncode != 0:
            raise RuntimeError(f"Decryption failed: {r2.stderr.strip()}")
        enc_file.unlink()
        return out_dir / "stock_firmware.zip"
    zips = list(out_dir.glob("*.zip"))
    if zips:
        z = zips[0]
        dest = out_dir / "stock_firmware.zip"
        if z != dest:
            z.rename(dest)
        return dest
    raise RuntimeError("No firmware files found after download")


def extract_super(firmware_zip: Path, work_dir: Path, log_func=print) -> Path:
    log_func("Extracting AP tarmd5 and super.img.lz4...")
    r = subprocess.run(
        ["unzip", "-o", "-j", str(firmware_zip), "*AP*.tar.md5"],
        capture_output=True, text=True, cwd=str(work_dir))
    if r.returncode != 0:
        raise RuntimeError(f"Failed to extract AP tar: {r.stderr}")
    ap_files = list(work_dir.glob("AP_*.tar.md5"))
    if not ap_files:
        raise RuntimeError("AP tar not found in firmware zip")
    ap = ap_files[0]
    r2 = subprocess.run(
        ["tar", "-xf", str(ap), "--wildcards", "*super.img.lz4"],
        capture_output=True, text=True, cwd=str(work_dir))
    if r2.returncode != 0:
        raise RuntimeError(f"Failed to extract super.img.lz4: {r2.stderr}")
    super_lz4 = work_dir / "super.img.lz4"
    if not super_lz4.exists():
        raise RuntimeError("super.img.lz4 not found in AP tar")
    log_func("Decompressing super.img.lz4...")
    r3 = subprocess.run(
        ["lz4", "-d", str(super_lz4), str(work_dir / "stock_super_sparse.img")],
        capture_output=True, text=True)
    if r3.returncode != 0:
        raise RuntimeError(f"Failed to decompress super: {r3.stderr}")
    super_lz4.unlink()
    ap.unlink()
    log_func(f"Stock super: {work_dir / 'stock_super_sparse.img'}")
    return work_dir / "stock_super_sparse.img"
