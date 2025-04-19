#!/usr/bin/env bash
# perplexity-tech-news.sh

set -eo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
LOG_FILE="$SCRIPT_DIR/tech_news.log"
MAX_RETRIES=3
RETRY_DELAY=10

# --- Initialize Logging ---
exec 3>&1 4>&2  # Save original stdout/stderr
trap 'exec 1>&3 2>&4' EXIT  # Restore on exit
exec > >(tee -a "$LOG_FILE") 2>&1  # Redirect all output to log

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# --- Environment Management ---
load_environment() {
    log "Loading environment from: $ENV_FILE"
    
    if [[ ! -f "$ENV_FILE" ]]; then
        log "Error: .env file not found"
        exit 1
    fi

    if [[ "$(stat -c %a "$ENV_FILE")" != "600" ]]; then
        log "Insecure .env file permissions (should be 600)"
        exit 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        line="${line#export }"
        key=$(echo "$line" | cut -d= -f1)
        value=$(echo "$line" | cut -d= -f2-)
        value="${value%\"}"
        value="${value#\"}"
        export "$key"="$value"
    done < "$ENV_FILE"

    log "Environment loaded successfully"
}

validate_environment() {
    declare -a REQUIRED_VARS=(
        PERPLEXITY_API
        SENDGRID_API
        FROM_EMAIL
        FROM_NAME
        SENDGRID_TO_EMAIL
        PROMPT_TEXT
    )

    for var in "${REQUIRED_VARS[@]}"; do
        if [[ -z "${!var}" ]]; then
            log "Error: $var not set in environment"
            exit 1
        fi
    done

    log "Environment validation passed"
    log "PERPLEXITY_API: ${PERPLEXITY_API:0:4}******"
    log "SENDGRID_API: ${SENDGRID_API:0:4}******"
    log "PROMPT_TEXT: ${PROMPT_TEXT:0:80}..."
}

# --- API Functions ---
query_perplexity() {
    local retry_count=0
    local temp_file response http_status json_content
    
    until [[ $retry_count -ge $MAX_RETRIES ]]; do
        temp_file=$(mktemp)
        
        log "API Attempt $((retry_count+1))/$MAX_RETRIES"
        
        curl -sS \
            -w "\nHTTP_STATUS:%{http_code}" \
            -H "Authorization: Bearer $PERPLEXITY_API" \
            -H "Content-Type: application/json" \
            -d "$(jq -n \
                --arg content "$PROMPT_TEXT" \
                '{
                    "model": "sonar-pro",
                    "messages": [
                        {
                            "role": "system",
                            "content": "You are a senior technology analyst producing comprehensive daily briefings."
                        },
                        {
                            "role": "user",
                            "content": $content
                        }
                    ]
                }')" \
            https://api.perplexity.ai/chat/completions > "$temp_file"

        http_status=$(grep 'HTTP_STATUS' "$temp_file" | cut -d':' -f2)
        json_content=$(grep -v 'HTTP_STATUS' "$temp_file" | tr -d '\r')

        log "Response status: $http_status"
        log "Response length: ${#json_content} chars"

        if [[ "$http_status" -eq 200 ]]; then
            if jq -e '.choices[0].message.content' <<< "$json_content" &>/dev/null; then
                echo "$json_content"  # Output to original stdout (FD 3)
                rm -f "$temp_file"
                return 0
            else
                log "Invalid JSON structure in successful response"
            fi
        fi

        log "Raw response: $(cat "$temp_file")"
        rm -f "$temp_file"
        ((retry_count++))
        sleep $RETRY_DELAY
    done

    log "Failed after $MAX_RETRIES attempts"
    return 1
}

# --- Email Sending ---
send_email() {
    local content="$1"
    local payload response http_status
    
    payload=$(jq -n \
        --arg to "$SENDGRID_TO_EMAIL" \
        --arg from "$FROM_EMAIL" \
        --arg name "$FROM_NAME" \
        --arg subj "Tech News Digest - $(date +'%Y-%m-%d')" \
        --arg content "$content" \
        '{
            "personalizations": [{"to": [{"email": $to}]}],
            "from": {"email": $from, "name": $name},
            "subject": $subj,
            "content": [{"type": "text/plain", "value": $content}],
            "tracking_settings": {
                "click_tracking": { "enable": false },
                "open_tracking": { "enable": false }
            }
        }')

    response=$(curl -sS \
        -w "\nHTTP_STATUS:%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $SENDGRID_API" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        https://api.sendgrid.com/v3/mail/send)

    http_status=$(echo "$response" | grep 'HTTP_STATUS' | cut -d':' -f2)
    
    if [[ "$http_status" -ne 202 ]]; then
        log "SendGrid Error: $http_status - $(echo "$response" | grep -v HTTP_STATUS)"
        return 1
    fi

    return 0
}

# --- Main Execution ---
main() {
    log "=== Tech News Digest Startup ==="
    
    load_environment
    validate_environment

    for cmd in curl jq; do
        if ! command -v $cmd &>/dev/null; then
            log "Error: $cmd not found"
            exit 1
        fi
    done

    local api_response
    api_response=$(query_perplexity 3>&1)  # Capture from FD 3
    
    if [[ -z "$api_response" ]]; then
        log "Critical error: Empty API response"
        exit 1
    fi

    local news_content=$(jq -r '.choices[0].message.content' <<< "$api_response")
    
    if [[ -z "$news_content" || "$news_content" == "null" ]]; then
        log "Error: Invalid news content received"
        exit 1
    fi

    log "Successfully received news content (${#news_content} chars)"

    if ! send_email "$news_content"; then
        log "Failed to send email"
        exit 1
    fi

    log "=== Digest sent to $SENDGRID_TO_EMAIL ==="
}

main "$@"
