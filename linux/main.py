#!/usr/bin/env python3
import sys
import os

# Ensure project root is on path so scripts/ can be found
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from PySide6.QtWidgets import QApplication
from linux.ui.main_window import MainWindow


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("Custom-Super-Maker")
    win = MainWindow()
    win.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
