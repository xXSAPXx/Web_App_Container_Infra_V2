# Trusted base image for backend/ - published to ECR trusted_base_images
# as node-26-alpine-<run>.<attempt> by .github/workflows/curate-base-images.yml,
# only after a clean Trivy scan.
FROM node:26-alpine

# Pull OS fixes Alpine has already published but the upstream image hasn't
# been rebuilt with yet - the weekly curation run picks them up even when
# node:26-alpine itself doesn't change.
RUN apk upgrade --no-cache
