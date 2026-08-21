FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        curl \
        iproute2 \
        kmod \
        systemd \
        systemd-sysv \
    && rm -rf /var/lib/apt/lists/*

RUN userdel -r ubuntu 2>/dev/null || true \
    && useradd -m -s /bin/bash -u 1000 testuser

COPY bloodhound /opt/bloodhound/bloodhound
COPY bloodhound-ready /usr/local/libexec/bloodhound-ready
COPY bloodhound.service /etc/systemd/system/bloodhound.service
COPY bloodhound-ready.service /etc/systemd/system/bloodhound-ready.service
COPY journald-console.conf /etc/systemd/journald.conf.d/console.conf

RUN chmod 0755 /opt/bloodhound/bloodhound /usr/local/libexec/bloodhound-ready \
    && mkdir -p /var/log/journal \
    && systemctl set-default multi-user.target \
    && systemctl enable bloodhound.service bloodhound-ready.service

STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
