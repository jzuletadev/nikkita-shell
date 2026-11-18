#!/usr/bin/env bash
# ~/nikita-shell/scripts/default-apps.sh
#
# Default apps (~/.config/mimeapps.list): folders -> Nautilus, images -> Loupe, video and
# audio -> Celluloid. Settings -> Default apps changes them later, kind by kind.

set -uo pipefail

xdg-mime default org.gnome.Nautilus.desktop inode/directory
xdg-mime default org.gnome.Loupe.desktop image/png image/jpeg image/jpg image/webp image/gif \
    image/avif image/heif image/bmp image/tiff image/svg+xml
xdg-mime default io.github.celluloid_player.Celluloid.desktop video/mp4 video/mkv video/webm \
    video/x-matroska video/quicktime video/x-msvideo video/mpeg video/ogg
xdg-mime default io.github.celluloid_player.Celluloid.desktop audio/mpeg audio/mp4 audio/flac \
    audio/ogg audio/opus audio/x-wav audio/aac
