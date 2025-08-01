# AI Powered Tech News RSS Crawler and Digest System

This enhanced version of the tech news system crawls RSS feeds locally instead of asking Perplexity to search for news online. This provides better control, faster processing, and more reliable results.

## What's New

### Key Improvements
- **Local RSS Crawling**: Downloads and parses RSS feeds directly instead of relying on Perplexity's web search
- **Better Content Filtering**: Filters by publication date (last 24 hours) and content quality
- **Configurable Feed Sources**: Easy-to-edit RSS feeds list in `rss_feeds.txt`
- **Enhanced Error Handling**: Better retry logic and error reporting
- **Automatic Cleanup**: Removes old RSS data files automatically
- **Improved Categorization**: More accurate article categorization

### Architecture Changes
1. **RSS Crawler**: Downloads feeds from configured URLs
2. **Content Parser**: Extracts recent articles using XML parsing
3. **Content Consolidator**: Combines articles by category
4. **Perplexity Processor**: Sends consolidated content to Perplexity for analysis
5. **Email Delivery**: Sends formatted digest via Mailjet

## Files Overview

| File | Purpose |
|------|---------|
| `perplexity-tech-news-enhanced.bash` | Main enhanced script with RSS crawling |
| `rss_feeds.txt` | List of RSS feed URLs to crawl |
| `prompt-updated.txt` | Updated prompt for processing local RSS content |
| `setup-enhanced-news.bash` | Setup script for easy deployment |
| `.env` | API keys and configuration (create manually) |

## Installation

### Prerequisites
```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install curl jq libxml2-utils

# CentOS/RHEL/Fedora  
sudo yum install curl jq libxml2

# macOS
brew install curl jq libxml2
```

### Quick Setup
1. Run the setup script:
```bash
chmod +x setup-enhanced-news.bash
./setup-enhanced-news.bash
```

2. Create your `.env` file:
```bash
cat > .env << 'EOF'
PERPLEXITY_API=your_perplexity_api_key
MJ_APIKEY_PUBLIC=your_mailjet_public_key
MJ_APIKEY_PRIVATE=your_mailjet_private_key
FROM_EMAIL=sender@yourdomain.com
FROM_NAME=Tech News Bot
TO_EMAIL=recipient@yourdomain.com
EOF

chmod 600 .env
```

### Manual Setup
1. Copy all files to your desired directory
2. Make scripts executable: `chmod +x *.bash`
3. Set secure permissions: `chmod 600 .env prompt.txt`
4. Create RSS data directory: `mkdir rss_data`

## Configuration

### RSS Feeds (`rss_feeds.txt`)
Edit this file to add/remove RSS feeds. Format: one URL per line, comments start with `#`.

### Environment Variables (`.env`)
```bash
PERPLEXITY_API=your_api_key          # Perplexity AI API key
MJ_APIKEY_PUBLIC=mailjet_public      # Mailjet public key
MJ_APIKEY_PRIVATE=mailjet_private    # Mailjet private key
FROM_EMAIL=sender@domain.com         # Sender email
FROM_NAME=News Digest                # Sender name
TO_EMAIL=recipient@domain.com        # Recipient email
```

## Usage

### Run Once
```bash
./perplexity-tech-news-enhanced.bash
```

### Schedule with Cron
```bash
# Edit crontab
crontab -e

# Add line for daily execution at 8 AM
0 8 * * * /path/to/perplexity-tech-news-enhanced.bash
```

### Monitor Logs
```bash
tail -f tech_news.log
```

## How It Works

### 1. RSS Feed Crawling
- Reads URLs from `rss_feeds.txt`
- Downloads each RSS feed with proper error handling
- Validates XML format
- Respects rate limits (2-second delay between feeds)

### 2. Content Processing
- Parses XML using `xmllint`
- Extracts title, link, description, publication date
- Filters articles by age (last 24 hours)
- Categorizes articles based on source URL patterns
- Consolidates into structured format

### 3. AI Processing
- Sends consolidated RSS content to Perplexity
- Uses updated prompt optimized for local content
- Requests structured output with proper formatting
- Handles API retries and error responses

### 4. Email Delivery
- Formats content for email
- Sends via Mailjet API
- Includes proper error handling and logging

## Troubleshooting

### Common Issues

**Missing Dependencies**
```bash
# Check what's missing
command -v curl jq xmllint

# Install missing packages (Ubuntu/Debian)
sudo apt-get install curl jq libxml2-utils
```

**RSS Feed Errors**
- Check `tech_news.log` for specific feed errors
- Verify RSS URLs are valid and accessible
- Some feeds may have changed URLs or formats

**API Failures**
- Verify API keys in `.env` file
- Check API rate limits and quotas
- Review network connectivity

**Permission Errors**
```bash
# Fix file permissions
chmod 600 .env prompt.txt
chmod +x perplexity-tech-news-enhanced.bash
chmod 644 rss_feeds.txt
```

**XML Parsing Issues**
- Install libxml2-utils: `sudo apt-get install libxml2-utils`
- Check if RSS feeds return valid XML

### Debug Mode
Add debug output by modifying the log level:
```bash
# Add to script temporarily
set -x  # Enable debug output
```

### Testing Individual Components

**Test RSS Download**
```bash
curl -sS -L -m 30 -A "RSS-Crawler/1.0" "https://www.example.com/rss.xml" | head -20
```

**Test XML Parsing**
```bash
xmllint --xpath "//item/title/text()" feed.xml | head -5
```

**Test Perplexity API**
```bash
# Use curl to test API directly with your key
curl -H "Authorization: Bearer YOUR_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"model":"sonar-pro","messages":[{"role":"user","content":"Test"}]}' \
     https://api.perplexity.ai/chat/completions
```

## Customization

### Adding New RSS Feeds
1. Edit `rss_feeds.txt`
2. Add URL on new line
3. Feeds are automatically categorized by URL patterns

### Modifying Categories
Edit the categorization logic in the `parse_rss_feed()` function:
```bash
case "$feed_url" in
    *yoursite*) category="YOUR CATEGORY" ;;
esac
```

### Changing Time Window
Modify `MAX_FEED_AGE_HOURS` variable:
```bash
MAX_FEED_AGE_HOURS=48  # Change to 48 hours
```

### Custom Prompt
Edit `prompt-updated.txt` to modify how Perplexity processes the content.

## Security Notes

- `.env` file contains sensitive API keys - keep permissions at 600
- RSS data is automatically cleaned up after 7 days
- All downloads respect robots.txt and use appropriate user agents
- No sensitive data is logged (API keys are masked)

## Performance

- **RSS Crawling**: ~2-5 seconds per feed
- **Processing**: ~10-30 seconds depending on content volume
- **API Call**: ~5-15 seconds depending on content size
- **Total Runtime**: Usually 1-3 minutes for 8-10 feeds

## Migration from Original Script

The enhanced script maintains compatibility with the original `.env` file and email settings. Key differences:

1. **RSS Content**: Now downloaded locally instead of searched via Perplexity
2. **Prompt**: Updated to work with pre-processed RSS content
3. **Dependencies**: Requires `xmllint` for XML parsing
4. **Structure**: More modular with separate functions for RSS handling

Your existing `.env` file and cron jobs should work without modification.
