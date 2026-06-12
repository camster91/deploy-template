# Generic Dockerfile template for camster91/* Node.js web apps.
#
# Replace {{PORT}} with the port your app listens on (3000 by default).
# Assumes:
#   - npm or pnpm project
#   - "build" script produces production assets
#   - "start" script runs the server
#
# The framework supports any of:
#   - Static SPA (Vite, Next.js static, Astro) — just `npm run build`, serve dist/
#   - Node server (Express, Fastify, Next.js standalone) — `npm start` on PORT
#   - Static export (just serve dist/ via nginx)
#
# Two stages: build → runtime. Runtime is the smaller image (no dev deps).

# ─── Stage 1: build ─────────────────────────────────────────────────────
FROM node:20-alpine AS build

WORKDIR /app

# Layer-cache the install
COPY package*.json ./
COPY pnpm-lock.yaml* ./
RUN \
  if [ -f pnpm-lock.yaml ]; then \
    corepack enable && corepack prepare pnpm@latest --activate && \
    pnpm install --frozen-lockfile; \
  else \
    npm install --no-audit --no-fund --include=dev; \
  fi

COPY . .
RUN npm run build

# ─── Stage 2: runtime ───────────────────────────────────────────────────
FROM node:20-alpine AS runtime

# curl + wget for healthchecks
RUN apk add --no-cache curl wget tini

WORKDIR /app

# Production-only deps
COPY package*.json ./
COPY pnpm-lock.yaml* ./
RUN \
  if [ -f pnpm-lock.yaml ]; then \
    corepack enable && corepack prepare pnpm@latest --activate && \
    pnpm install --frozen-lockfile --prod; \
  else \
    npm install --omit=dev --no-audit --no-fund; \
  fi

COPY --from=build /app/dist ./dist
COPY --from=build /app/build ./build 2>/dev/null || true
COPY --from=build /app/.next ./.next 2>/dev/null || true
COPY . .

# Persistent data dir (DBs, uploads)
RUN mkdir -p /app/data && chown -R node:node /app

USER node

ENV PORT=3000 \
    NODE_ENV=production

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/api/health || exit 1

# tini = proper signal handling (SIGTERM, etc.)
ENTRYPOINT ["/sbin/tini", "--"]

CMD ["node", "server.js"]
