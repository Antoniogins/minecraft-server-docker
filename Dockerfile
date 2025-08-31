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

# Descargar el pack en tiempo de build (se deja cacheado en la imagen)
ARG SERVER_PACK_URL=https://mediafilez.forgecdn.net/files/6921/537/ServerFiles-4.10.zip
RUN mkdir -p /opt/server \
 && curl -L -o /opt/server/pack.zip "$SERVER_PACK_URL" \
 && chown -R minecraft:minecraft /opt/server

VOLUME ["/data"]

# Copiar entrypoint que inicializa el volumen en tiempo de arranque
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /data

EXPOSE 25565 25575

# Ejecutar entrypoint como root para poder inicializar el volumen; luego baja privilegios
USER root
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
