# syntax=docker/dockerfile:1.4

####################################################################################################
## Build Packages

FROM node:18-alpine AS builder
WORKDIR /directus

ARG TARGETPLATFORM

ENV NODE_OPTIONS=--max-old-space-size=8192

RUN <<EOF
  if [ "$TARGETPLATFORM" = 'linux/arm64' ]; then
  	apk --no-cache add python3 build-base
  	ln -sf /usr/bin/python3 /usr/bin/python
  fi
EOF

COPY package.json .
RUN corepack enable && corepack prepare

COPY pnpm-lock.yaml .
RUN pnpm fetch

COPY . .
RUN <<EOF
	pnpm install --recursive --offline --frozen-lockfile
	npm_config_workspace_concurrency=1 pnpm run build
	pnpm --filter directus deploy --prod dist
	cd dist
	# Regenerate package.json file with essential fields only
	# (see https://github.com/directus/directus/issues/20338)
	node -e '
		const f = "package.json", {name, version, type, exports, bin} = require(`./${f}`), {packageManager} = require(`../${f}`);
		fs.writeFileSync(f, JSON.stringify({name, version, type, exports, bin, packageManager}, null, 2));
	'
	mkdir -p database extensions uploads
EOF

# Download Litestream binary
ARG LITESTREAM_VERSION="v0.3.13"
ARG LITESTREAM_BINARY_TGZ_FILE_NAME="litestream-${LITESTREAM_VERSION}-linux-amd64.tar.gz"

ADD "https://github.com/benbjohnson/litestream/releases/download/${LITESTREAM_VERSION}/${LITESTREAM_BINARY_TGZ_FILE_NAME}" /tmp/litestream.tar.gz
RUN tar -C /usr/local/bin -xzf /tmp/litestream.tar.gz

####################################################################################################
## Create Production Image

FROM node:18-alpine AS runtime

RUN npm install --global pm2@5 && apk add --no-cache bash

USER node

WORKDIR /directus

EXPOSE 8055

ENV \
	DB_CLIENT="better-sqlite3" \
	DB_FILENAME="/directus/database/database.sqlite" \
	DB_EXCLUDE_TABLES="_litestream_lock" \
	NODE_ENV="production" \
	NPM_CONFIG_UPDATE_NOTIFIER="false"

COPY --from=builder --chown=node:node /directus/ecosystem.config.cjs .
COPY --from=builder --chown=node:node /directus/dist .
COPY --from=builder /usr/local/bin/litestream /usr/local/bin/litestream

COPY litestream.yml /etc/litestream.yml
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
