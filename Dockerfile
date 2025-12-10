ARG BUILD_FROM
FROM node:20-alpine AS builder

ARG RETROASSEMBLY_VERSION

WORKDIR /app

# Install git and other build dependencies
RUN apk add --no-cache git python3 make g++

# Clone repository
RUN git clone --depth 1 --branch ${RETROASSEMBLY_VERSION} https://github.com/arianrhodsandlot/retroassembly.git .

# HA Ingress: Apply minimal patch to make routes relative
RUN sed -i "s|: '/|: '|g" src/pages/routes.ts

# Enable and download pnpm
RUN npm i -g pnpm

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
    npm \
    nginx

WORKDIR /app

# Copy built application
COPY --from=builder /app/package.json ./
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules

# Copy root filesystem (S6 services and nginx config)
COPY rootfs /
COPY nginx.conf /etc/nginx/nginx.conf

# Use S6 init
CMD [ "/init" ]
