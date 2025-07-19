
########################## Variables for CPU above 70% CloudWatch Alarm #########################
variable "cpu_above_70_alarm_alarm_name" {
  type        = string
  description = "Name of the alarm for high CPU usage"
}

variable "cpu_above_70_alarm_comparison_operator" {
  type        = string
  description = "Comparison operator for high CPU alarm"
}

variable "cpu_above_70_alarm_evaluation_periods" {
  type        = string
  description = "Evaluation periods for high CPU alarm"
}

variable "cpu_above_70_alarm_metric_name" {
  type        = string
  description = "Metric name for high CPU alarm"
}

variable "cpu_above_70_alarm_namespace" {
  type        = string
  description = "Namespace for high CPU alarm"
}

variable "cpu_above_70_alarm_period" {
  type        = string
  description = "Period for high CPU alarm"
}

variable "cpu_above_70_alarm_statistic" {
  type        = string
  description = "Statistic for high CPU alarm"
}

variable "cpu_above_70_alarm_threshold" {
  type        = string
  description = "Threshold for high CPU alarm"
}

variable "cpu_above_70_alarm_alarm_description" {
  type        = string
  description = "Description of high CPU alarm"
}

variable "cpu_above_70_alarm_actions_enabled" {
  type        = bool
  description = "Whether actions are enabled for high CPU alarm"
  default     = true
}

variable "cpu_above_70_alarm_autoscaling_group_name" {
  type        = string
  description = "Auto Scaling group name for high CPU alarm dimension"
}

########################## Variables for scaling out policy #########################
variable "scale_out_policy_name" {
  type        = string
  description = "Name of the scale-out policy"
}

variable "scale_out_policy_scaling_adjustment" {
  type        = number
  description = "Scaling adjustment for scale-out policy"
  default     = 1
}

variable "scale_out_policy_adjustment_type" {
  type        = string
  description = "Adjustment type for scale-out policy"
}

variable "scale_out_policy_cooldown" {
  type        = number
  description = "Cooldown period for scale-out policy"
  default     = 120
}

variable "scale_out_policy_autoscaling_group_name" {
  type        = string
  description = "Auto Scaling group ID for scale-out policy"
}

######################### Variables for CPU below 50% CloudWatch Alarm #########################
variable "cpu_below_50_alarm_alarm_name" {
  type        = string
  description = "Name of the alarm for low CPU usage"
}

variable "cpu_below_50_alarm_comparison_operator" {
  type        = string
  description = "Comparison operator for low CPU alarm"
}

variable "cpu_below_50_alarm_evaluation_periods" {
  type        = string
  description = "Evaluation periods for low CPU alarm"
}

variable "cpu_below_50_alarm_metric_name" {
  type        = string
  description = "Metric name for low CPU alarm"
}

variable "cpu_below_50_alarm_namespace" {
  type        = string
  description = "Namespace for low CPU alarm"
}

variable "cpu_below_50_alarm_period" {
  type        = string
  description = "Period for low CPU alarm"
}

variable "cpu_below_50_alarm_statistic" {
  type        = string
  description = "Statistic for low CPU alarm"
}

variable "cpu_below_50_alarm_threshold" {
  type        = string
  description = "Threshold for low CPU alarm"
}

variable "cpu_below_50_alarm_alarm_description" {
  type        = string
  description = "Description of low CPU alarm"
}

variable "cpu_below_50_alarm_actions_enabled" {
  type        = bool
  description = "Whether actions are enabled for low CPU alarm"
}

variable "cpu_below_50_alarm_autoscaling_group_name" {
  type        = string
  description = "Auto Scaling group name for low CPU alarm dimension"
}

########################## Variables for scaling in policy #########################
variable "scale_in_policy_name" {
  type        = string
  description = "Name of the scale-in policy"
}

variable "scale_in_policy_scaling_adjustment" {
  type        = number
  description = "Scaling adjustment for scale-in policy"
  default     = -1
}

variable "scale_in_policy_adjustment_type" {
  type        = string
  description = "Adjustment type for scale-in policy"
}

variable "scale_in_policy_cooldown" {
  type        = number
  description = "Cooldown period for scale-in policy"
  default     = 120
}

variable "scale_in_policy_autoscaling_group_name" {
  type        = string
  description = "Auto Scaling group ID for scale-in policy"
}
