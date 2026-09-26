
##############################################
# CLUSTER IDENTITY / VERSION:
##############################################

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster."
  default     = "app-eks-cluster"
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes version for the EKS control plane. Deliberately not pinned to the latest (1.36 as of 2026-07) - keeping some standard-support versions above this one gives room to practice in-place upgrades later. Check `aws eks describe-cluster-versions` before bumping further, support windows move fast."
  default     = "1.34"
}


##############################################
# NETWORKING:
##############################################

variable "vpc_id" {
  type        = string
  description = "VPC ID the cluster is deployed into."
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs - passed to the cluster's vpc_config alongside the private subnets so the control plane ENIs can span both tiers."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs - where the managed node group's EC2 instances are launched."
}

variable "endpoint_private_access" {
  type        = bool
  description = "Enable the private EKS API endpoint."
  default     = true
}

variable "endpoint_public_access" {
  type        = bool
  description = "Enable the public EKS API endpoint (kept on for a learning/dev cluster; would normally be off or CIDR-restricted in a real prod account)."
  default     = true
}

variable "my_ip_cidr" {
  type        = string
  sensitive   = true
  description = "Your personal IP, as a /32 - the only address allowed to reach the public EKS API endpoint directly. endpoint_private_access already covers in-VPC/Tailscale access regardless of this."
}


##############################################
# LOGGING / ENCRYPTION:
##############################################

variable "enabled_cluster_log_types" {
  type        = list(string)
  description = "EKS control-plane log types to ship to CloudWatch."
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cluster_log_retention_days" {
  type        = number
  description = "CloudWatch log retention for the EKS control-plane log group."
  default     = 30
}


##############################################
# MANAGED NODE GROUP:
##############################################

variable "eks_node_security_group_id" {
  type        = string
  description = "Additional security group (from modules/security_groups) attached to node ENIs via a launch template - covers pod-to-pod, ALB-to-pod, and bastion ICMP traffic."
}

variable "node_instance_types" {
  type        = list(string)
  description = "EC2 instance types for the managed node group."
  default     = ["t3.medium"]
}

variable "node_disk_size" {
  type        = number
  description = "Root EBS volume size (GiB) for worker nodes. 20 is not an arbitrary choice - the EKS-optimized AMI's root volume is created from a pre-baked snapshot, and EC2 hard-rejects any volume smaller than the snapshot it's sourced from (confirmed: 10 fails with 'Volume of size 10GB is smaller than snapshot ..., expect size >= 20GB'). Measured real usage right after a cold start (OS + every platform/monitoring image pulled) was ~5Gi/20Gi (25%), so there's real headroom - it just can't be reclaimed by shrinking this value."
  default     = 20
}

variable "node_desired_size" {
  type        = number
  description = "Desired worker node count. Static for this foundation pass - Karpenter replaces this with dynamic provisioning in a later phase."
  default     = 2
}

variable "node_min_size" {
  type        = number
  description = "Minimum worker node count."
  default     = 2
}

variable "node_max_size" {
  type        = number
  description = "Maximum worker node count."
  default     = 2
}

variable "node_max_pods" {
  type        = number
  description = "kubelet --max-pods override, applied via the launch template's user_data. Only meaningful because the vpc-cni addon has ENABLE_PREFIX_DELEGATION on (see addons.tf) - the AMI's default max-pods table doesn't account for prefix delegation on its own. 110 is AWS's own commonly recommended ceiling once prefix delegation is enabled, well above what the raw IP math would technically allow, since other things (etcd, kube-proxy iptables rules) also scale with pods-per-node."
  default     = 110
}
