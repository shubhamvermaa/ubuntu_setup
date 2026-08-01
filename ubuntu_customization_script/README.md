# Ubuntu Customization Scripts

This directory contains scripts for customizing Ubuntu's look, feel, and behavior.

## Scripts Included

### `install_windows_titlebar_buttons.sh`
Applies a Windows-style appearance to the window control buttons (Close, Minimize, Maximize) for GTK3 and GTK4 (Libadwaita) applications. 

**Features:**
- Changes the default circular buttons to large, square buttons that span the height of the titlebar.
- Implements the classic Windows red hover effect (`#e81123`) for the close button.
- Restructures margins and padding so the buttons touch the absolute edges of the screen when a window is maximized (adhering to Fitts's Law), allowing you to close windows by simply throwing your mouse to the top-right corner.

**Usage:**
1. Open your terminal in this directory.
2. Make the script executable:
   ```bash
   chmod +x install_windows_titlebar_buttons.sh
   ```
3. Run the script:
   ```bash
   ./install_windows_titlebar_buttons.sh
   ```
4. Restart your applications (or log out and log back in) for all changes to take full effect. (e.g. run `nautilus -q` to restart the file manager).

### `revert_windows_titlebar_buttons.sh`
Reverts the changes made by the installation script, restoring the default circular Ubuntu/Yaru window control buttons.

**Features:**
- Safely disables the custom GTK3 and GTK4 CSS by renaming them with a `.bak` extension.

**Usage:**
1. Open your terminal in this directory.
2. Make the script executable:
   ```bash
   chmod +x revert_windows_titlebar_buttons.sh
   ```
3. Run the script:
   ```bash
   ./revert_windows_titlebar_buttons.sh
   ```
4. Restart your applications for changes to apply.

### `set_custom_keybindings.sh`
Applies custom GNOME keyboard shortcuts tailored to your preferences.

**Features:**
- Binds `Super+M` (Windows key + M) to toggle window maximize/unmaximize.
- Binds `Super+V` (Windows key + V) to open the message tray (notification center).

**Usage:**
1. Open your terminal in this directory.
2. Make the script executable:
   ```bash
   chmod +x set_custom_keybindings.sh
   ```
3. Run the script:
   ```bash
   ./set_custom_keybindings.sh
   ```

### `cleanup_zoxide.sh`
Cleans up the `zoxide` database by removing paths that no longer exist on your filesystem.

**Features:**
- Safely loops through all directories tracked by `zoxide`.
- Identifies directories that have been deleted or moved.
- Removes only the broken paths from the `zoxide` database without touching the filesystem.
- Includes a safety check to ensure `zoxide` is installed before running.

**Usage:**
1. Open your terminal in this directory.
2. Make the script executable (if it isn't already):
   ```bash
   chmod +x cleanup_zoxide.sh
   ```
3. Run the script:
   ```bash
   ./cleanup_zoxide.sh
   ```

---

*Note: The script safely creates and overrides `~/.config/gtk-3.0/gtk.css` and `~/.config/gtk-4.0/gtk.css` in your local user directory. It does not modify system files.*
