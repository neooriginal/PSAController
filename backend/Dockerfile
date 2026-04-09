FROM node:22-bookworm-slim

WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends openssl python3 python3-pip \
  && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
RUN npm ci --omit=dev

COPY src ./src
COPY psa_bridge ./psa_bridge

RUN python3 -m pip install --break-system-packages --no-cache-dir -r /app/psa_bridge/requirements.txt

ENV HOST=0.0.0.0
ENV PORT=8787
ENV DB_PATH=/data/data.sqlite3
ENV PSA_BRIDGE_HOME=/data/psa-runtime

EXPOSE 8787

CMD ["node", "src/server.js"]
