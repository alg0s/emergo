# emergo

Simple static site deployed to a Hetzner VPS.

## Local Deploy

```bash
DEPLOY_HOST=5.223.51.101 DEPLOY_USER=openclawuser ./scripts/deploy.sh
```

Optional:

```bash
DEPLOY_PORT=22 DEPLOY_PATH=/var/www/html ./scripts/deploy.sh
```

## GitHub Actions Deploy

Push to `main` to auto-deploy. Required repo secrets:

- `ACTIONS_DEPLOY_KEY` (private SSH key for GitHub Actions)
- `VPS_HOST`
- `VPS_USER`
- `VPS_PORT`
- `VPS_KNOWN_HOSTS` (output of `ssh-keyscan -H <host>`)
