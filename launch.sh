#!/usr/bin/env bash
# Stumble Home - Quick Game Launcher
cd "$(dirname "$0")"
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
echo "Launching Stumble Home on ${DISPLAY:-$WAYLAND_DISPLAY}..."
godot --path . "$@"
