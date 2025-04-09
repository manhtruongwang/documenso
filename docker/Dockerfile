###########################
#     BASE CONTAINER      #
###########################
FROM node:22-slim AS base

RUN apt-get update && apt-get install -y openssl libglib2.0-0 libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 libcairo2 libasound2


###########################
#    BUILDER CONTAINER    #
###########################
FROM base AS builder

WORKDIR /app

COPY . .

RUN npm install -g "turbo@^1.9.3"

# Outputs to the /out folder
# source: https://turbo.build/repo/docs/reference/command-line-reference/prune#--docker
RUN turbo prune --scope=@documenso/remix --docker

###########################
#   INSTALLER CONTAINER   #
###########################
FROM base AS installer

RUN apt-get update && apt-get install -y jq make cmake g++ bash

WORKDIR /app

# Disable husky from installing hooks
ENV HUSKY 0
ENV DOCKER_OUTPUT 1
ENV NEXT_TELEMETRY_DISABLED 1

# Encryption keys
ARG NEXT_PRIVATE_ENCRYPTION_KEY="CAFEBABE"
ENV NEXT_PRIVATE_ENCRYPTION_KEY="$NEXT_PRIVATE_ENCRYPTION_KEY"

ARG NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY="DEADBEEF"
ENV NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY="$NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY"


# Uncomment and use build args to enable remote caching
# ARG TURBO_TEAM
# ENV TURBO_TEAM=$TURBO_TEAM
# ARG TURBO_TOKEN
# ENV TURBO_TOKEN=$TURBO_TOKEN

# First install the dependencies (as they change less often)
COPY .gitignore .gitignore
COPY --from=builder /app/out/json/ .
COPY --from=builder /app/out/package-lock.json ./package-lock.json

COPY --from=builder /app/lingui.config.ts ./lingui.config.ts

RUN npm ci

# Then copy all the source code (as it changes more often)
COPY --from=builder /app/out/full/ .

# Finally copy the turbo.json file so that we can run turbo commands
COPY turbo.json turbo.json

RUN npm install -g "turbo@^1.9.3"

RUN npx playwright install --with-deps chromium

RUN turbo run build --filter=@documenso/remix...

###########################
#     RUNNER CONTAINER    #
###########################
FROM base AS runner

ENV HUSKY 0
ENV DOCKER_OUTPUT 1

# Don't run production as root
RUN groupadd --system --gid 1001 nodejs
RUN useradd --system --uid 1001 --gid nodejs nodejs

WORKDIR /app

COPY --from=builder /app/out/json/ .
# Copy the tailwind config files across
COPY --from=builder /app/out/full/packages/tailwind-config ./packages/tailwind-config

# Install dependencies as root
RUN npm ci --only=production

# Copy the built files
COPY --from=installer /app/apps/remix/build ./apps/remix/build
COPY --from=installer /app/apps/remix/public ./apps/remix/public

# Copy the prisma binary, schema and migrations
COPY --from=installer /app/packages/prisma/schema.prisma ./packages/prisma/schema.prisma
COPY --from=installer /app/packages/prisma/migrations ./packages/prisma/migrations

# Copy playwright browsers
COPY --from=installer /root/.cache/ms-playwright /home/nodejs/.cache/ms-playwright

# Generate the prisma client as root
RUN npx prisma generate --schema ./packages/prisma/schema.prisma

# Copy the start script
COPY ./docker/start.sh /app/apps/remix/start.sh

# Fix permissions for the nodejs user
RUN chown -R nodejs:nodejs /app

# Switch to non-root user after all setup is done
USER nodejs

WORKDIR /app/apps/remix

CMD ["sh", "start.sh"]