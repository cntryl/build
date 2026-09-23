# cntryl/build

Docker Compose configuration for running self-hosted GitHub Actions runners for the `cntryl` GitHub organization. The image is based on Ubuntu 24.04 and includes common project CI tools so workflows can build Rust, .NET, Go, and Node.js projects, as well as run Playwright tests with Chromium.

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

Edit `.env` as needed, then build and start the runners:

```sh
docker compose up --build -d
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
| `RUNNER_NAME` | Name assigned to each runner | Container hostname |
| `RUNNER_LABELS` | Comma-separated labels advertised to workflow routing | `ubuntu-24.04` |
| `RUNNER_VERSION` | GitHub Actions runner release installed in the image | `2.328.0` |
| `DOTNET_CHANNEL` | .NET SDK release channel | `10.0` |
| `GO_VERSION` | Go release installed in the image | `1.26.5` |
| `NODE_VERSION` | Node.js release installed in the image | `26.5.1` |

Compose sets `deploy.replicas` to `2`. `RUNNER_NAME` is passed unchanged to each replica, so leave it unset to use each container's unique hostname, or adjust the deployment configuration if you want fixed, distinct names.

## Files

- `Dockerfile` builds the runner image and installs its toolchains and browser dependencies.
- `compose.yml` configures the runner service, replicas, environment, and mounts.
- `entrypoint.sh` obtains a registration token and manages runner registration and shutdown.
- `.env.example` documents the local settings; copy it to the ignored `.env` file before starting.
