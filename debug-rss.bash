#!/usr/bin/env bash

set -e

echo "=== RSS Feed Tester ==="
echo

test_feed() {
    local url="$1"
    echo "Testing: $url"
    
    # Download feed
    local temp_file=$(mktemp)
    if curl -sS -L -m 30 -A "RSS-Crawler/1.0" -o "$temp_file" "$url"; then
        echo "✓ Downloaded ($(wc -c < "$temp_file") bytes)"
        
        # Test with Python
        python3 << EOF
import xml.etree.ElementTree as ET
import re
from html import unescape

def clean_text(text):
    if not text: return ""
    text = re.sub(r'<!\[CDATA\[(.*?)\]\]>', r'\1', text, flags=re.DOTALL)
    text = re.sub(r'<[^>]+>', '', text)
    text = unescape(text).strip()
    return text[:50] + "..." if len(text) > 50 else text

try:
    tree = ET.parse("$temp_file")
    root = tree.getroot()
    items = root.findall('.//item') or root.findall('.//{http://www.w3.org/2005/Atom}entry')
    
    print(f"✓ Found {len(items)} items")
    
    for i, item in enumerate(items[:2]):
        title_elem = item.find('title') or item.find('.//{http://www.w3.org/2005/Atom}title')
        title = clean_text(title_elem.text if title_elem is not None else "")
        
        link_elem = item.find('link')
        link = ""
        if link_elem is not None:
            if link_elem.text and link_elem.text.strip():
                link = clean_text(link_elem.text)
            elif 'href' in link_elem.attrib:
                link = link_elem.attrib['href']
        
        if not link:
            guid_elem = item.find('guid')
            if guid_elem is not None and guid_elem.text:
                link = clean_text(guid_elem.text)
        
        print(f"  Item {i+1}: {title[:30]}...")
        print(f"    Link: {link[:60]}...")

except Exception as e:
    print(f"✗ Parse error: {e}")
EOF
        
        rm -f "$temp_file"
    else
        echo "✗ Download failed"
    fi
    echo ""
}

# Test key feeds
feeds=(
    "https://www.engadget.com/rss.xml"
    "https://gizmodo.com/feed"
    "https://techcrunch.com/feed/"
    "https://arstechnica.com/feed/"
)

for feed in "${feeds[@]}"; do
    test_feed "$feed"
done

echo "=== Testing Complete ==="
