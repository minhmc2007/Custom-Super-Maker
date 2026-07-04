from PySide6.QtWidgets import (
    QMainWindow, QTabWidget, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QLineEdit, QPushButton, QCheckBox, QComboBox,
    QGroupBox, QFormLayout, QFileDialog, QMessageBox, QProgressBar,
)
from PySide6.QtCore import QThread, Signal
from pathlib import Path
from .log_widget import LogWidget
from ..backend import firmware as fw_mod
from ..backend import porting as pt_mod
from ..backend import repacker as rp_mod
from ..backend import uploader as up_mod


class WorkflowThread(QThread):
    finished = Signal()
    error = Signal(str)
    status = Signal(str)

    def __init__(self, steps, parent=None):
        super().__init__(parent)
        self._steps = steps

    def run(self):
        try:
            for step in self._steps:
                self.status.emit(f"Running: {step.__name__}")
                step()
            self.status.emit("All steps complete")
        except Exception as e:
            self.error.emit(str(e))
        finally:
            self.finished.emit()


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Custom-Super-Maker Desktop")
        self.resize(950, 700)

        self._work_dir = Path.cwd() / "work"
        self._log_widget = LogWidget()
        self._progress = QProgressBar()
        self._progress.setVisible(False)

        tabs = QTabWidget()
        tabs.addTab(self._build_base_tab(), "Base Firmware")
        tabs.addTab(self._build_source_tab(), "Custom System")
        tabs.addTab(self._build_repack_tab(), "Repack & Upload")

        central = QWidget()
        layout = QVBoxLayout(central)
        layout.addWidget(tabs)
        layout.addWidget(self._log_widget, stretch=1)
        layout.addWidget(self._progress)
        self.setCentralWidget(central)

        self._base_model = None
        self._base_csc = None
        self._base_imei = None
        self._super_img = None
        self._custom_img = None
        self._patched_dir = None

    # ---------- helpers ----------

    def _log(self, text): self._log_widget.log(text)

    def _run_workflow(self, steps):
        self._progress.setVisible(True)
        self._progress.setRange(0, 0)
        self._thread = WorkflowThread(steps)
        self._thread.status.connect(lambda s: self.statusBar().showMessage(s))
        self._thread.error.connect(lambda e: QMessageBox.critical(self, "Error", e))
        self._thread.finished.connect(lambda: self._progress.setVisible(False))
        self._thread.start()

    # ---------- Tab 1: Base Firmware ----------

    def _build_base_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)

        grp = QGroupBox("Samloader Firmware Download")
        form = QFormLayout(grp)
        self._base_model = QLineEdit()
        self._base_model.setPlaceholderText("e.g. SM-A155F")
        form.addRow("Model:", self._base_model)
        self._base_csc = QLineEdit("XXV")
        form.addRow("CSC:", self._base_csc)
        self._base_imei = QLineEdit()
        self._base_imei.setPlaceholderText("15-digit IMEI")
        form.addRow("IMEI:", self._base_imei)
        dl_btn = QPushButton("Download & Extract Super")
        dl_btn.clicked.connect(self._do_download_base)
        form.addRow(dl_btn)
        layout.addWidget(grp)

        grp2 = QGroupBox("Or Use Existing Super Image")
        h = QHBoxLayout(grp2)
        self._super_path = QLineEdit()
        self._super_path.setPlaceholderText("Path to stock_super_sparse.img")
        h.addWidget(self._super_path)
        browse_btn = QPushButton("Browse")
        browse_btn.clicked.connect(lambda: self._super_path.setText(
            QFileDialog.getOpenFileName(self, "Select Super Image", filter="Images (*.img)")[0]))
        h.addWidget(browse_btn)
        load_btn = QPushButton("Load")
        load_btn.clicked.connect(lambda: setattr(self, '_super_img', Path(self._super_path.text())))
        h.addWidget(load_btn)
        layout.addWidget(grp2)
        layout.addStretch()
        return tab

    def _do_download_base(self):
        model = self._base_model.text().strip()
        csc = self._base_csc.text().strip()
        imei = self._base_imei.text().strip()
        if not model or not csc or not imei:
            QMessageBox.warning(self, "Missing Info", "Fill in Model, CSC, and IMEI")
            return

        def steps():
            import os
            os.makedirs(self._work_dir, exist_ok=True)
            ver = fw_mod.checkupdate(model, csc, imei, self._log)
            self._log(f"Version: {ver}")
            fw = fw_mod.download(model, csc, imei, ver, self._work_dir, self._log)
            self._super_img = fw_mod.extract_super(fw, self._work_dir, self._log)
            self._log(f"Super ready: {self._super_img}")

        self._run_workflow([steps])

    # ---------- Tab 2: Custom System ----------

    def _build_source_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)

        self._port_check = QCheckBox("Enable OEM Port (instead of GSI download)")
        layout.addWidget(self._port_check)

        # Porting options
        self._port_grp = QGroupBox("OEM Port Options")
        port_form = QFormLayout(self._port_grp)
        self._port_tool = QComboBox()
        self._port_tool.addItems(["Link2GSI", "ErfanGSIs"])
        port_form.addRow("Port Tool:", self._port_tool)
        self._port_rom_type = QComboBox()
        self._port_rom_type.addItems(["OneUI", "Pixel", "MIUI", "OxygenOS", "Flyme", "Moto", "ColorOS", "Generic"])
        port_form.addRow("ROM Type:", self._port_rom_type)
        self._port_url = QLineEdit()
        self._port_url.setPlaceholderText("Direct firmware URL (leave empty for Samloader)")
        port_form.addRow("Firmware URL:", self._port_url)
        self._port_model = QLineEdit()
        self._port_model.setPlaceholderText("e.g. SM-S918B")
        port_form.addRow("Port Model:", self._port_model)
        self._port_csc = QLineEdit("XXV")
        port_form.addRow("Port CSC:", self._port_csc)
        self._port_imei = QLineEdit()
        self._port_imei.setPlaceholderText("15-digit IMEI")
        port_form.addRow("Port IMEI:", self._port_imei)
        port_btn = QPushButton("Run OEM Port")
        port_btn.clicked.connect(self._do_oem_port)
        port_form.addRow(port_btn)
        self._port_grp.setEnabled(False)
        layout.addWidget(self._port_grp)

        # GSI options
        self._gsi_grp = QGroupBox("GSI Download")
        gsi_form = QFormLayout(self._gsi_grp)
        self._gsi_url = QLineEdit()
        self._gsi_url.setPlaceholderText("Direct download URL to system image")
        gsi_form.addRow("GSI URL:", self._gsi_url)
        gsi_btn = QPushButton("Download GSI")
        gsi_btn.clicked.connect(self._do_download_gsi)
        gsi_form.addRow(gsi_btn)
        layout.addWidget(self._gsi_grp)

        self._port_check.toggled.connect(self._port_grp.setEnabled)
        self._port_check.toggled.connect(lambda e: self._gsi_grp.setEnabled(not e))

        # Patch firmware (only for OEM port)
        patch_btn = QPushButton("Patch Firmware Partitions (OEM Port Only)")
        patch_btn.clicked.connect(self._do_patch_firmware)
        layout.addWidget(patch_btn)
        layout.addStretch()
        return tab

    def _do_oem_port(self):
        def steps():
            import os
            os.makedirs(self._work_dir, exist_ok=True)
            url = self._port_url.text().strip()
            args = ()
            if not url:
                args = (self._port_model.text().strip(), self._port_csc.text().strip(), self._port_imei.text().strip())
            self._custom_img = pt_mod.run_oem_port(
                self._work_dir, self._port_tool.currentText(), self._port_rom_type.currentText(),
                firmware_url=url or None, samloader_args=args, log_func=self._log)
            self._log(f"Custom system: {self._custom_img}")
        self._run_workflow([steps])

    def _do_patch_firmware(self):
        if not self._super_img or not self._super_img.exists():
            QMessageBox.warning(self, "Missing Super", "Download/load base firmware first")
            return

        def steps():
            self._patched_dir = self._work_dir / "patched_partitions"
            pt_mod.run_patch_firmware(self._super_img, self._patched_dir, self._log)
            self._log(f"Patched partitions: {self._patched_dir}")
        self._run_workflow([steps])

    def _do_download_gsi(self):
        url = self._gsi_url.text().strip()
        if not url:
            QMessageBox.warning(self, "Missing URL", "Enter a GSI download URL")
            return

        def steps():
            import os
            os.makedirs(self._work_dir, exist_ok=True)
            self._custom_img = pt_mod.download_gsi(url, self._work_dir, self._log)
            self._log(f"Custom system: {self._custom_img}")
        self._run_workflow([steps])

    # ---------- Tab 3: Repack & Upload ----------

    def _build_repack_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)

        self._erofs_check = QCheckBox("Compress system.img via EROFS")
        self._erofs_check.setChecked(True)
        layout.addWidget(self._erofs_check)

        repack_btn = QPushButton("Repack Super")
        repack_btn.clicked.connect(self._do_repack)
        layout.addWidget(repack_btn)

        layout.addWidget(QLabel("--- Upload ---"))
        self._upload_release = QCheckBox("Also upload to GitHub Release")
        layout.addWidget(self._upload_release)
        upload_btn = QPushButton("Upload to GoFile")
        upload_btn.clicked.connect(self._do_upload)
        layout.addWidget(upload_btn)

        run_all_btn = QPushButton("Run Full Pipeline")
        run_all_btn.clicked.connect(self._do_full_pipeline)
        layout.addWidget(run_all_btn)
        layout.addStretch()
        return tab

    def _do_repack(self):
        if not self._super_img or not self._super_img.exists():
            QMessageBox.warning(self, "Missing Super", "Download/load base firmware first")
            return
        if not self._custom_img or not self._custom_img.exists():
            QMessageBox.warning(self, "Missing Custom System", "Run OEM port or download GSI first")
            return

        def steps():
            if self._erofs_check.isChecked():
                compressed = self._work_dir / "custom_system_compressed.img"
                rp_mod.compress_erofs(self._custom_img, compressed, self._log)
                compressed.replace(self._custom_img)
            out = self._work_dir / "repacked_super.img"
            rp_mod.repack_super(self._super_img, self._custom_img, out, self._patched_dir, self._log)
            self._log(f"Repacked: {out}")
        self._run_workflow([steps])

    def _do_upload(self):
        def steps():
            tar_path = up_mod.package_tar(self._work_dir, str(id(self)), self._log)
            url = up_mod.upload_gofile(tar_path, self._log)
            self._log(f"Download page: {url}")
        self._run_workflow([steps])

    def _do_full_pipeline(self):
        steps = []
        if not self._super_img or not self._super_img.exists():
            steps.append(self._do_download_base)
        if not self._custom_img or not self._custom_img.exists():
            if self._port_check.isChecked():
                steps.append(self._do_oem_port)
            else:
                steps.append(self._do_download_gsi)
        steps.append(self._do_repack)
        self._run_workflow(steps)
