
# Dockerfile for the frontend service using Apache HTTP Server.
# Base: trusted, patched + scanned copy of httpd:2.4-alpine (see base-images/httpd
# and .github/workflows/curate-base-images.yml). Pinned by tag (readable) AND digest
# (immutable - Docker uses the digest). Bump both via PR when a new curated tag lands.
# Building locally needs an ECR login first (see IaC/README.md).
FROM 341587087009.dkr.ecr.us-east-1.amazonaws.com/trusted_base_images:httpd-2.4-alpine-1.1@sha256:137a5516fd6e0a25d7d18ba2354a1b1de146c804992e14680b992afd50611e34

# Copy the public directory files to the Apache document root:
COPY ./public /usr/local/apache2/htdocs/

# Copy the custom httpd configuration file:
COPY httpd.conf /usr/local/apache2/conf/httpd.conf

# httpd listens on 8080 (non-root can't bind <1024) - see Listen in httpd.conf:
EXPOSE 8080
