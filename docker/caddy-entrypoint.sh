#!/bin/sh
set -eu

# Generate Caddyfile based on whether CF_API_TOKEN is set
if [ -n "${CF_API_TOKEN:-}" ]; then
	cat >/etc/caddy/Caddyfile <<EOF
# Caddy configuration with Cloudflare DNS challenge for HTTPS.
# CF_API_TOKEN is set -> HTTPS with DNS-01 challenge via Cloudflare.

{
	# Optional: configure ACME CA (default: Let's Encrypt production)
	# acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
}

${THROTTLE_HOSTNAME} {
	tls {
		dns cloudflare ${CF_API_TOKEN}
	}
	reverse_proxy app:80 {
		header_up Host ${THROTTLE_HOSTNAME}
		header_up X-Forwarded-Host {host}
		header_up X-Forwarded-Proto {scheme}
		header_up X-Forwarded-For {remote_host}
	}
}

# Catch-all for direct IP access: plain HTTP to app
:80 {
	reverse_proxy app:80 {
		header_up Host ${THROTTLE_HOSTNAME}
		header_up X-Forwarded-Host {host}
		header_up X-Forwarded-Proto {scheme}
		header_up X-Forwarded-For {remote_host}
	}
}
EOF
else
	cat >/etc/caddy/Caddyfile <<EOF
# Caddy configuration for plain HTTP (no CF_API_TOKEN).
# Serves HTTP on port 80 only.

:80 {
	reverse_proxy app:80 {
		header_up Host ${THROTTLE_HOSTNAME}
		header_up X-Forwarded-Host {host}
		header_up X-Forwarded-Proto {scheme}
		header_up X-Forwarded-For {remote_host}
	}
}
EOF
fi

# Execute the original caddy command
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
