# GNOME Wayland OCR Shortcut

This repository contains a simple setup script that equips a fresh Ubuntu/GNOME Wayland installation with an interactive Optical Character Recognition (OCR) shortcut.

Due to Wayland's strict security protocols, background scripts are completely blocked from recording the screen or intercepting clipboard data directly. To get around this without relying on complex shell extensions, this setup seamlessly integrates with GNOME's built-in DBus APIs to trigger the native screenshot UI and monitor your `~/Pictures/Screenshots` directory for the captured image.

## Requirements
- GNOME Desktop Environment (Versions 42+ heavily supported)
- Wayland display server
- `apt` package manager (Ubuntu, Debian, Pop!_OS, etc.)

## Features
- Provides an interactive area selection crosshair.
- Extracts text using Google's **Tesseract OCR** engine.
- Instantly places the extracted text into your clipboard.
- Operates on a single shortcut (`Win + Shift + O`).
- Cleans up the temporary screenshot from your folder automatically.

## How to Install

1. Make the setup script executable:
   ```bash
   chmod +x install.sh
   ```

2. Run the script:
   ```bash
   ./install.sh
   ```
   *(Note: You will be prompted for your `sudo` password to install the required dependencies like `tesseract-ocr` and `wl-clipboard`)*

## How to Use

1. Press **`Win + Shift + O`** (the Super key).
2. The screen will dim and GNOME's native area selection tool will appear.
3. Click and drag over the text you wish to copy, then press **Enter** (or click the Capture button).
4. Wait a few moments. A desktop notification will pop up saying **"OCR Complete"**.
5. Paste (`Ctrl + V`) your extracted text anywhere!

## Uninstalling
If you wish to remove this tool:
1. Delete the script: `rm ~/.local/bin/ocr-to-clipboard.sh`
2. Remove the custom shortcut from Settings -> Keyboard -> Custom Shortcuts.
3. Optionally remove the dependencies: `sudo apt remove tesseract-ocr wl-clipboard`
