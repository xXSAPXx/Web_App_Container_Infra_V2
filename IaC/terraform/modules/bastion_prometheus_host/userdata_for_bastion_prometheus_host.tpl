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
chmod +x /usr/local/bin/node_exporter
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

# Install and configure Tailscale - lets the bastion act as a subnet router
# into the VPC (10.0.0.0/16) for internal-only access (Grafana, etc.)
# without a public Ingress, AWS Client VPN's per-hour billing, or hand-
# managing our own WireGuard keys/config (Tailscale is WireGuard underneath,
# plus a coordination service that handles key exchange/NAT traversal - see
# the bastion module README for the full mechanism notes).
curl -fsSL https://tailscale.com/install.sh | sh

# Off by default on a plain EC2 host since it's normally just a network
# endpoint, not a router - required for the subnet router to forward
# packets between the tailnet and the VPC interface. Tailscale does NOT set
# this for you.
cat <<SYSCTL > /etc/sysctl.d/99-tailscale-forwarding.conf
net.ipv4.ip_forward = 1
SYSCTL
sysctl --system

systemctl enable --now tailscaled

# --authkey joins non-interactively (no browser login on a headless box) -
# ephemeral so this node auto-removes from the tailnet when the bastion is
# destroyed each session, instead of piling up stale offline devices.
# --advertise-routes is what makes this a subnet router rather than just
# another tailnet member - still needs approving once in the admin console
# (or auto-approved via an ACL tag) before other devices can actually reach
# 10.0.0.0/16 through it.
tailscale up --authkey="${tailscale_authkey}" --advertise-routes=10.0.0.0/16 --hostname=bastion-vpn --accept-routes=false
