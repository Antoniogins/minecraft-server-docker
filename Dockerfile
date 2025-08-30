FROM eclipse-temurin:21-jdk

ARG SERVER_PACK_URL

ENV SERVER_PACK_URL=${SERVER_PACK_URL} \
    SERVER_HOME=/opt/server-dist \
    DATA_DIR=/data \
    BACKUP_DIR=/data/backups

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    jq \
    tzdata \
    unzip \
    wget \
    rsync \
    zip \
    tini \
 && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 -U -d /home/minecraft -s /bin/bash minecraft

RUN mkdir -p ${SERVER_HOME} ${DATA_DIR} /usr/local/bin \
 && chown -R minecraft:minecraft ${SERVER_HOME} ${DATA_DIR}

# Download and unpack ATM10 server pack at build time if URL is provided
RUN if [ -n "${SERVER_PACK_URL}" ]; then \
      echo "Downloading server pack from ${SERVER_PACK_URL}" && \
      wget -O /tmp/pack.zip "${SERVER_PACK_URL}" && \
      unzip -q /tmp/pack.zip -d "${SERVER_HOME}" && \
      rm -f /tmp/pack.zip && \
      if [ -f "${SERVER_HOME}/startserver.sh" ]; then chmod +x "${SERVER_HOME}/startserver.sh"; fi; \
    else \
      echo "SERVER_PACK_URL not provided at build time; you'll need to place files at runtime"; \
    fi

# Copy entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 25565 25575

VOLUME ["${DATA_DIR}"]

WORKDIR ${DATA_DIR}

USER minecraft

ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/usr/local/bin/entrypoint.sh"]


