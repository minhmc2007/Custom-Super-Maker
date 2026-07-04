from PySide6.QtCore import QObject, Signal
from PySide6.QtWidgets import QTextEdit, QWidget, QVBoxLayout, QPushButton
from PySide6.QtGui import QTextCursor, QColor, QFont


class LogSignal(QObject):
    new_line = Signal(str)


class LogWidget(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self._signal = LogSignal()
        self._signal.new_line.connect(self._append)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        self._text = QTextEdit()
        self._text.setReadOnly(True)
        self._text.setFont(QFont("monospace", 9))
        layout.addWidget(self._text)
        clear_btn = QPushButton("Clear Log")
        clear_btn.clicked.connect(self._text.clear)
        layout.addWidget(clear_btn)

    def _append(self, text: str):
        self._text.moveCursor(QTextCursor.MoveOperation.End)
        color = "gray" if text.startswith("$ ") else "white"
        self._text.setTextColor(QColor(color))
        self._text.append(text)

    def log(self, text: str):
        self._signal.new_line.emit(text)
