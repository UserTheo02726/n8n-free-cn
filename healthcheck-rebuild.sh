#!/usr/bin/env bash

# HF_REPO=owner/space
# TG_TOKEN=
# TG_CHAT_ID=
# HF_TOKEN=

for cmd in git curl jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "::error::This script requires '$cmd' but it's not installed. Aborting." >&2
        exit 1
    fi
done

export PATH=$PATH:/usr/bin

if [ -z "$HF_REPO" ]; then
    echo "::error::HF_REPO is not set" >&2
    exit 1
fi

if ! echo "$HF_REPO" | grep -q "/"; then
    echo "::error::HF_REPO must be in owner/space format" >&2
    exit 1
fi

if [ -z "$HF_TOKEN" ]; then
    echo "::error::HF_TOKEN is not set" >&2
    exit 1
fi

owner=${HF_REPO%%/*}
space=${HF_REPO#*/}
N8N_HOST="${owner}-${space}.hf.space"

notify() {
    # --- Telegram 通道 ---
    if [ ! -z "$TG_TOKEN" ]; then
        curl -X POST \
            -H "Content-Type: application/json" \
            -d "{\"chat_id\": \"$TG_CHAT_ID\", \"text\": \"🚨 警告：检测到服务异常，正在触发重启。\n目标空间: https://huggingface.co/spaces/$HF_REPO\", \"disable_notification\": false}" \
            "https://api.telegram.org/bot$TG_TOKEN/sendMessage"
    fi

    # --- Bark 通道 ---
    if [ ! -z "$BARK_KEY" ]; then
        curl -s \
            "https://api.day.app/$BARK_KEY/N8n报警/🚨检测到服务异常，正在触发重启-$HF_REPO" \
            > /dev/null
    fi
}

rebuild() {
    git reset --hard HEAD
    git pull --force
    date >rebuild.txt
    git add rebuild.txt
    git commit -m "rebuild"
    git push
    owner=${HF_REPO%%/*}
    git remote add space "https://${owner}:${HF_TOKEN}@huggingface.co/spaces/${HF_REPO}"
    git push space main --force
    notify
}

# Make the request and capture the body and status code in variables
http_response=$(curl -s -w "\n%{http_code}" "https://$N8N_HOST/healthz/readiness")
http_body=$(echo "$http_response" | sed '$d')
http_status=$(echo "$http_response" | tail -n1)

echo "http_body: $http_body"
echo "http_status: $http_status"

# Check the HTTP status code
if [ "$http_status" -ne 200 ]; then
    echo "::error::Health check failed with status code $http_status"
    echo "Response body: $http_body"
    rebuild
    exit 1
fi

# Parse the JSON response and check the status field
response_status=$(echo "$http_body" | jq -r '.status')

if [ "$response_status" != "ok" ]; then
    echo "::error::Health check failed. Expected status 'ok', but got '$response_status'"
    echo "Response body: $http_body"
    rebuild
    exit 1
fi

echo "Health check successful!"
