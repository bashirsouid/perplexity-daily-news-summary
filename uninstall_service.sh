#!/usr/bin/env bash
# Remove user service

set -eo pipefail

SERVICE_NAME="perplexity-tech-news"

systemctl --user stop "$SERVICE_NAME.timer"
systemctl --user disable "$SERVICE_NAME.timer"
systemctl --user stop "$SERVICE_NAME.service"
systemctl --user disable "$SERVICE_NAME.service"

rm -fv \
  "$HOME/.config/systemd/user/$SERVICE_NAME.service" \
  "$HOME/.config/systemd/user/$SERVICE_NAME.timer"

systemctl --user daemon-reload
systemctl --user reset-failed

echo "Successfully uninstalled user service"
