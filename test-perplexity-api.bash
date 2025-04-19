#!/usr/bin/env bash

set -a; source ./.env; set +a
echo "$PROMPT_TEXT"

curl -Ss \
    -H "Authorization: Bearer $PERPLEXITY_API" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg prompt "$PROMPT_TEXT" '{model:"sonar-pro",messages:[{role:"system",content:"You are a tech analyst"},{role:"user",content:$prompt}]}')" \
    https://api.perplexity.ai/chat/completions | jq
