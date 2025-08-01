#!/usr/bin/env bash

# setup-enhanced-news.bash
# Setup script for the enhanced RSS-crawling tech news system

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Enhanced Tech News System Setup ==="
echo

# Check if we're replacing an existing system
if [[ -f "$SCRIPT_DIR/perplexity-tech-news.bash" ]]; then
    echo "Found existing script. Creating backup..."
    cp "$SCRIPT_DIR/perplexity-tech-news.bash" "$SCRIPT_DIR/perplexity-tech-news.bash.backup"
    echo "Backup created: perplexity-tech-news.bash.backup"
fi

# Check for required system packages
echo "Checking system requirements..."
MISSING_PACKAGES=()

if ! command -v curl &>/dev/null; then
    MISSING_PACKAGES+=(curl)
fi

if ! command -v jq &>/dev/null; then
    MISSING_PACKAGES+=(jq)
fi

if ! command -v xmllint &>/dev/null; then
    MISSING_PACKAGES+=(libxml2-utils)
fi

if [[ ${#MISSING_PACKAGES[@]} -gt 0 ]]; then
    echo "Missing required packages: ${MISSING_PACKAGES[*]}"
    echo "Install them with:"
    echo "  sudo apt-get update && sudo apt-get install ${MISSING_PACKAGES[*]}"
    echo "  # OR on CentOS/RHEL: sudo yum install ${MISSING_PACKAGES[*]}"
    echo "  # OR on macOS: brew install ${MISSING_PACKAGES[*]}"
    echo
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 1
    fi
fi

# Set up file permissions
echo "Setting up files and permissions..."

# Make scripts executable
chmod +x "$SCRIPT_DIR/perplexity-tech-news-enhanced.bash"
chmod +x "$0"

# Set secure permissions for sensitive files
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    chmod 600 "$SCRIPT_DIR/.env"
    echo "Secured .env file permissions"
fi

if [[ -f "$SCRIPT_DIR/prompt-updated.txt" ]]; then
    chmod 600 "$SCRIPT_DIR/prompt-updated.txt"
    cp "$SCRIPT_DIR/prompt-updated.txt" "$SCRIPT_DIR/prompt.txt"
    chmod 600 "$SCRIPT_DIR/prompt.txt"
    echo "Updated prompt.txt with new RSS-aware version"
fi

if [[ -f "$SCRIPT_DIR/rss_feeds.txt" ]]; then
    chmod 644 "$SCRIPT_DIR/rss_feeds.txt"
    echo "Set up RSS feeds configuration"
fi

# Create RSS data directory
mkdir -p "$SCRIPT_DIR/rss_data"
echo "Created RSS data directory"

# Check .env file
if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
    echo
    echo "WARNING: .env file not found!"
    echo "Create .env file with the following variables:"
    echo "  PERPLEXITY_API=your_api_key_here"
    echo "  MJ_APIKEY_PUBLIC=your_mailjet_public_key"
    echo "  MJ_APIKEY_PRIVATE=your_mailjet_private_key"
    echo "  FROM_EMAIL=your_from_email@domain.com"
    echo "  FROM_NAME=Your Name"
    echo "  TO_EMAIL=destination@domain.com"
    echo
    echo "Then run: chmod 600 .env"
fi

echo
echo "=== Setup Complete ==="
echo
echo "Enhanced Features:"
echo "• RSS feeds are now downloaded and parsed locally"
echo "• Content is filtered by recency (last 24 hours)"
echo "• Better categorization of articles"  
echo "• Automatic cleanup of old RSS data"
echo "• Improved error handling and logging"
echo
echo "Configuration Files:"
echo "• perplexity-tech-news-enhanced.bash - Main enhanced script"
echo "• rss_feeds.txt - RSS feed URLs (edit to add/remove feeds)"
echo "• prompt.txt - Updated prompt for local RSS content"
echo "• .env - API keys and email settings (secure permissions)"
echo
echo "Usage:"
echo "  ./perplexity-tech-news-enhanced.bash"
echo
echo "To customize RSS feeds, edit rss_feeds.txt"
echo "Log files are stored in tech_news.log"
echo "RSS data is temporarily stored in rss_data/ directory"
echo

# Test run option
echo
read -p "Would you like to run a test? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [[ -f "$SCRIPT_DIR/.env" ]]; then
        echo "Running test..."
        "$SCRIPT_DIR/perplexity-tech-news-enhanced.bash"
    else
        echo "Cannot run test without .env file. Please create it first."
    fi
fi

echo "Setup script completed!"
