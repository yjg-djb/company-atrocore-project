# Production Readiness

This project is ready for local Docker demos, but production still requires environment hardening, backup validation, and a stable ingress plan.

## Current Verified State

- Local Docker app runs on `http://localhost:8081`.
- Cloudflare Quick Tunnel can expose the local web service for temporary external demos.
- Core API, UI CRUD, file metadata, Import, Export, cron, cleanup, and schema checks pass with `FAIL=0`.
- Export production verification should use `ExportFeed/action/exportFile` plus `php console.php cron`; direct `ExportFeed/action/exportData` is a read-preview style path and currently logs a non-fatal `exportJobId` warning.

## Demo Mode: This Windows Machine

- Use `scripts/tunnel-quick.ps1` to start a temporary `https://*.trycloudflare.com` URL.
- Use `scripts/tunnel-stop.ps1` to stop the external URL.
- Keep Docker Desktop, the `web` and `db` containers, and the tunnel container running while the demo URL is needed.
- Do not treat Quick Tunnel as production uptime. The URL can change when restarted.
- Before sharing externally, change the default `admin/admin` password and run `verification/smoke.ps1`.

## Production Checklist

- Replace all default passwords:
  - AtroCore admin user.
  - PostgreSQL root password.
  - PostgreSQL application user password.
- Use a production `.env` outside Git; never commit secrets.
- Build from committed `composer.lock`; do not run `composer update` during production deploy.
- Validate backup and restore:
  - PostgreSQL dump.
  - `web-data` volume.
  - `upload-data` volume.
- Keep PostgreSQL private. Only expose HTTP/HTTPS ingress.
- Configure HTTPS for real production:
  - Domain + Traefik/Nginx on cloud or internal server.
  - Or a named Cloudflare Tunnel with Access policy if using Cloudflare for stable access.
- Run before every release:
  - `verification/smoke.ps1`
  - `verification/ui-export-acceptance.js`
  - `php console.php sql diff --show`
- Monitor after deploy:
  - AtroCore logs for fatal/error.
  - Docker logs for web/db.
  - Cron execution.
  - Disk usage for uploads and database volumes.

## Deployment Routes

- Local demo: Windows Docker Desktop + Cloudflare Quick Tunnel. Fastest, temporary, not production.
- Cloud server: Docker Compose + domain + HTTPS reverse proxy. Recommended for public production.
- Company intranet: Docker Compose behind internal DNS/reverse proxy. Recommended for internal-only production.

## Known Risks

- Default `admin/admin` must be changed before sharing any external URL.
- Quick Tunnel has no uptime guarantee.
- Direct `ExportFeed/action/exportData` logs a warning; use the Export Job path for production workflows.
