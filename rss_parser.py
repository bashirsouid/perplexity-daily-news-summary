#!/usr/bin/env python3
"""
Standalone RSS Parser for Tech News Script
Usage: python3 rss_parser.py <feed_url> <category> [max_age_hours]
"""

import sys
import urllib.request
import xml.etree.ElementTree as ET
import re
from html import unescape
from datetime import datetime, timezone, timedelta
import json

def clean_text(text):
    """Clean and normalize text content"""
    if not text:
        return ""
    
    # Remove CDATA wrappers
    text = re.sub(r'<!\[CDATA\[(.*?)\]\]>', r'\1', text, flags=re.DOTALL)
    
    # Remove HTML tags
    text = re.sub(r'<[^>]+>', '', text)
    
    # Decode HTML entities
    text = unescape(text)
    
    # Clean up whitespace
    text = ' '.join(text.split())
    
    # Limit length
    return text[:500] if len(text) > 500 else text

def extract_link(item):
    """Extract link from RSS item using multiple methods"""
    
    # Method 1: Standard link element
    link_elem = item.find('link')
    if link_elem is not None and link_elem.text:
        link = link_elem.text.strip()
        # Remove CDATA if present
        link = re.sub(r'<!\[CDATA\[(.*?)\]\]>', r'\1', link)
        if link.startswith('http'):
            return link
    
    # Method 2: GUID that looks like a URL
    guid_elem = item.find('guid')
    if guid_elem is not None and guid_elem.text:
        guid = guid_elem.text.strip()
        guid = re.sub(r'<!\[CDATA\[(.*?)\]\]>', r'\1', guid)
        if guid.startswith('http'):
            return guid
    
    # Method 3: Search for any URL in the item XML
    item_text = ET.tostring(item, encoding='unicode')
    url_matches = re.findall(r'https?://[^\s<>"\[\]]+', item_text)
    if url_matches:
        # Return the first URL that doesn't look like an image
        for url in url_matches:
            if not re.search(r'\.(jpg|jpeg|png|gif|webp)($|\?)', url, re.IGNORECASE):
                return url
        # If no non-image URLs, return the first URL
        return url_matches[0]
    
    return ""

def parse_date(date_str):
    """Parse various date formats"""
    if not date_str:
        return None
    
    # Common RSS date formats
    formats = [
        '%a, %d %b %Y %H:%M:%S %z',
        '%a, %d %b %Y %H:%M:%S %Z',
        '%Y-%m-%dT%H:%M:%S%z',
        '%Y-%m-%dT%H:%M:%SZ',
        '%Y-%m-%d %H:%M:%S',
        '%a, %d %b %Y %H:%M:%S'
    ]
    
    for fmt in formats:
        try:
            return datetime.strptime(date_str.strip(), fmt)
        except ValueError:
            continue
    
    return None

def download_feed(url):
    """Download RSS feed with proper headers"""
    try:
        req = urllib.request.Request(
            url,
            headers={'User-Agent': 'RSS-Crawler/1.0'}
        )
        with urllib.request.urlopen(req, timeout=30) as response:
            return response.read().decode('utf-8', errors='ignore')
    except Exception as e:
        print(f"Error downloading {url}: {e}", file=sys.stderr)
        return None

def parse_rss_content(content, category, max_age_hours=48):
    """Parse RSS content and extract items"""
    try:
        # Try to parse as XML
        root = ET.fromstring(content)
        
        # Handle both RSS and Atom feeds
        items = (root.findall('.//item') or 
                root.findall('.//{http://www.w3.org/2005/Atom}entry') or
                root.findall('.//entry'))
        
        if not items:
            print(f"No items found in feed", file=sys.stderr)
            return []
        
        # Calculate cutoff time
        cutoff_time = datetime.now(timezone.utc) - timedelta(hours=max_age_hours)
        
        parsed_items = []
        for item in items:
            # Extract title
            title_elem = (item.find('title') or 
                         item.find('.//{http://www.w3.org/2005/Atom}title'))
            title = clean_text(title_elem.text if title_elem is not None else "")
            
            # Extract link
            link = extract_link(item)
            
            # Extract description
            desc_elem = (item.find('description') or 
                        item.find('summary') or 
                        item.find('.//{http://www.w3.org/2005/Atom}summary') or
                        item.find('.//{http://www.w3.org/2005/Atom}content'))
            description = clean_text(desc_elem.text if desc_elem is not None else "")
            
            # Extract date
            date_elem = (item.find('pubDate') or 
                        item.find('.//{http://www.w3.org/2005/Atom}published') or
                        item.find('.//{http://www.w3.org/2005/Atom}updated'))
            pub_date_str = date_elem.text if date_elem is not None else ""
            
            # Skip items without title or link
            if not title or not link:
                continue
            
            # Check date (if available and parseable)
            if pub_date_str:
                pub_date = parse_date(pub_date_str)
                if pub_date:
                    # Make timezone-aware if not already
                    if pub_date.tzinfo is None:
                        pub_date = pub_date.replace(tzinfo=timezone.utc)
                    
                    if pub_date < cutoff_time:
                        continue
            
            parsed_items.append({
                'title': title,
                'link': link,
                'description': description,
                'category': category,
                'pub_date': pub_date_str
            })
        
        return parsed_items
        
    except ET.ParseError as e:
        print(f"XML Parse Error: {e}", file=sys.stderr)
        return []
    except Exception as e:
        print(f"Parsing Error: {e}", file=sys.stderr)
        return []

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 rss_parser.py <feed_url> <category> [max_age_hours]")
        sys.exit(1)
    
    feed_url = sys.argv[1]
    category = sys.argv[2]
    max_age_hours = int(sys.argv[3]) if len(sys.argv) > 3 else 48
    
    # Download feed
    content = download_feed(feed_url)
    if not content:
        sys.exit(1)
    
    # Parse feed
    items = parse_rss_content(content, category, max_age_hours)
    
    # Output items in the expected format
    for item in items:
        print(f"TITLE: {item['title']}")
        print(f"LINK: {item['link']}")
        print(f"DESCRIPTION: {item['description']}")
        print(f"CATEGORY: {item['category']}")
        print("---")
    
    print(f"# Extracted {len(items)} items from {feed_url}", file=sys.stderr)

if __name__ == "__main__":
    main()
