
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
  description = "Root EBS volume size (GiB) for worker nodes."
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
