
##################################################################
# CLOUDWATCH ALARM AND SCALING OUT POLICY (CPU above 70% ALARM)
##################################################################

# Define a CloudWatch Alarm for CPU Utilization Above 70%
resource "aws_cloudwatch_metric_alarm" "cpu_alarm_high" {
  alarm_name          = var.cpu_above_70_alarm_alarm_name
  comparison_operator = var.cpu_above_70_alarm_comparison_operator
  evaluation_periods  = var.cpu_above_70_alarm_evaluation_periods
  metric_name         = var.cpu_above_70_alarm_metric_name
  namespace           = var.cpu_above_70_alarm_namespace
  period              = var.cpu_above_70_alarm_period
  statistic           = var.cpu_above_70_alarm_statistic
  threshold           = var.cpu_above_70_alarm_threshold
  alarm_description   = var.cpu_above_70_alarm_alarm_description
  actions_enabled     = var.cpu_above_70_alarm_actions_enabled
  alarm_actions       = [aws_autoscaling_policy.scale_out_policy.arn]
  dimensions = {
    AutoScalingGroupName = var.cpu_above_70_alarm_autoscaling_group_name
  }
}

# Define the Scaling Policy for Scaling Out
resource "aws_autoscaling_policy" "scale_out_policy" {
  name                   = var.scale_out_policy_name
  scaling_adjustment     = var.scale_out_policy_scaling_adjustment
  adjustment_type        = var.scale_out_policy_adjustment_type
  cooldown               = var.scale_out_policy_cooldown
  autoscaling_group_name = var.scale_out_policy_autoscaling_group_name
}


##################################################################
# CLOUDWATCH ALARM AND SCALING IN POLICY (CPU below 50% ALARM)
##################################################################

# Define a CloudWatch Alarm for CPU Utilization Below 50%
resource "aws_cloudwatch_metric_alarm" "cpu_alarm_low" {
  alarm_name          = var.cpu_below_50_alarm_alarm_name
  comparison_operator = var.cpu_below_50_alarm_comparison_operator
  evaluation_periods  = var.cpu_below_50_alarm_evaluation_periods
  metric_name         = var.cpu_below_50_alarm_metric_name
  namespace           = var.cpu_below_50_alarm_namespace
  period              = var.cpu_below_50_alarm_period
  statistic           = var.cpu_below_50_alarm_statistic
  threshold           = var.cpu_below_50_alarm_threshold
  alarm_description   = var.cpu_below_50_alarm_alarm_description
  actions_enabled     = var.cpu_below_50_alarm_actions_enabled
  alarm_actions       = [aws_autoscaling_policy.scale_in_policy.arn]
  dimensions = {
    AutoScalingGroupName = var.cpu_below_50_alarm_autoscaling_group_name
  }
}

# Define the Scaling Policy for Scaling In
resource "aws_autoscaling_policy" "scale_in_policy" {
  name                   = var.scale_in_policy_name
  scaling_adjustment     = var.scale_in_policy_scaling_adjustment
  adjustment_type        = var.scale_in_policy_adjustment_type
  cooldown               = var.scale_in_policy_cooldown
  autoscaling_group_name = var.scale_in_policy_autoscaling_group_name
}