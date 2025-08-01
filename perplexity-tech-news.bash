#!/usr/bin/env bash
set -eo pipefail

# --- Configuration ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
PROMPT_FILE="$SCRIPT_DIR/prompt.txt"
RSS_FEEDS_FILE="$SCRIPT_DIR/rss_feeds.txt"
RSS_DATA_DIR="$SCRIPT_DIR/rss_data"
LOG_FILE="$SCRIPT_DIR/tech_news.log"
MAX_RETRIES=3
RETRY_DELAY=10

# --- Initialize Logging ---

exec 3>&1 4>&2
trap 'exec 1>&3 2>&4' EXIT
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# --- Environment Management ---

load_environment() {
    log "Loading environment from: $ENV_FILE"
    [[ ! -f "$ENV_FILE" ]] && { log ".env file missing"; exit 1; }
    [[ "$(stat -c %a "$ENV_FILE")" != "600" ]] && { log "Insecure .env permissions"; exit 1; }
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        line="${line#export }"
        key=$(echo "$line" | cut -d= -f1)
        value=$(echo "$line" | cut -d= -f2-)
        value="${value%\"}"
        value="${value#\"}"
        export "$key"="$value"
    done < "$ENV_FILE"
}

validate_environment() {
    [[ ! -f "$PROMPT_FILE" ]] && { log "Error: Missing prompt.txt"; exit 1; }
    [[ ! -f "$RSS_FEEDS_FILE" ]] && { log "Error: Missing rss_feeds.txt"; exit 1; }
    [[ "$(stat -c %a "$PROMPT_FILE")" != "600" ]] && { log "Insecure prompt.txt permissions"; exit 1; }
    
    declare -a REQUIRED_VARS=(
        PERPLEXITY_API
        MJ_APIKEY_PUBLIC
        MJ_APIKEY_PRIVATE
        FROM_EMAIL
        FROM_NAME
        TO_EMAIL
    )
    
    for var in "${REQUIRED_VARS[@]}"; do
        [[ -z "${!var}" ]] && { log "Error: $var not set"; exit 1; }
    done
    
    log "Environment validation passed"
    log "PERPLEXITY_API: ${PERPLEXITY_API:0:4}******"
    log "MJ_APIKEY_PUBLIC: ${MJ_APIKEY_PUBLIC:0:4}******"
}

# --- RSS Functions ---

setup_rss_directory() {
    [[ ! -d "$RSS_DATA_DIR" ]] && mkdir -p "$RSS_DATA_DIR"
    log "RSS data directory: $RSS_DATA_DIR"
}

download_rss_feed() {
    local feed_url="$1"
    local feed_filename="$2"
    local feed_path="$RSS_DATA_DIR/$feed_filename"
    
    log "Downloading feed: $feed_url"
    
    if curl -sS -L -m 30 -A "RSS-Crawler/1.0" -o "$feed_path" "$feed_url"; then
        if grep -q "<?xml\|<rss\|<feed" "$feed_path" 2>/dev/null; then
            log "Successfully downloaded: $feed_filename ($(wc -c < "$feed_path") bytes)"
            return 0
        else
            log "Downloaded file is not valid XML/RSS: $feed_filename"
            rm -f "$feed_path"
            return 1
        fi
    else
        log "Failed to download: $feed_url"
        return 1
    fi
}

