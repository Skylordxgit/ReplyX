# Local Limcx image: layers this working tree over the upstream runtime image.
#
# Why this exists: macOS TCC blocks Docker Desktop from bind-mounting ~/Downloads,
# so the usual "mount the source" dev loop is unavailable on this machine.
# Docker *builds* can still read the directory, so we copy the source in instead.
#
# Requires host-built frontend assets (public/vite) to exist before building:
#   RAILS_ENV=production NODE_ENV=production NODE_OPTIONS=--max-old-space-size=6144 npx vite build
FROM chatwoot/chatwoot:latest

WORKDIR /app

# Ruby/app source + host-precompiled assets.
COPY app /app/app
COPY config /app/config
COPY db /app/db
COPY lib /app/lib
COPY enterprise /app/enterprise
COPY public/vite /app/public/vite
COPY public/assets /app/public/assets

# GIT_HASH falls back to this file when .git is absent (config/initializers/git_sha.rb).
COPY .git_sha /app/.git_sha
