# Trusted base image for frontend/ - published to ECR trusted_base_images
# as httpd-2.4-alpine-<run>.<attempt> by .github/workflows/curate-base-images.yml,
# only after a clean Trivy scan.
FROM httpd:2.4-alpine

# apk upgrade: pull OS fixes Alpine has already published but the upstream
# image hasn't been rebuilt with yet (e.g. perl CVE-2026-13221, fixed in
# 5.42.2-r1 while httpd:2.4-alpine still shipped r0).
# apk del perl: only httpd's build-time helper scripts (apxs, dbmmanage)
# use it, never the running server, and no package depends on it - so drop
# it instead of patching its CVEs forever.
RUN apk upgrade --no-cache && apk del --no-cache perl
