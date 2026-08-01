#!/bin/bash
# revert_windows_titlebar_buttons.sh
# Reverts the Windows-style window controls by disabling the custom CSS files.

echo "Reverting Windows-style Window Controls..."

# Revert GTK3 CSS
if [ -f ~/.config/gtk-3.0/gtk.css ]; then
    mv ~/.config/gtk-3.0/gtk.css ~/.config/gtk-3.0/gtk.css.bak
    echo "Backed up and removed GTK3 custom CSS (~/.config/gtk-3.0/gtk.css.bak)."
else
    echo "GTK3 custom CSS not found, skipping."
fi

# Revert GTK4 CSS
if [ -f ~/.config/gtk-4.0/gtk.css ]; then
    mv ~/.config/gtk-4.0/gtk.css ~/.config/gtk-4.0/gtk.css.bak
    echo "Backed up and removed GTK4 custom CSS (~/.config/gtk-4.0/gtk.css.bak)."
else
    echo "GTK4 custom CSS not found, skipping."
fi

echo "Done! Please restart your GTK applications (e.g., 'nautilus -q' or log out and log back in) to see the default Ubuntu theme."
