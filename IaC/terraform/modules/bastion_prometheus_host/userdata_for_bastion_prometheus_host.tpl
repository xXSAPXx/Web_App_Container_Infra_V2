#!/bin/bash

# Install MySQL Client: (Connect to the DB)
sudo dnf install -y mysql

# Install node_exporter - exposes this host's metrics on :9100 for the
# in-cluster Prometheus to scrape via EC2 Service Discovery (see
# prometheus.prometheusSpec.additionalScrapeConfigs in
# ../../values/kube-prometheus-stack.yaml). Runs as its own unprivileged
# system user, not root.
NODE_EXPORTER_VERSION="1.8.2"
useradd --no-create-home --shell /usr/sbin/nologin node_exporter
curl -sL "https://github.com/prometheus/node_exporter/releases/download/v$${NODE_EXPORTER_VERSION}/node_exporter-$${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz" -o /tmp/node_exporter.tar.gz
tar xzf /tmp/node_exporter.tar.gz -C /tmp
mv "/tmp/node_exporter-$${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter" /usr/local/bin/node_exporter
chown node_exporter:node_exporter /usr/local/bin/node_exporter
rm -rf /tmp/node_exporter.tar.gz "/tmp/node_exporter-$${NODE_EXPORTER_VERSION}.linux-amd64"

cat <<'UNIT' > /etc/systemd/system/node_exporter.service
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now node_exporter
