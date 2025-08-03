# AI Powered Tech News RSS Crawler and Digest System

A Python-based system that crawls RSS feeds, categorizes articles using AI, and sends formatted email digests. This enhanced version provides better control, faster processing, and more reliable results than web-based crawling.

## What's New (Latest Updates)

### Major Architecture Changes
- **Pure Python Implementation**: Complete rewrite from bash/Python hybrid to clean Python-only codebase
- **Object-Oriented Design**: Clean class structure with organized methods and proper error handling
- **Multiple API Key Support**: Load balancing across multiple Perplexity API keys to avoid rate limits
- **HTML Email Formatting**: Rich email formatting with bold headers, clickable links, and plain text fallback
- **Robust RSS Parsing**: Fixed title extraction, CDATA handling, and XML namespace support
- **Enhanced Debugging**: Comprehensive logging with step-by-step processing information

### Key Improvements
- **Local RSS Crawling**: Downloads and parses RSS feeds directly instead of relying on Perplexity's web search
- **Smart Content Filtering**: Filters by content quality and validates both titles and links
- **Configurable Feed Sources**: Easy-to-edit RSS feeds list in `rss_feeds.txt`  
- **Advanced Error Handling**: Retry logic, connection handling, and detailed error reporting
- **Automatic Cleanup**: Removes old RSS data files automatically (7-day retention)
- **Load Balancing**: Distributes API calls across multiple keys for better performance

### Architecture Flow
1. **Environment Setup**: Loads API keys, validates configuration, sets up logging
2. **RSS Crawler**: Downloads feeds from configured URLs with rate limiting
3. **Content Parser**: Extracts articles using robust XML parsing with multiple fallback methods
4. **Content Consolidator**: Formats articles for AI processing
5. **Perplexity Processor**: Sends content to Perplexity AI with load-balanced API keys
6. **Email Delivery**: Sends HTML-formatted digest via Mailjet with plain text fallback

## Files Overview

| File | Purpose |
|------|---------|
| `perplexity-tech-news.run` | Main Python script (executable) |
| `rss_feeds.txt` | List of RSS feed URLs to crawl |
| `prompt.txt` | AI processing prompt for content categorization |
| `.env` | API keys and configuration (create manually) |
| `tech_news.log` | Runtime logs and debugging information |
| `rss_data/` | Temporary RSS data storage (auto-created) |

## Installation

### Prerequisites
```bash
# Python 3.6+ and pip
sudo apt-get update && sudo apt-get install python3 python3-pip

# Required Python packages (auto-installed by script)
pip3 install requests
```

### Quick Setup
1. Download the main script and support files
2. Make the script executable:
```bash
chmod +x perplexity-tech-news.run
```

3. Create your `.env` file:
```bash
cat > .env << 'EOF'
# Multiple API keys for load balancing (comma-separated)
PERPLEXITY_APIS=key1,key2,key3
# OR single API key (backward compatible)
PERPLEXITY_API=your_perplexity_api_key

# Mailjet configuration
MJ_APIKEY_PUBLIC=your_mailjet_public_key
MJ_APIKEY_PRIVATE=your_mailjet_private_key

# Email settings
FROM_EMAIL=sender@yourdomain.com
FROM_NAME=Tech News Digest
TO_EMAIL=recipient@yourdomain.com
EOF

chmod 600 .env
```

4. Create RSS feeds list:
```bash
cat > rss_feeds.txt << 'EOF'
# Technology News
https://www.engadget.com/rss.xml
https://techcrunch.com/feed/
https://arstechnica.com/feed/

# Photography News  
https://www.dpreview.com/feeds/news.xml
https://petapixel.com/feed/
https://fstoppers.com/feed
EOF
```

