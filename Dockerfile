FROM blowsnow/n8n-chinese:latest

USER root

RUN if command -v apk > /dev/null; then apk add --no-cache python3 py3-pip; else apt-get update && apt-get install -y python3 python3-pip; fi

USER node
