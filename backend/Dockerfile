
# -----------------------------------------------------------------------------------------------
# Base image
# Trusted, patched + scanned copy of node:26-alpine (see base-images/node and
# .github/workflows/curate-base-images.yml). Pinned by tag (readable) AND digest
# (immutable - Docker uses the digest). Bump both via PR when a new curated tag lands.
# Building locally needs an ECR login first (see IaC/README.md).
# -----------------------------------------------------------------------------------------------
FROM 341587087009.dkr.ecr.us-east-1.amazonaws.com/trusted_base_images:node-26-alpine-1.1@sha256:aa412a145d4fe148bb3cc40068ff5dadb4ed2b882e7cde847343344dfe6851e7 AS base
WORKDIR /app

# -----------------------------------------------------------------------------------------------
# Install dependencies
# Re-install dependencies only when [package.json]/[package-lock.json] files change - [Caching] 
# -----------------------------------------------------------------------------------------------
FROM base AS dependencies
COPY package*.json ./
RUN npm ci


# -----------------------------------------------------------------------------------------------
# Test stage
# Run tests right in the container reusing the installed dependencies:
# -----------------------------------------------------------------------------------------------
FROM dependencies AS test
COPY . .
RUN npm run test


# -----------------------------------------------------------------------------------------------
# Final runtime container
# IMPORTANT: Add node_modules to your .dockerignore file to avoid overwriting the node_modules from the dependencies stage:
# -----------------------------------------------------------------------------------------------
FROM base AS production
WORKDIR /app
# Copy just what we need from the dependencies stage and leave out the dev/test dependencies:
COPY --from=dependencies /app/node_modules ./node_modules
COPY . .
RUN npm install
EXPOSE 3000
CMD ["node", "server.js"]