5. Create the AI prompt:
```bash
cat > prompt.txt << 'EOF'
You are analyzing RSS feed articles from various tech news sources.

Your job is to intelligently categorize each article based on its CONTENT, not its source. A single source can contribute articles to multiple categories.

INSTRUCTIONS:
1. Read through all the RSS feed articles provided below
2. For each article, determine which category it best fits based on its title and description
3. Group articles into the following main categories based on their actual content
4. Prioritize the most newsworthy and interesting articles (limit to 4-6 articles per category)
5. Articles about the same topic from different sources should be mentioned together or the best version chosen

CATEGORY GUIDELINES:

**CONSUMER ELECTRONICS**: 
- Smartphones, tablets, laptops, smart home devices
- Gaming consoles, VR/AR headsets, wearables  
- Product launches, reviews, hardware announcements
- Consumer technology trends and releases

**PHOTOGRAPHY GEAR**:
- Cameras, lenses, photography equipment
- Photography techniques, tutorials, industry news
- Camera reviews, new camera releases
- Photography software and editing tools

**SOFTWARE INDUSTRY**:
- Programming, development tools, frameworks
- Business software, enterprise tech, SaaS
- Tech company news, acquisitions, funding
- AI/ML developments, cybersecurity, data privacy
- App releases, software updates, platform changes

FORMATTING REQUIREMENTS:
- Use exactly this format with 50 dashes above and below each header.
- Then the next line is the title in bold using **bold text** markdown syntax.
- Then the next line is a multi-sentence summary of the articles' contents in regular text.
- Then the next line(s) are the links to the references used to generate the summary.

FORMATTING EXAMPLE:
--------------------------------------------------
CONSUMER ELECTRONICS
--------------------------------------------------
**New iPhone 15 Features Revolutionary Camera System**
Apple has announced the iPhone 15 will include a groundbreaking camera system with improved low-light performance. The device also features a new titanium build and enhanced battery life. Pre-orders begin next Friday with shipping expected in early October.
- https://example.com/iphone15-announcement
- https://example.com/iphone15-camera-review

**Samsung Galaxy Watch 6 Adds Health Monitoring**
Samsung's latest smartwatch introduces advanced sleep tracking and blood glucose monitoring capabilities. The device runs on the company's new Wear OS 4 platform and promises 48-hour battery life. It will be available in three sizes starting at $299.
- https://example.com/galaxy-watch6-features
- https://example.com/samsung-health-tech

ADDITIONAL FORMATTING INSTRUCTIONS:
- Under each section, write a short title using **double asterisks for bold text**
- Follow the title with a 4-6 sentence summary in regular text (no bold formatting)
- Place the full article URLs as bullet points immediately after each summary
- Skip sections entirely if no relevant articles are found
- Prioritize recent, substantial news over minor updates
- Do not put a list of references at the end of your response
- Do not use reference markers like [1] anywhere in your response

CONTENT FILTERING:
- Only include articles that are actually news, not speculation or rumors
- Skip promotional content, sponsored articles, and fluff pieces
- Focus on significant developments, product launches, industry changes

INPUT DATA PARSING:
Each article in the RSS content follows this format:

TITLE: [Article Title]
LINK: [Article URL]  
DESCRIPTION: [Article Summary]
SOURCE: [Source Name]
---

Analyze the content below and create your categorized summary:
EOF

chmod 600 prompt.txt
```

## Configuration

### RSS Feeds (`rss_feeds.txt`)
Edit this file to add/remove RSS feeds. Format: one URL per line, comments start with `#`.

**Supported Categories:**
- Technology news (Engadget, TechCrunch, Ars Technica)
- Photography (DPReview, PetaPixel, Fstoppers)  
- Add any RSS feed - the AI will categorize content automatically

### Environment Variables (`.env`)

**Multiple API Keys (Recommended):**
```bash
PERPLEXITY_APIS=key1,key2,key3,key4        # Comma-separated, no spaces
```

**Single API Key (Backward Compatible):**
```bash
PERPLEXITY_API=your_single_api_key
```

**Required Settings:**
```bash
MJ_APIKEY_PUBLIC=mailjet_public_key         # Mailjet public key
MJ_APIKEY_PRIVATE=mailjet_private_key       # Mailjet private key
FROM_EMAIL=sender@yourdomain.com            # Sender email
FROM_NAME=Tech News Digest                  # Sender name
TO_EMAIL=recipient@yourdomain.com           # Recipient email
```

## Usage

### Run Once
```bash
./perplexity-tech-news.run
```

### Schedule with Cron
```bash
# Edit crontab
crontab -e

# Add line for daily execution at 8 AM
0 8 * * * /path/to/perplexity-tech-news.run >> /path/to/cron.log 2>&1
```

### Monitor Logs
```bash
# Follow real-time logs
tail -f tech_news.log

# Check recent errors
grep -i error tech_news.log | tail -10

# View API key usage
grep -i "selected api key" tech_news.log
```

## How It Works

### 1. Environment & Setup
- Validates API keys and email configuration
- Sets up logging to both file and console
- Creates necessary directories
- Detects single vs. multiple API keys for load balancing

### 2. RSS Feed Processing
- Downloads feeds with proper User-Agent headers
- Validates XML format and content
- Parses using ElementTree with multiple namespace support
- Extracts titles, links, descriptions with robust fallback methods
- Handles CDATA sections and HTML entities properly

### 3. Content Extraction & Validation
- Cleans HTML tags and normalizes text
- Validates that articles have both titles and links
- Skips articles with missing or invalid data
- Logs processing details for debugging

