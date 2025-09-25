FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:0 \
    WINEARCH=win64 \
    WINEPREFIX=/opt/wine64

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      software-properties-common \
      xvfb x11vnc supervisor wget unzip cabextract winbind \
      python3 python3-pip \
      novnc websockify \
      fluxbox \
      winetricks \
 && rm -rf /var/lib/apt/lists/*

RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends wine64 wine32 \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/wine64 /srv/botdata /opt/mt5

RUN wget -O /tmp/corefonts.exe "https://downloads.sourceforge.net/corefonts/arial32.exe" \
 && cabextract -d /tmp/corefonts /tmp/corefonts.exe \
 && rm -f /tmp/corefonts.exe

RUN wget -O /tmp/mt5setup.exe "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"

COPY run.sh /usr/local/bin/run-mt5.sh
RUN chmod +x /usr/local/bin/run-mt5.sh

EXPOSE 6080

CMD ["/usr/local/bin/run-mt5.sh"]
