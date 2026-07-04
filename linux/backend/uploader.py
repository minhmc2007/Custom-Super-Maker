import subprocess
import json
import shutil
from pathlib import Path

try:
    import requests
except ImportError:
    requests = None


def package_tar(work_dir: Path, run_id: str, log_func=print) -> Path:
    super_img = work_dir / "super.img"
    if not super_img.exists():
        old = work_dir / "repacked_super.img"
        if old.exists():
            old.rename(super_img)
        else:
            raise FileNotFoundError("No repacked super image found")
    tar_name = f"super_repack_{run_id}.tar"
    tar_path = work_dir / tar_name
    log_func(f"Creating tarball: {tar_name}")
    r = subprocess.run(
        ["tar", "-cvf", str(tar_path), "super.img"],
        capture_output=True, text=True, cwd=str(work_dir))
    if r.returncode != 0:
        raise RuntimeError(f"tar failed: {r.stderr}")
    return tar_path


def upload_gofile(file_path: Path, log_func=print) -> str:
    if requests is None:
        raise ImportError("requests library is required for upload")
    log_func("Uploading to GoFile...")
    srv_resp = requests.get("https://api.gofile.io/servers", timeout=30)
    server = srv_resp.json().get("data", {}).get("servers", [{}])[0].get("name")
    if not server:
        raise RuntimeError("Failed to get GoFile server")
    with open(file_path, "rb") as f:
        url = f"https://{server}.gofile.io/uploadFile"
        log_func(f"Uploading to {url}...")
        resp = requests.post(url, files={"file": f}, timeout=600)
    data = resp.json().get("data", {})
    dl_page = data.get("downloadPage")
    if dl_page:
        log_func(f"Download link: {dl_page}")
        return dl_page
    raise RuntimeError(f"GoFile upload failed: {resp.text}")
