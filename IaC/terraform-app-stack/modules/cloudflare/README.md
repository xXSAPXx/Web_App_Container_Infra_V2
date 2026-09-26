# Domain / TLS Cert / ALB setup - how xxsapxx.uk gets wired up

This covers the **provisioning sequence** - what actually creates the cert,
the ALB, and the DNS records, and in what order. For the **traffic-flow**
view (what happens when a browser hits `www.xxsapxx.uk`), see the Network
Architecture Diagram in `IaC/README.md` instead - this doc is the
complementary "how did any of that come to exist" side of the same system.

Nothing here is a single `terraform apply`. Three separate things create
resources in sequence, reacting to each other rather than being directly
wired together in code:

1. Terraform (the ACM cert - independent of everything else below)
2. The AWS Load Balancer Controller (a pod in-cluster, reacting to
   `k8s/ingress.yaml`)
3. external-dns (a pod in-cluster, reacting to the same Ingress)


## Provisioning sequence

```text
STEP 1 - Terraform requests + validates the ACM cert (module.alb_ssl_cert_validation)
  Fully independent of the ALB - it doesn't exist yet at this point.

  aws_acm_certificate.alb_cert  (domain_name=xxsapxx.uk, san=[www.xxsapxx.uk])
          |
          v
  cloudflare_dns_record.cert_validation   (proof-of-ownership CNAME,
          |                                proxied=false - required)
          v
  aws_acm_certificate_validation.cert_validation   (blocks until ACM confirms)
          |
          v
  output: acm_certificate_arn
          (the cert now exists and is valid in ACM - nothing else has
           happened yet, no ALB, no DNS record pointing at anything)


STEP 2 - deploy-app.sh hands the cert ARN to the Ingress manifest
  terraform output -raw acm_certificate_arn
          |
          v
  envsubst -> k8s/rendered/ingress.yaml
          (alb.ingress.kubernetes.io/certificate-arn: <the arn from step 1>)


STEP 3 - kubectl apply -f k8s/rendered/  ->  ALB Controller reacts
  ALB Controller (helm_release.aws_load_balancer_controller) sees the
  Ingress and provisions a REAL ALB in AWS
          |
          v
  configures the ALB's :443 listener using the cert ARN from step 1
          (the cert is now actually live on a real load balancer)
          |
          v
  writes the ALB's real AWS-generated DNS hostname into
  Ingress.status.loadBalancer.ingress[].hostname


STEP 4 - external-dns reacts to that SAME Ingress status field
  external-dns (helm_release.external_dns) reads
  Ingress.status.loadBalancer.ingress[].hostname on its reconcile loop
          |
          v
  calls the Cloudflare API -> creates/updates:
    www.xxsapxx.uk  --CNAME-->  <alb-dns-name>
    (+ a hidden TXT ownership record alongside it)


STEP 5 - the bare apex rides along, no dynamic step needed
  modules/cloudflare's static, Terraform-managed CNAME:
    xxsapxx.uk  --CNAME-->  www.xxsapxx.uk
  (never points at the ALB directly - see "Why the apex is static" below)
```

Steps 3 and 4 never talk to each other directly - the ALB Controller and
external-dns are two unrelated pods. They communicate *through* the
Ingress object's `.status` field: one writes it, the other reads it.


## The two separate TLS connections

Since Cloudflare proxies these records (`proxied = true`), a client never
talks to your ALB directly - there are two independent HTTPS connections,
not one:

- **Browser <-> Cloudflare edge**: uses Cloudflare's own "Universal SSL"
  certificate. Entirely Cloudflare-managed - nothing in this repo touches it.
- **Cloudflare edge <-> your ALB (the origin)**: this is what the ACM cert
  from Step 1 is actually for. For Cloudflare to trust this second
  connection (under Full / Full-strict SSL mode), the ALB needs a real,
  valid certificate for the domain - a self-signed or missing cert here
  would break the Cloudflare-to-origin leg even though the browser-facing
  side looks fine.

(Cloudflare's SSL mode itself - Full vs Full-strict - is a dashboard
setting, not currently managed by this repo's Terraform.)


## Why the apex domain is static instead of dynamic

external-dns's ownership scheme writes a TXT record like
`cname-<hostname>` to mark records it manages. For a bare zone apex, that
pattern collapses to `cname-xxsapxx.uk` - no separating dot - which fails
its own zone-suffix matching and retries forever without ever converging
(visible as an endless `UPDATE` loop in its logs). Rather than fight that,
the apex is kept as a plain static CNAME pointing at `www.xxsapxx.uk`
(never at the ALB directly), managed here in `modules/cloudflare/main.tf`.
Since it points at `www` rather than the ALB's own hostname, it never
needs to change and needs no dynamic input - it's set once and never
touched again, unlike the `www` record above it.

