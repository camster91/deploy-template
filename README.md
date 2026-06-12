# camster91 deploy template

Reusable GitHub Actions workflows and scripts for deploying any camster91/* web app.

## What's here

```
.github/workflows/
  build-and-push.yml     # Build Docker image, push to ghcr.io/camster91/<repo>
  deploy.yml             # Pull the image, run it on any host
Dockerfile.template      # Generic multi-stage Node Dockerfile (npm + pnpm)
deploy.sh                # Portable shell script for any Docker host
```

## The pattern

```
push to main
  ↓
[GH Actions] build-and-push.yml
  ↓ builds Dockerfile in this repo
  ↓ tags as :main, :main-<sha>, :latest
  ↓ multi-arch linux/amd64 + linux/arm64
  ↓
[GHCR] ghcr.io/camster91/<repo>:main
  ↓
[GH Actions] deploy.yml (or manual `deploy.sh` on the host)
  ↓
any Docker host pulls and runs:
  docker run -d -p 3000:3000 --name <repo> ghcr.io/camster91/<repo>:main
```

The image is the deployable. The host doesn't need source, Node, npm, pnpm, or any build tools.

## Adopting this template in a new repo

1. **Copy the workflows:**
   ```bash
   cd camster91/<your-repo>
   mkdir -p .github/workflows
   cp <this-repo>/.github/workflows/build-and-push.yml .github/workflows/
   cp <this-repo>/.github/workflows/deploy.yml .github/workflows/
   ```

2. **Add a Dockerfile** to your repo. Either:
   - Hand-write one (see `Dockerfile.template` for the multi-stage pattern)
   - Copy from `animal-farts/Dockerfile`, `lull/Dockerfile`, or `creative-studio/Dockerfile` and adapt the port

3. **Add the deploy script** (optional — for manual deploys on a Docker host):
   ```bash
   cp <this-repo>/deploy.sh ./
   chmod +x deploy.sh
   ```

4. **Test the build:**
   ```bash
   git add . && git commit -m "Add deploy template"
   git push
   # Watch the build in GitHub Actions
   ```

5. **Test the deploy** by pulling and running the image:
   ```bash
   docker pull ghcr.io/camster91/<repo>:main
   docker run -d -p 3000:3000 --name <repo> ghcr.io/camster91/<repo>:main
   ```

## Deploying to specific targets

### Coolify (your existing VPS)
- Add webhook URL as `COOLIFY_WEBHOOK_URL` secret in repo settings
- Coolify's existing service pulls the new image and restarts

### Hostinger VPS
- Same as any Docker host: install Docker, run `./deploy.sh <repo>`

### Hostinger Node.js hosting (no Docker)
- Use their Git integration: point at this repo, branch=main, build=`npm run build`, start=`npm start`
- Or publish the static `dist/` to GH Pages and let their CDN serve it

### Render / Fly.io / Railway
- Connect the GitHub repo, set image pull policy to `ghcr.io/camster91/<repo>:main`
- Set the appropriate env vars on their dashboard

### Local Docker
- `git clone` this repo, `./deploy.sh <repo-name>`

## Secrets (set in repo Settings → Secrets and variables → Actions)

| Secret | When to set | Used for |
|---|---|---|
| `COOLIFY_WEBHOOK_URL` | If using Coolify | Triggers redeploy on push |
| `DEPLOY_HOST` | If using SSH deploy | Hostname/IP of the target |
| `DEPLOY_SSH_USER` | If using SSH deploy | Default: root |
| `DEPLOY_HOST_SSH_KEY` | If using SSH deploy | Private SSH key with access to DEPLOY_HOST |
| `HOSTINGER_FTP_*` | If deploying to Hostinger shared hosting | For static site deploys |

Most of these are optional. The image publishes to GHCR unconditionally; only the deploy step needs secrets.

## Image tags

Every push to main creates three tags:
- `:main` — the latest from main
- `:main-<7char-sha>` — pinned to a specific commit, for rollback
- `:latest` — same as main (for hosts that always pull :latest)

Every git tag `v*` (e.g., `v1.2.0`) creates a release tag.

## Cache

- Docker layer cache lives in `/tmp/.buildx-cache` on the runner
- GitHub Actions cache key includes the branch name, so main-branch builds reuse each other's cache
- Cold cache: ~5-8 min for a typical Vite/Express app
- Warm cache: ~1-2 min

## Migration from old deploy.yml

If you have an existing `deploy.yml` that SSHes to a specific host:

1. Keep the old file for one deploy cycle
2. Add `build-and-push.yml` to `.github/workflows/`
3. Wait for it to push an image to GHCR (verify at https://github.com/camster91/<repo>/pkgs/container/<repo>)
4. Add `deploy.yml` from this template
5. Disable the old file: rename it to `deploy.yml.disabled` (GitHub ignores non-`.yml` files)
6. Now you can deploy to ANY host by pulling the image
