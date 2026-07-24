#!/bin/bash
# install_windows_titlebar_buttons.sh
# Applies Windows-style window controls (square, large, edge-touching) to GTK3 and GTK4 apps on Ubuntu.

echo "Installing Windows-style Window Controls CSS..."

# Ensure config directories exist
mkdir -p ~/.config/gtk-3.0
mkdir -p ~/.config/gtk-4.0

echo "Applying GTK4 CSS..."
cat << 'EOF' > ~/.config/gtk-4.0/gtk.css
/*
 * Windows-like Window Controls CSS (GTK 4)
 * Makes titlebar buttons square, wider, and touch the edges using hitbox expansion.
 */

/* Override Yaru's specific windowcontrols styles for GTK 4 */
headerbar windowcontrols button,
windowcontrols button,
headerbar windowcontrols button.titlebutton,
windowcontrols button.titlebutton {
    background-color: transparent;
    background-image: none;
    border-radius: 0;
    border: none;
    box-shadow: none;
    
    /* Make buttons wider like Windows, but don't force height to prevent thickening titlebar */
    min-width: 36px; 
    transition: background-color 0.15s ease, color 0.15s ease;
}

/* FOR MAXIMIZED WINDOWS ONLY: Expand hitbox vertically to touch top edge */
window.maximized headerbar windowcontrols button,
window.maximized windowcontrols button,
window.maximized headerbar windowcontrols button.titlebutton,
window.maximized windowcontrols button.titlebutton {
    padding-top: 15px;
    margin-top: -15px;
}

/* Make the close button rounded to match floating window corners */
headerbar windowcontrols.end button:last-child,
windowcontrols.end button:last-child,
headerbar windowcontrols button.close,
windowcontrols button.close {
    border-top-right-radius: 8px;
}

/* FOR MAXIMIZED WINDOWS ONLY: Force the close button hitbox into absolute top-right corner and remove rounding */
window.maximized headerbar windowcontrols.end button:last-child,
window.maximized windowcontrols.end button:last-child,
window.maximized headerbar windowcontrols button.close,
window.maximized windowcontrols button.close,
window.tiled headerbar windowcontrols.end button:last-child,
window.tiled windowcontrols.end button:last-child,
window.tiled headerbar windowcontrols button.close,
window.tiled windowcontrols button.close,
window.fullscreen headerbar windowcontrols.end button:last-child,
window.fullscreen windowcontrols.end button:last-child,
window.fullscreen headerbar windowcontrols button.close,
window.fullscreen windowcontrols button.close {
    padding-right: 30px;
    margin-right: -30px;
    border-top-right-radius: 0;
}


/* Override the circular background that Yaru sets on the image elements */
headerbar windowcontrols button > image,
windowcontrols button > image {
    border-radius: 0;
    background: transparent;
    background-color: transparent;
    background-image: none;
    box-shadow: none;
    min-height: 16px;
    min-width: 16px;
    padding: 0;
    margin: 0;
}

/* Hover and Active states for Minimize button */
headerbar windowcontrols button.minimize:hover,
windowcontrols button.minimize:hover {
    background-color: rgba(128, 128, 128, 0.18);
}
headerbar windowcontrols button.minimize:active,
windowcontrols button.minimize:active {
    background-color: rgba(128, 128, 128, 0.3);
}

/* Hover and Active states for Maximize / Unmaximize buttons */
headerbar windowcontrols button.maximize:hover,
windowcontrols button.maximize:hover {
    background-color: rgba(128, 128, 128, 0.18);
}
headerbar windowcontrols button.maximize:active,
windowcontrols button.maximize:active {
    background-color: rgba(128, 128, 128, 0.3);
}

/* Hover and Active states for Close button (Classic Windows Red) */
headerbar windowcontrols button.close:hover,
windowcontrols button.close:hover {
    background-color: #e81123; /* Windows Red */
    color: #ffffff;
}
headerbar windowcontrols button.close:active,
windowcontrols button.close:active {
    background-color: #f1707a; /* Lighter Red */
    color: #ffffff;
}

/* Make sure Yaru's image hover states don't re-apply background circles */
headerbar windowcontrols button:hover > image,
windowcontrols button:hover > image,
headerbar windowcontrols button:active > image,
windowcontrols button:active > image {
    background: transparent;
    background-color: transparent;
    background-image: none;
    border-radius: 0;
    box-shadow: none;
}
EOF