# Parse RSS feed
parse_rss_feed() {
    local feed_path="$1"
    local feed_source="$2"
    
    log "Parsing feed: $(basename "$feed_path") from source: $feed_source"
    
    # Create a temporary Python script
    local python_script="$RSS_DATA_DIR/temp_parser.py"
    
    cat > "$python_script" << 'EOF'
import xml.etree.ElementTree as ET
import re
import sys
from html import unescape
from urllib.parse import urlparse

def clean_text(text):
    if not text:
        return ""
    # Remove CDATA
    text = re.sub(r'<!\[CDATA\[(.*?)\]\]>', r'\1', text, flags=re.DOTALL)
    # Remove HTML tags
    text = re.sub(r'<[^>]+>', '', text)
    # Decode HTML entities
    text = unescape(text)
    # Clean whitespace
    text = ' '.join(text.split())
    return text[:400]  # Good length for AI analysis

def extract_link(item):
    # Try link element
    link_elem = item.find('link')
    if link_elem is not None:
        if link_elem.text and link_elem.text.strip():
            link = link_elem.text.strip()
            # Clean CDATA if present
            link = re.sub(r'<!\[CDATA\[(.*?)\]\]>', r'\1', link)
            if link.startswith('http'):
                return link
        
        # Try href attribute (Atom feeds)
        if 'href' in link_elem.attrib:
            return link_elem.attrib['href']
    
    # Try guid
    guid_elem = item.find('guid')
    if guid_elem is not None and guid_elem.text:
        guid = guid_elem.text.strip()
        guid = re.sub(r'<!\[CDATA\[(.*?)\]\]>', r'\1', guid)
        if guid.startswith('http'):
            return guid
    
    # Search in the full item XML
    item_xml = ET.tostring(item, encoding='unicode')
    urls = re.findall(r'https?://[^\s<>"\'\]+', item_xml)
    for url in urls:
        # Skip image URLs
        if not re.search(r'\.(jpg|jpeg|png|gif|webp)(\?|$)', url, re.IGNORECASE):
            return url
    
    return ""

def get_source_name(feed_source):
    try:
        domain = urlparse(feed_source).netloc
        domain = domain.replace('www.', '')
        return domain.split('.')[0].title()
    except:
        return "Unknown"

try:
    feed_file = sys.argv[1]
    feed_source = sys.argv[2]
    
    tree = ET.parse(feed_file)
    root = tree.getroot()
    
    # Find items (RSS) or entries (Atom)
    items = root.findall('.//item')
    if not items:
        items = root.findall('.//{http://www.w3.org/2005/Atom}entry')
    if not items:
        items = root.findall('.//entry')
    
    source_name = get_source_name(feed_source)
    count = 0
    
    # Take 15 items per feed - good balance
    for item in items[:15]:
        # Extract title
        title_elem = item.find('title')
        if title_elem is None:
            title_elem = item.find('.//{http://www.w3.org/2005/Atom}title')
        
        title = clean_text(title_elem.text if title_elem is not None else "")
        
        # Extract link
        link = extract_link(item)
        
        # Extract description
        desc_elem = item.find('description')
        if desc_elem is None:
            desc_elem = item.find('summary')
        if desc_elem is None:
            desc_elem = item.find('.//{http://www.w3.org/2005/Atom}summary')
        if desc_elem is None:
            desc_elem = item.find('.//{http://www.w3.org/2005/Atom}content')
        
        description = clean_text(desc_elem.text if desc_elem is not None else "")
        
        # Only output if we have both title and link
        if title and link and link.startswith('http'):
            print(f"TITLE: {title}")
            print(f"LINK: {link}")
            print(f"DESCRIPTION: {description}")
            print(f"SOURCE: {source_name}")
            print("---")
            count += 1
    
    print(f"# Parsed {count} items from {source_name}", file=sys.stderr)

except Exception as e:
    print(f"Error parsing RSS: {e}", file=sys.stderr)
EOF
    
    # Run the Python parser
    if command -v python3 &>/dev/null; then
        python3 "$python_script" "$feed_path" "$feed_source" 2>>"$LOG_FILE"
    else
        log "Python3 not available, skipping feed"
    fi
    
    # Clean up
    rm -f "$python_script"
    
    log "Extracted items from $(basename "$feed_path")"
    return 0
}

crawl_all_feeds() {
    setup_rss_directory
    local consolidated_file="$RSS_DATA_DIR/consolidated_news.txt"
    
    > "$consolidated_file"
    log "Starting RSS feed crawling (smart categorization mode)..."
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        
        local feed_url="$line"
        local feed_filename=$(basename "$feed_url" | sed 's/[^a-zA-Z0-9._/-]/_/g')
        
        if download_rss_feed "$feed_url" "$feed_filename"; then
            parse_rss_feed "$RSS_DATA_DIR/$feed_filename" "$feed_url" >> "$consolidated_file"
        fi
        
        sleep 2
        
    done < "$RSS_FEEDS_FILE"
    
    local item_count=$(grep -c "^TITLE:" "$consolidated_file" 2>/dev/null || echo "0")
    log "RSS crawling completed. Found $item_count articles (AI will categorize them)."
    
    echo "$consolidated_file"
}

# --- API Functions using Python (no command-line limits) ---

