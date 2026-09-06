# Throttle

SourceMod crash report viewer and symbol server.

## Quick Start (Local Development)

```bash
cp .env.example .env
docker compose up -d
```

Access at http://localhost:80 (or `:${HTTP_PORT}`)

## Production with HTTPS (Cloudflare DNS Challenge)

### 1. Create Cloudflare API Token

1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Create token with **Zone > DNS > Edit** permissions for your domain
3. Copy the token

### 2. Configure Environment

```bash
cp .env.example .env
```

Edit `.env`:
```env
THROTTLE_HOSTNAME=throttle.example.com
CF_API_TOKEN=your_cloudflare_api_token_here
HTTP_PORT=80
HTTPS_PORT=443
```

### 3. Deploy

```bash
docker compose up -d
```

Caddy will:
- Provision TLS certificates via Let's Encrypt using Cloudflare DNS-01 challenge
- Redirect HTTP to HTTPS
- Serve your app at https://throttle.example.com

### 4. Verify

```bash
# Check Caddy logs for certificate issuance
docker compose logs -f caddy

# Test HTTPS
curl -I https://throttle.example.com
```

## How It Works

- **No `CF_API_TOKEN`**: Caddy serves plain HTTP on port 80 (local/dev)
- **With `CF_API_TOKEN`**: Caddy uses the Cloudflare DNS plugin to:
  1. Solve DNS-01 challenge via Cloudflare API
  2. Obtain Let's Encrypt certificates
  3. Serve HTTPS on port 443 with automatic renewal

## Ports

| Variable | Default | Description |
|----------|---------|-------------|
| `HTTP_PORT` | 80 | Host port for HTTP (ACME redirects, non-HTTPS traffic) |
| `HTTPS_PORT` | 443 | Host port for HTTPS (when `CF_API_TOKEN` is set) |

## Admin User

Admins can manage/delete any crash report, view all users, etc. Set one or more
Steam ID64s via `THROTTLE_ADMINS` (comma-separated). The entrypoint writes them
into the generated `app/config.php` (`admins` array) on container start.

Find your Steam ID64 (a 17-digit number) from your profile URL
(`steamcommunity.com/id/<name>/profile/?id=7656...`) or via steamid.io.

```env
THROTTLE_ADMINS=76561198012345678,76561198987654321
```

Then recreate the app so the config is regenerated:

```bash
docker compose up -d --force-recreate app
```

Verify:

```bash
docker compose exec app grep "'admins'" /var/www/throttle/app/config.php
```

## Custom Caddy Image

The `docker/Dockerfile.caddy` builds a Caddy binary with the Cloudflare DNS provider plugin using `xcaddy`. This image is built automatically by docker-compose.

## Troubleshooting

**Certificate not issuing?**
- Verify `CF_API_TOKEN` has correct Zone:DNS:Edit permissions
- Check domain is managed by Cloudflare (orange-clouded)
- Check Caddy logs: `docker compose logs caddy`

**Rate limited by Let's Encrypt?**
- Use staging CA for testing (uncomment `acme_ca` in Caddyfile)
- Wait before retrying production

**Port 80/443 already in use?**
- Change `HTTP_PORT`/`HTTPS_PORT` in `.env`
- Or stop conflicting services (e.g., `sudo systemctl stop nginx`)