### 4. AI Processing with Load Balancing
- Randomly selects API key from available pool
- Formats RSS content for AI analysis
- Sends to Perplexity API with retry logic
- Handles rate limiting and API errors gracefully

### 5. Email Generation & Delivery
- Converts markdown to HTML for rich formatting
- Creates plain text version for compatibility
- Sends multipart email (HTML + plain text)
- Provides clickable links and proper styling

## Troubleshooting

### Common Issues

**No Articles Found**
```bash
# Check RSS feeds are accessible
curl -I https://www.engadget.com/rss.xml

# Verify script permissions
ls -la perplexity-tech-news.run

# Check for title extraction issues
./perplexity-tech-news.run 2>&1 | grep "title_valid"
```

**API Key Issues**
```bash
# Verify API keys format in .env
cat .env | grep PERPLEXITY

# Test single API key
curl -H "Authorization: Bearer YOUR_KEY" \
     -H "Content-Type: application/json" \
     -d '{"model":"sonar-pro","messages":[{"role":"user","content":"test"}]}' \
     https://api.perplexity.ai/chat/completions
```

**Email Delivery Problems**
```bash
# Check Mailjet credentials
grep MJ_APIKEY .env

# Verify email addresses are valid
grep EMAIL .env
```

**Python Dependencies**
```bash
# Install required packages
pip3 install requests

# Check Python version (needs 3.6+)
python3 --version
```

### Debug Mode
Enable detailed debugging by modifying the logging level in the script:
```python
logging.basicConfig(level=logging.DEBUG, ...)
```

### Testing Components

**Test RSS Download:**
```bash
python3 -c "
import requests
response = requests.get('https://www.engadget.com/rss.xml', timeout=30)
print(f'Status: {response.status_code}, Length: {len(response.text)}')
print(response.text[:200])
"
```

**Test Title Extraction:**
```bash
python3 -c "
import xml.etree.ElementTree as ET
import requests
response = requests.get('https://www.engadget.com/rss.xml')
root = ET.fromstring(response.text)
items = root.findall('.//item')
print(f'Found {len(items)} items')
if items:
    title = items[0].find('title')
    print(f'First title: {title.text if title is not None else "None"}')
"
```

## Features

### Load Balancing
- **Automatic Distribution**: API calls distributed across multiple keys
- **Random Selection**: Each request uses a different key
- **Usage Logging**: Track which keys are being used
- **Graceful Fallback**: Single key mode if only one provided

### Email Formatting
- **HTML Rich Text**: Bold headers, clickable links, proper styling
- **Plain Text Fallback**: Automatic plain text version for compatibility
- **Link Lists**: Clean formatting for reference links
- **Responsive Design**: Proper CSS for various email clients

### RSS Processing
- **Multi-Format Support**: RSS 2.0, Atom, and various custom formats
- **Robust Parsing**: Multiple fallback methods for title/link extraction
- **Content Validation**: Ensures articles have required fields
- **Error Recovery**: Continues processing even if individual feeds fail

### Monitoring & Debugging
- **Comprehensive Logging**: All operations logged with timestamps
- **Debug Information**: Detailed parsing information for troubleshooting
- **Performance Metrics**: Processing time and article counts
- **Error Tracking**: Clear error messages with context

## Performance

- **RSS Crawling**: ~2-5 seconds per feed (with 2s delay between feeds)
- **Content Processing**: ~5-15 seconds depending on article count
- **API Processing**: ~10-30 seconds depending on content volume
- **Email Delivery**: ~2-5 seconds
- **Total Runtime**: Usually 2-4 minutes for 8-10 feeds

## Security

- **API Key Protection**: Keys masked in logs, secure file permissions
- **Data Cleanup**: RSS data automatically purged after 7 days
- **Respectful Crawling**: Proper User-Agent, rate limiting
- **Input Validation**: All URLs and content validated before processing

## Migration Notes

### From Bash Version
The Python version maintains full compatibility with existing `.env` files and configurations. Key improvements:

1. **Better Error Handling**: More robust error recovery
2. **Improved Performance**: Faster processing and fewer dependencies
3. **Enhanced Debugging**: Better logging and troubleshooting
4. **Load Balancing**: Support for multiple API keys
5. **Rich Email**: HTML formatting with fallbacks

### Configuration Changes
- **Multiple API Keys**: Add `PERPLEXITY_APIS=key1,key2,key3` for load balancing
- **Dependencies**: Only requires Python 3.6+ and `requests` package
- **File Structure**: Simpler structure with fewer files

Your existing cron jobs and email settings work without modification.
