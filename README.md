# cntryl/build

Docker Compose configuration for running self-hosted GitHub Actions runners for the `cntryl` GitHub organization. The published OCI image is `ghcr.io/cntryl/build`, based on Ubuntu 24.04, with common project CI tools for Rust, .NET, Go, Node.js, and Playwright tests with Chromium.

## What it provides

- GitHub Actions runner, with version configurable through `RUNNER_VERSION`.
- Stable Rust with `clippy` and `rustfmt`.
- .NET SDK from the configurable `DOTNET_CHANNEL`.
- Pinned Go and Node.js releases.
- Playwright Test and Chromium.
- Docker CLI and access to the host Docker daemon through `/var/run/docker.sock`.
- Two runner replicas in the Compose deployment configuration.

The runner registers with `https://github.com/cntryl` at startup. `entrypoint.sh` exchanges the organization token for a short-lived registration token, configures the runner, and removes its registration when it shuts down cleanly.

## Requirements

- Docker Engine with Docker Compose.
- A GitHub personal access token with permission to create organization runner registration tokens for `cntryl`.

The runner mounts the host Docker socket. Workflows running on it can control the host Docker daemon, so use this setup only for repositories and workflows you trust.

## Configure and start

Create a local environment file from the example and set `GITHUB_TOKEN` to your token:

```sh
cp .env.example .env
```

Edit `.env` and start the published image:

```sh
docker compose pull
docker compose up -d
```

The default image tag is `latest`, published from `main`. Set `IMAGE_TAG` in `.env` to a release such as `1.2.3` to run that version. The GHCR package must be public for unauthenticated pulls; if it is private, authenticate first with `docker login ghcr.io` using a token with `read:packages`.

The Compose service used above is defined in `compose.yml`. To copy it into another deployment, use:

```yaml
services:
  runner:
    image: ghcr.io/cntryl/build:${IMAGE_TAG:-latest}
    deploy:
      replicas: 2
    environment:
      GITHUB_TOKEN: ${GITHUB_TOKEN:?Set GITHUB_TOKEN in the environment}
      RUNNER_NAME: ${RUNNER_NAME:-}
      RUNNER_LABELS: ${RUNNER_LABELS:-ubuntu-24.04}
    volumes:
      - /runner/_work
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped
```

Set `GITHUB_TOKEN` in the environment or `.env` file before starting. It is used only to request a short-lived runner registration token. The token needs organization runner registration permission for `cntryl`.

For a build from this source checkout, use the local build override instead:

```sh
docker compose -f compose.yml -f compose.build.yml up --build -d
```

View runner logs and stop the deployment with:

```sh
docker compose logs -f runner
docker compose down
```

The `.env` file is ignored by Git. Do not commit credentials.

## Configuration

`.env.example` lists the supported Compose settings:

| Variable | Purpose | Default |
| --- | --- | --- |
| `GITHUB_TOKEN` | Organization token used to request a runner registration token | Required |
| `IMAGE_TAG` | Published GHCR image tag | `latest` |
| `RUNNER_NAME` | Name assigned to each runner | Container hostname |
| `RUNNER_LABELS` | Comma-separated labels advertised to workflow routing | `ubuntu-24.04` |
| `RUNNER_VERSION` | GitHub Actions runner release installed in the image | `2.328.0` |
| `DOTNET_CHANNEL` | .NET SDK release channel | `10.0` |
| `GO_VERSION` | Go release installed in the image | `1.26.5` |
| `NODE_VERSION` | Node.js release installed in the image | `26.5.1` |

Compose sets `deploy.replicas` to `2`. `RUNNER_NAME` is passed unchanged to each replica, so leave it unset to use each container's unique hostname, or adjust the deployment configuration if you want fixed, distinct names.

## CI and image publishing

`ci.yml` checks shell syntax, Compose configuration, and builds the image on GitHub-hosted runners for pull requests and pushes to `main`. `containers.yml` builds `linux/amd64` and `linux/arm64` on separate native GitHub-hosted runners, then merges their pushed digests into a multi-architecture OCI manifest at `ghcr.io/cntryl/build`. It runs on pushes to `main` and version tags named `v*`. A `main` push publishes the `main` and `latest` tags; a release such as `v1.2.3` publishes `v1.2.3`, `1.2.3`, and `1.2` tags. The publisher uses `GITHUB_TOKEN` with package write permission.

## Files

- `Dockerfile` builds the runner image and installs its toolchains and browser dependencies.
- `compose.yml` runs the published GHCR image; `compose.build.yml` enables local builds.
- `.github/workflows/` contains CI checks and the GHCR publisher.
- `entrypoint.sh` obtains a registration token and manages runner registration and shutdown.
- `.env.example` documents the local settings; copy it to the ignored `.env` file before starting.