echo "Applying GTK3 CSS..."
cat << 'EOF' > ~/.config/gtk-3.0/gtk.css
/*
 * Windows-like Window Controls CSS (GTK 3)
 * Makes titlebar buttons square, wider, and touch the edges using hitbox expansion.
 */

/* Override Yaru's specific button.titlebutton:not(.appmenu) selectors */
headerbar button.titlebutton:not(.appmenu),
.titlebar button.titlebutton:not(.appmenu),
headerbar windowcontrols button,
windowcontrols button {
    background-color: transparent;
    background-image: none;
    border-radius: 0;
    border: none;
    box-shadow: none;
    
    /* Make buttons wider like Windows, but don't force height to prevent thickening titlebar */
    min-width: 36px; 
    transition: background-color 0.15s ease, color 0.15s ease;
}

/* FOR MAXIMIZED WINDOWS ONLY: Expand hitbox vertically to touch top edge */
window.maximized headerbar button.titlebutton:not(.appmenu),
window.maximized .titlebar button.titlebutton:not(.appmenu),
window.maximized headerbar windowcontrols button,
window.maximized windowcontrols button {
    padding-top: 15px;
    margin-top: -15px;
}

/* Make the close button rounded to match floating window corners */
headerbar windowcontrols.end button:last-child,
windowcontrols.end button:last-child,
headerbar windowcontrols button.close,
windowcontrols button.close,
headerbar button.titlebutton.close,
.titlebar button.titlebutton.close {
    border-top-right-radius: 8px;
}

/* FOR MAXIMIZED WINDOWS ONLY: Force the close button hitbox into absolute top-right corner and remove rounding */
window.maximized headerbar windowcontrols.end button:last-child,
window.maximized windowcontrols.end button:last-child,
window.maximized headerbar windowcontrols button.close,
window.maximized windowcontrols button.close,
window.maximized headerbar button.titlebutton.close,
window.maximized .titlebar button.titlebutton.close,
window.tiled headerbar windowcontrols.end button:last-child,
window.tiled windowcontrols.end button:last-child,
window.tiled headerbar windowcontrols button.close,
window.tiled windowcontrols button.close,
window.tiled headerbar button.titlebutton.close,
window.tiled .titlebar button.titlebutton.close,
window.fullscreen headerbar windowcontrols.end button:last-child,
window.fullscreen windowcontrols.end button:last-child,
window.fullscreen headerbar windowcontrols button.close,
window.fullscreen windowcontrols button.close,
window.fullscreen headerbar button.titlebutton.close,
window.fullscreen .titlebar button.titlebutton.close {
    padding-right: 30px;
    margin-right: -30px;
    border-top-right-radius: 0;
}


/* Hover and Active states for Minimize button */
headerbar button.titlebutton:not(.appmenu).minimize:hover,
.titlebar button.titlebutton:not(.appmenu).minimize:hover,
windowcontrols button.minimize:hover {
    background-color: rgba(128, 128, 128, 0.18);
    background-image: none;
}
headerbar button.titlebutton:not(.appmenu).minimize:active,
.titlebar button.titlebutton:not(.appmenu).minimize:active,
windowcontrols button.minimize:active {
    background-color: rgba(128, 128, 128, 0.3);
    background-image: none;
}

/* Hover and Active states for Maximize / Unmaximize buttons */
headerbar button.titlebutton:not(.appmenu).maximize:hover,
.titlebar button.titlebutton:not(.appmenu).maximize:hover,
windowcontrols button.maximize:hover {
    background-color: rgba(128, 128, 128, 0.18);
    background-image: none;
}
headerbar button.titlebutton:not(.appmenu).maximize:active,
.titlebar button.titlebutton:not(.appmenu).maximize:active,
windowcontrols button.maximize:active {
    background-color: rgba(128, 128, 128, 0.3);
    background-image: none;
}

/* Hover and Active states for Close button (Classic Windows Red) */
headerbar button.titlebutton:not(.appmenu).close:hover,
.titlebar button.titlebutton:not(.appmenu).close:hover,
windowcontrols button.close:hover {
    background-color: #e81123; /* Windows Red */
    background-image: none;
    color: #ffffff;
}
headerbar button.titlebutton:not(.appmenu).close:active,
.titlebar button.titlebutton:not(.appmenu).close:active,
windowcontrols button.close:active {
    background-color: #f1707a; /* Lighter Red */
    background-image: none;
    color: #ffffff;
}
EOF

echo "Done! The Windows-style window controls have been applied."
echo "Please restart your GTK applications (or log out and log back in) to see the changes."
