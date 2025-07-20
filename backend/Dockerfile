
# -----------------------------------------------------------------------------------------------
# Base image
# Use the official Node.js Alpine image as a base for the backend service: 
# -----------------------------------------------------------------------------------------------
FROM node:24-alpine AS base
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


