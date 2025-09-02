FROM caddy:builder-alpine AS caddy-builder
RUN --mount=type=cache,target=/go/pkg/mod/cache xcaddy build \
  --with github.com/caddyserver/caddy/v2=github.com/trajano/caddy/v2@otel-client \
  --with github.com/caddyserver/cache-handler \
  --with github.com/darkweak/storages/nuts/caddy \
  --with github.com/darkweak/storages/redis/caddy

FROM caddy:alpine AS prerelease
COPY --from=caddy-builder /usr/bin/caddy /usr/bin/caddy
COPY Caddyfile /etc/caddy/Caddyfile

FROM prerelease AS test
RUN caddy validate --config /etc/caddy/Caddyfile

FROM prerelease AS release
VOLUME /data/nuts
