
##################################################################
# ONE-TIME STATE MIGRATION - delete this file in the follow-up PR.
#
# kubernetes provider v3 deprecates the un-versioned resource types
# (kubernetes_secret, kubernetes_namespace, ...) in favour of *_v1. The
# provider can't `moved` state across resource types ("Move Resource State
# Not Supported"), so each object is handed over in two steps that never
# touch the cluster:
#   removed: forget the old address in state WITHOUT deleting the object
#            (deleting a namespace would delete everything inside it)
#   import : adopt the same live object under its new *_v1 address
#
# Must be removed once applied: on a fresh bring-up (empty state) these
# import blocks would try to adopt objects that don't exist yet and fail.
##################################################################

# --- Namespaces ---
removed {
  from = kubernetes_namespace.calc_app
  lifecycle { destroy = false }
}
import {
  to = kubernetes_namespace_v1.calc_app
  id = "calc-app"
}

removed {
  from = kubernetes_namespace.monitoring
  lifecycle { destroy = false }
}
import {
  to = kubernetes_namespace_v1.monitoring
  id = "monitoring"
}

# --- Secrets ---
removed {
  from = kubernetes_secret.backend_db
  lifecycle { destroy = false }
}
import {
  to = kubernetes_secret_v1.backend_db
  id = "calc-app/backend-secrets"
}

removed {
  from = kubernetes_secret.cloudflare_api_token
  lifecycle { destroy = false }
}
import {
  to = kubernetes_secret_v1.cloudflare_api_token
  id = "kube-system/cloudflare-api-token"
}

removed {
  from = kubernetes_secret.grafana_admin
  lifecycle { destroy = false }
}
import {
  to = kubernetes_secret_v1.grafana_admin
  id = "monitoring/grafana-admin-credentials"
}

# --- Monitoring namespace guardrails ---
removed {
  from = kubernetes_limit_range.monitoring
  lifecycle { destroy = false }
}
import {
  to = kubernetes_limit_range_v1.monitoring
  id = "monitoring/monitoring-default-limits"
}

removed {
  from = kubernetes_resource_quota.monitoring
  lifecycle { destroy = false }
}
import {
  to = kubernetes_resource_quota_v1.monitoring
  id = "monitoring/monitoring-quota"
}

# --- StorageClasses (cluster-scoped - id is just the name) ---
removed {
  from = kubernetes_storage_class.ebs_gp3
  lifecycle { destroy = false }
}
import {
  to = kubernetes_storage_class_v1.ebs_gp3
  id = "ebs-gp3"
}

removed {
  from = kubernetes_storage_class.ebs_gp3_observability
  lifecycle { destroy = false }
}
import {
  to = kubernetes_storage_class_v1.ebs_gp3_observability
  id = "ebs-gp3-observability"
}
