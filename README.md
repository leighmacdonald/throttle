# Throttle

SourceMod crash report viewer and symbol server.

## Quick Start (Local Development)

```bash
cp .env.example .env
docker compose up -d
```

Access at http://localhost:8080

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