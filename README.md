# Company AtroCore Project

Dockerized AtroCore/AtroPIM project for long-term customization. Business code belongs in the `MyCompany` module, not in `vendor/atrocore/*` or inside a running container.

## Local development

Requirements:

- Docker Desktop
- Git
- PowerShell

Start the stack:

```powershell
Copy-Item .env.example .env
powershell -ExecutionPolicy Bypass -File .\scripts\dev-up.ps1 -Build
```

By default local development uses `.docker/php/Dockerfile.local`, which reuses the already built AtroCore Docker image when it exists. For an independent full build, set `DOCKERFILE=.docker/php/Dockerfile` in `.env`.

Open:

- Web: http://localhost:8080/
- Default local login after installer/demo setup: `admin/admin`

On a brand-new database, the first page is the AtroCore installer. Complete the installer once to create schema and the admin user. After that, smoke verification can run the login/API checks.

Stop the stack:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev-down.ps1
```

Remove local database and upload volumes:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev-down.ps1 -Volumes
```

## Project structure

- `composer.json` and `composer.lock` lock AtroCore, AtroPIM, Import and Export dependencies.
- `custom/MyCompany` is the project-specific custom module.
- `.docker` contains the PHP/Apache image, runtime startup and database initialization.
- `scripts` contains local development and operational helper commands.
- `verification` contains smoke checks.

## Custom development rules

Put business customization in `custom/MyCompany`:

- PHP classes under `custom/MyCompany/app`
- metadata, layouts and language files under `custom/MyCompany/app/Resources`
- migrations under `custom/MyCompany/app/Migrations`
- frontend files under `custom/MyCompany/client`

Do not directly edit `vendor/atrocore/*`. If core behavior must be changed, fork the affected Composer package and point `composer.json` to that fork.

## Composer workflow

For production and repeatable deployments, use the lock file:

```bash
composer install --no-dev --optimize-autoloader
```

Use `composer update` only during planned dependency upgrades, then commit the changed `composer.lock` after testing.

## Useful commands

Run an AtroCore console command:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\console.ps1 sql diff --show
```

Follow logs:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev-logs.ps1 web
```

Create backups:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\backup.ps1
```

Run smoke verification:

```powershell
powershell -ExecutionPolicy Bypass -File .\verification\smoke.ps1
```

If you run on the local `8081` test port used during scaffolding:

```powershell
powershell -ExecutionPolicy Bypass -File .\verification\smoke.ps1 -BaseUrl http://localhost:8081
```

## Temporary external demo access

For a temporary external URL without a domain or router port forwarding, run a Cloudflare Quick Tunnel through Docker:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\tunnel-quick.ps1
```

The script prints a temporary `https://*.trycloudflare.com` URL that forwards to the local Docker `web` service. Keep the tunnel container running while the URL is needed.

Stop the tunnel:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\tunnel-stop.ps1
```

Before sharing the URL outside your machine, change the default `admin/admin` password. Quick Tunnel URLs are temporary and can change every time the tunnel is restarted.

## Deployment outline

1. Back up PostgreSQL and uploads.
2. Pull the target Git revision.
3. Build the image from this repository.
4. Start `web` and `db`.
5. Run module synchronization and schema checks.
6. Run smoke verification.
7. Check application logs for fatal errors.

## Files that must not be committed

- `.env`
- `vendor/`
- `data/`
- `upload/`
- logs, caches, backups and database volume data
