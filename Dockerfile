# ============================================================
# Dockerfile — Multi-stage build for minimal production image
# ============================================================

# ── Stage 1: Dependencies ───────────────────────────────────
FROM node:20-alpine AS deps
WORKDIR /app
COPY app/package*.json ./
# Install only production dependencies
RUN npm ci --only=production

# ── Stage 2: Build / Test ───────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app
COPY app/package*.json ./
RUN npm ci                         # includes devDeps for tests
COPY app/src ./src
COPY app/tests ./tests

# ── Stage 3: Production image ───────────────────────────────
FROM node:20-alpine AS production
WORKDIR /app

# Non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=deps    /app/node_modules ./node_modules
COPY --from=builder /app/src          ./src
COPY app/package.json ./

# Set ownership
RUN chown -R appuser:appgroup /app
USER appuser

ENV NODE_ENV=production
ENV PORT=3000
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "src/index.js"]
