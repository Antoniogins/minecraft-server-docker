FROM eclipse-temurin:21-jdk

ENV DATA_DIR=/data

# Paquetes mínimos para descarga y copia
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl unzip rsync \
 && rm -rf /var/lib/apt/lists/*

# Usuario no root para ejecutar el servidor
RUN useradd -m -U -d /home/minecraft -s /bin/bash minecraft \
 && mkdir -p "$DATA_DIR" \
 && chown -R minecraft:minecraft "$DATA_DIR"

# Descargar y descomprimir el pack en tiempo de build (caché de capas)
ARG SERVER_PACK_URL=https://mediafilez.forgecdn.net/files/6921/537/ServerFiles-4.10.zip
RUN curl -L -o /tmp/pack.zip "$SERVER_PACK_URL" \
 && unzip -q /tmp/pack.zip -d "$DATA_DIR" \
 && rm -f /tmp/pack.zip \
 && chown -R minecraft:minecraft "$DATA_DIR"

# Sin entrypoint personalizado; el contenedor arrancará idle por ahora

VOLUME ["/data"]
WORKDIR /data

EXPOSE 25565 25575

USER minecraft
CMD ["sleep", "infinity"]