query_perplexity() {
    local rss_content_file="$1"
    
    log "Calling Perplexity API using Python (avoids command-line limits)"
    
    # Create Python script to handle API call
    local api_script="$RSS_DATA_DIR/api_caller.py"
    
    cat > "$api_script" << 'EOF'
#!/usr/bin/env python3
import json
import sys
import os
import requests
import time

def call_perplexity_api(prompt_content, rss_content, api_key, max_retries=3, retry_delay=10):
    url = "https://api.perplexity.ai/chat/completions"
    
    # Combine prompt and RSS content
    complete_prompt = f"{prompt_content}\n\nRSS FEED CONTENT:\n{rss_content}"
    
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    
    payload = {
        "model": "sonar-pro",
        "messages": [
            {
                "role": "system",
                "content": "You are a senior technology analyst who excels at categorizing tech news articles by their actual content, regardless of source."
            },
            {
                "role": "user",
                "content": complete_prompt
            }
        ]
    }
    
    for attempt in range(max_retries):
        try:
            print(f"API Attempt {attempt + 1}/{max_retries}", file=sys.stderr)
            
            response = requests.post(url, headers=headers, json=payload, timeout=60)
            
            print(f"HTTP Status: {response.status_code}", file=sys.stderr)
            
            if response.status_code == 200:
                result = response.json()
                if 'choices' in result and len(result['choices']) > 0:
                    content = result['choices'][0]['message']['content']
                    print(f"Success: Content received ({len(content)} chars)", file=sys.stderr)
                    return content
                else:
                    print("Error: No choices in response", file=sys.stderr)
            else:
                print(f"Error response: {response.text}", file=sys.stderr)
                
        except Exception as e:
            print(f"Request failed: {e}", file=sys.stderr)
        
        if attempt < max_retries - 1:
            print(f"Retrying in {retry_delay} seconds...", file=sys.stderr)
            time.sleep(retry_delay)
    
    return None

def main():
    # Get environment variables
    api_key = os.environ.get('PERPLEXITY_API')
    if not api_key:
        print("Error: PERPLEXITY_API environment variable not set", file=sys.stderr)
        sys.exit(1)
    
    # Read prompt file
    try:
        with open(sys.argv[1], 'r') as f:
            prompt_content = f.read()
    except Exception as e:
        print(f"Error reading prompt file: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Read RSS content file
    try:
        with open(sys.argv[2], 'r') as f:
            rss_content = f.read()
    except Exception as e:
        print(f"Error reading RSS content file: {e}", file=sys.stderr)
        sys.exit(1)
    
    print(f"Loaded prompt ({len(prompt_content)} chars) and RSS content ({len(rss_content)} chars)", file=sys.stderr)
    
    # Call API
    result = call_perplexity_api(prompt_content, rss_content, api_key)
    
    if result:
        print(result)  # Output the result to stdout
        sys.exit(0)
    else:
        print("API call failed after all retries", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 api_caller.py <prompt_file> <rss_content_file>", file=sys.stderr)
        sys.exit(1)
    main()
EOF
    
    # Install requests if needed
    if ! python3 -c "import requests" 2>/dev/null; then
        log "Installing requests module..."
        pip3 install requests 2>/dev/null || {
            log "Warning: Could not install requests. API call may fail."
        }
    fi
    
    # Call the Python API script
    local result
    if result=$(python3 "$api_script" "$PROMPT_FILE" "$rss_content_file" 2>>"$LOG_FILE"); then
        echo "$result"
        rm -f "$api_script"
        return 0
    else
        log "Python API call failed"
        rm -f "$api_script"
        return 1
    fi
}

# --- Email Sending ---

send_email() {
    local content="$1"
    local payload response http_status
    
    payload=$(jq -n \
        --arg to "$TO_EMAIL" \
        --arg from "$FROM_EMAIL" \
        --arg name "$FROM_NAME" \
        --arg subj "Tech News Digest - $(date +'%Y-%m-%d')" \
        --arg content "$content" \
        '{
            "Messages": [
                {
                    "From": {
                        "Email": $from,
                        "Name": $name
                    },
                    "To": [
                        {
                            "Email": $to
                        }
                    ],
                    "Subject": $subj,
                    "TextPart": $content
                }
            ]
        }')
    
    response=$(curl -sS \
        -w "\nHTTP_STATUS:%{http_code}" \
        -X POST \
        --user "$MJ_APIKEY_PUBLIC:$MJ_APIKEY_PRIVATE" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        https://api.mailjet.com/v3.1/send)
    
    http_status=$(echo "$response" | grep 'HTTP_STATUS' | cut -d':' -f2)
    
    if [[ "$http_status" -ne 200 ]]; then
        log "Mailjet Error: $http_status - $(echo "$response" | grep -v HTTP_STATUS)"
        return 1
    fi
    
    return 0
}

# --- Cleanup ---

cleanup_rss_data() {
    find "$RSS_DATA_DIR" -type f -mtime +7 -delete 2>/dev/null || true
    log "Cleaned up old RSS data files"
}

# --- Main ---

main() {
    log "=== Startup ==="
    
    load_environment
    validate_environment
    
    for cmd in curl jq python3; do
        if ! command -v $cmd &>/dev/null; then
            log "Error: $cmd not found"
            exit 1
        fi
    done
    
    local rss_content_file
    rss_content_file=$(crawl_all_feeds) || { log "RSS crawling failed"; exit 1; }
    
    local news_content
    news_content=$(query_perplexity "$rss_content_file") || { log "API failed"; exit 1; }
    
    if [[ -z "$news_content" ]]; then
        log "Empty content received"
        exit 1
    fi
    
    log "Content received (${#news_content} chars)"
    
    if ! send_email "$news_content"; then
        log "Failed to send email"
        exit 1
    fi
    
    cleanup_rss_data
    log "=== Success ==="
}

main "$@"
