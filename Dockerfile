FROM node:18.14.1-bullseye AS common

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
	--mount=type=cache,target=/var/lib/apt,sharing=locked \
	apt-get update
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
	--mount=type=cache,target=/var/lib/apt,sharing=locked \
	apt-get install -y --no-install-recommends build-essential


FROM common AS builder

ARG NODE_ENV=production

WORKDIR /misskey

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY packages/backend/package.json ./packages/backend/
COPY packages/client/package.json ./packages/client/
COPY packages/sw/package.json ./packages/sw/

RUN corepack enable
RUN pnpm install --frozen-lockfile

COPY gulpfile.js ./gulpfile.js
COPY locales ./locales
COPY scripts ./scripts
COPY packages/backend ./packages/backend
COPY packages/client ./packages/client
COPY packages/sw ./packages/sw

RUN pnpm build