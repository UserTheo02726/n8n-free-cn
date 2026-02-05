# ==========================================
# Stage 1: Fetch Chinese localization package
# ==========================================
# 👇 Initially set to latest; script will auto-replace with exact version (e.g., 2.11.0)
FROM blowsnow/n8n-chinese:2.6.3 AS builder

# ==========================================
# Stage 2: Build runtime environment (Alpine)
# ==========================================
# Based on verified Node 24 Alpine
FROM node:24-alpine

# 1. Install system dependencies
# Includes: Python3, FFmpeg, Chromium, Chinese fonts, Tini
RUN apk add --no-cache \
    git \
    python3 \
    py3-pip \
    make \
    g++ \
    build-base \
    cairo-dev \
    pango-dev \
    chromium \
    postgresql-client \
    ffmpeg \
    yt-dlp \
    tini \
    font-noto-cjk

# =========================================================
# 👇 Core config section (infrastructure settings hard-coded here)
# =========================================================

# --- Infrastructure config ---
ENV N8N_PORT=7860 \
    N8N_PROTOCOL=https \
    N8N_PROXY_HOPS=1 \
    N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true \
    N8N_REINSTALL_MISSING_PACKAGES=true

# --- Database type ---
ENV DB_TYPE=postgresdb

# --- Push backend ---
ENV N8N_PUSH_BACKEND=websocket

# --- Puppeteer/Chromium system path (must keep) ---
ENV PUPPETEER_SKIP_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# =========================================================

# 2. Install n8n
# 👇 Initially set to latest; script also watches here to align with above
RUN npm install -g n8n@2.6.3

# 3. Inject Chinese localization package
COPY --from=builder /usr/local/lib/node_modules/n8n/node_modules/n8n-editor-ui/dist /usr/local/lib/node_modules/n8n/node_modules/n8n-editor-ui/dist

# 4. Configure directory permissions
WORKDIR /data
RUN mkdir -p /home/node/.n8n \
    && chown -R node:node /home/node/.n8n \
    && chown -R node:node /data

# 5. Switch user
USER node

# 6. Expose port
EXPOSE 7860

# 7. Start command
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["n8n", "start"]
