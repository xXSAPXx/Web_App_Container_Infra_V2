
# How to set up IaC repo for this project on your own machine:
#
1) Download the Repo in a Code Editor of your choice. (Example: VSCode).
2) Download Terraform on your local machine and configure $PATH - (Check supporter versions for this project in main.tf).
3) Download AWS CLI and configure your AWS Credentials.
4) Create the Terraform Remote Backend (Configureed in backend.tf).
4) Initialize the Terrafrom Configuration.


# Network Architecture Diagram:

This architecture describes traffic flow for the domain `www.xxsapxx.uk` which is proxied through Cloudflare in **Full TLS mode**, routed to an AWS Application Load Balancer (ALB), and forwarded to frontend and backend targets based on path rules.

```text
                                                            ALB_HTTP_LISTENER
                                                           (REDIRECTED TO HTTPS)
                                                                  |
                                                                  V
Browser -----------------> CloudFlare_Proxy -----------------> ALB_DNS -------------------> ALB_HTTPS_LISTENER
`www.xxsapxx.uk`            (FULL_TLS_MODE)                  (`AWS_TLS_CERT_WITH_ACM`)           |
                            (CNAME www -> ALB_DNS)                                               |
                                                                                                 |
                                                                                +---------------------------+
                                                                                | Path Rule: '/api/*'       | URL/*
                                                                                |                           |
                                                                                V                           V
                                                                ALB_BACKEND_TG_PORT_3000          ALB_FRONTEND_TG_PORT_80    
                                                                (HEALTH_CHECK: /backend)           (HEALTH_CHECK: /)     


