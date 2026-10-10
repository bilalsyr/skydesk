# SkyDesk — lightweight Ubuntu desktop in the browser, tuned for slow connections
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    TZ=UTC \
    PORT=6080 \
    RESOLUTION=1280x720 \
    DEPTH=24 \
    HOME=/home/ubuntu

RUN apt-get update && apt-get install -y --no-install-recommends \
      xfce4 xfce4-terminal mousepad thunar dbus-x11 x11-xserver-utils xfonts-base \
      tigervnc-standalone-server tigervnc-common tigervnc-tools \
      novnc websockify python3-numpy \
      fonts-noto-core fonts-dejavu-core ca-certificates curl sudo tzdata \
    && apt-get purge -y xfce4-screensaver light-locker 2>/dev/null || true \
    && apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu

COPY index.html /usr/share/novnc/index.html
COPY xfwm4.xml xfce4-desktop.xml /home/ubuntu/.config/xfce4/xfconf/xfce-perchannel-xml/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh && chown -R 1000:1000 /home/ubuntu

USER 1000
WORKDIR /home/ubuntu
EXPOSE 6080

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -fs "http://localhost:${PORT}/" || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
