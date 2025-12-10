ARG BUILD_FROM
FROM node:20-alpine AS builder

ARG RETROASSEMBLY_VERSION

WORKDIR /app

# Install git and other build dependencies
RUN apk add --no-cache git python3 make g++

# Clone repository
RUN git clone --depth 1 --branch ${RETROASSEMBLY_VERSION} https://github.com/arianrhodsandlot/retroassembly.git .

# Enable and download pnpm
RUN npm i -g pnpm

# Fix SSR Error: Patch navigator usage to be safe
RUN sed -i "s|navigator.userAgent|((typeof navigator !== 'undefined') ? navigator.userAgent : '')|g" src/pages/library/hooks/use-is-apple.ts
RUN sed -i "s|navigator.userAgent|((typeof navigator !== 'undefined') ? navigator.userAgent : '')|g" src/pages/library/components/game-buttons/game-buttons.tsx

# Install dependencies and build
RUN pnpm install
RUN npm run build

# Production dependencies
RUN pnpm install --prod

# ------------------------------------------------------------------------------
# Target Build
# ------------------------------------------------------------------------------
FROM $BUILD_FROM

# Install runtime dependencies
RUN apk add --no-cache \
    nodejs \
    npm

WORKDIR /app

# Copy built application
COPY --from=builder /app/package.json ./
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/src/databases/migrations ./src/databases/migrations

# Copy root filesystem (S6 services)
COPY rootfs /

# Use S6 init
