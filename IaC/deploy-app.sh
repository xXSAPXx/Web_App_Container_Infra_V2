#!/usr/bin/env bash
# Renders k8s/*.yaml templates using values pulled live from Terraform
# outputs (DB_HOST, ACM_CERT_ARN), then applies them.
#
# Run this AFTER `terraform apply` in IaC/terraform has finished - it reads
# that stack's outputs directly. Requires: terraform, kubectl, envsubst
# (ships with Git for Windows / most Linux distros via gettext).
#
# Usage: ./IaC/deploy-app.sh   (from anywhere in the repo)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TF_DIR="$SCRIPT_DIR/terraform"
K8S_DIR="$REPO_ROOT/k8s"
RENDERED_DIR="$K8S_DIR/rendered"

echo "==> Reading Terraform outputs from $TF_DIR"
RDS_ENDPOINT="$(terraform -chdir="$TF_DIR" output -raw rds_endpoint)"
export DB_HOST="${RDS_ENDPOINT%%:*}" # strip the trailing :3306
export ACM_CERT_ARN="$(terraform -chdir="$TF_DIR" output -raw acm_certificate_arn)"

echo "    DB_HOST      = $DB_HOST"
echo "    ACM_CERT_ARN = $ACM_CERT_ARN"

echo "==> Rendering templates into $RENDERED_DIR"
rm -rf "$RENDERED_DIR"
mkdir -p "$RENDERED_DIR"
for f in "$K8S_DIR"/*.yaml; do
  envsubst < "$f" > "$RENDERED_DIR/$(basename "$f")"
done

echo "==> Applying to the cluster"
kubectl apply -f "$RENDERED_DIR/"

echo "==> Done. Check rollout status with:"
echo "    kubectl get ingress -n calc-app"
echo "    kubectl get pods -n calc-app"
