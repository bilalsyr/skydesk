# SkyDroid stream bridge: adb + patched ws-scrcpy + tiny device api.
FROM node:18-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        android-tools-adb \
        curl \
        unzip \
        git \
        ca-certificates \
        python3 \
        make \
        g++ \
    && rm -rf /var/lib/apt/lists/*

# Build ws-scrcpy (pinned commit) with SkyDroid low-latency patches.
COPY build-ws-scrcpy.sh patch-ws-scrcpy.py /opt/
RUN chmod +x /opt/build-ws-scrcpy.sh \
    && /opt/build-ws-scrcpy.sh \
    && rm -rf /opt/ws-src

# Runtime helpers.
COPY entrypoint.sh api.js install-apk.sh healthcheck.js /opt/
RUN chmod +x /opt/entrypoint.sh /opt/install-apk.sh

ENV ADB_SERIAL=android:5555 \
    WS_SCRCPY_PATHNAME=/s \
    API_PORT=8001

EXPOSE 8000 8001

ENTRYPOINT ["/opt/entrypoint.sh"]
