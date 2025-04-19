#!/usr/bin/env bash
# Install as user service (no sudo required)

set -eo pipefail

SERVICE_NAME="perplexity-tech-news"
USER_SYSTEMD_DIR="$HOME/.config/systemd/user"
SCRIPT_DIR="$HOME/src/perplexity-daily-news-summary"

# Create systemd user directory
mkdir -p "$USER_SYSTEMD_DIR"

# Install service files
cp -v \
  "$SCRIPT_DIR/$SERVICE_NAME.service" \
  "$SCRIPT_DIR/$SERVICE_NAME.timer" \
  "$USER_SYSTEMD_DIR/"

# Enable lingering for user services
sudo loginctl enable-linger $(whoami)

# Reload and enable
systemctl --user daemon-reload
systemctl --user enable --now "$SERVICE_NAME.timer"

echo "Installed user service for $(whoami)"
echo "Check status with: systemctl --no-pager --user status $SERVICE_NAME.timer"
