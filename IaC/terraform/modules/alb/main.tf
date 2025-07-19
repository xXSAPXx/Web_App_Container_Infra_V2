
########################################################################################################
# Target Groups Creation for ALB (Frontend / Backend)
########################################################################################################


# Frontend Target Group Creation: (httpd service)
resource "aws_lb_target_group" "frontend_tg" {
  name     = var.frontend_tg_name
  port     = var.frontend_tg_port
  protocol = var.frontend_tg_protocol
  vpc_id   = var.vpc_id

  health_check {
    path                = var.frontend_tg_path # Path to your health_check.html file OR "/" FOR GENERIC ROOT_PATH HEALTH_CHECK
    interval            = var.frontend_tg_interval
    timeout             = var.frontend_tg_timeout
    healthy_threshold   = var.frontend_tg_healthy_threshold
    unhealthy_threshold = var.frontend_tg_unhealthy_threshold
    matcher             = var.frontend_tg_matcher
  }

  tags = {
    Name = var.frontend_tg_tag_name
  }
}


# Backend Target Group Creation: (Node.js)
resource "aws_lb_target_group" "backend_tg" {
  name     = var.backend_tg_name
  port     = var.backend_tg_port
  protocol = var.backend_tg_protocol
  vpc_id   = var.vpc_id

  health_check {
    path                = var.backend_tg_path # Backend Server Endpoint Health Check defined in server.js:
    interval            = var.backend_tg_interval
    timeout             = var.backend_tg_timeout
    healthy_threshold   = var.backend_tg_healthy_threshold
    unhealthy_threshold = var.backend_tg_unhealthy_threshold
    matcher             = var.backend_tg_matcher
  }
  tags = {
    Name = var.backend_tg_tag_name
  }
}



##################################################################################################################
# Application Load Balancer (ALB) / ALB Listeners for HTTP and HTTPS Routing To The ALB Target Group 
##################################################################################################################

# Define the Application Load Balancer
resource "aws_lb" "web_alb" {
  name               = var.alb_name
  internal           = var.alb_internal
  load_balancer_type = var.alb_load_balancer_type
  security_groups    = var.alb_security_groups
  subnets            = var.alb_subnets # We need 2 Subnets for the ALB to work


  enable_deletion_protection = var.alb_enable_deletion_protection

  tags = {
    Name = var.alb_tag_name
  }
}


# Define ALB HTTP Listener to be Redirected from HTTP:80 to HTTPS:443
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = var.http_listener_port
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      protocol    = var.http_listener_redirect_protocol
      port        = var.http_listener_redirect_port
      status_code = var.http_listener_redirect_status_code
    }

  }
}

# Define ALB HTTPS Listener (With the relevant TLS Cert:)
# Forward if path is `/` or `/*.html` or similar → frontend-tg
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = var.https_listener_port
  protocol          = "HTTPS"
  ssl_policy        = var.https_listener_ssl_policy
  certificate_arn   = var.https_listener_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}

# Listener Rule To Send /api/* To Backend:
# Forward if path starts with `/api/*` → backend-tg
resource "aws_lb_listener_rule" "backend_api_route" {
  listener_arn = aws_lb_listener.https.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }

  condition {
    path_pattern {
      values = var.backend_path_patterns
    }
  }
}



