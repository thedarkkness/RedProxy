#!/usr/bin/env python3
"""Render a proxy link as an ANSI QR code in the terminal.

Used by utils/common.sh (render_qr) via the project's .venv interpreter,
so RedProxy doesn't depend on a system-wide qrencode install.
"""
import sys


def main() -> None:
    if len(sys.argv) < 2:
        print("usage: qr.py <data>", file=sys.stderr)
        sys.exit(1)

    try:
        import qrcode
    except ImportError:
        print("qrcode package not installed in venv", file=sys.stderr)
        sys.exit(1)

    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    qr = qrcode.QRCode(border=1)
    qr.add_data(sys.argv[1])
    qr.make(fit=True)
    qr.print_ascii(invert=True)


if __name__ == "__main__":
    main()
