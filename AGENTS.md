# Repository Guidelines

## Project Structure

This repository builds and runs self-hosted GitHub Actions runners for the `cntryl` organization. It is intentionally small: `Dockerfile` defines the Ubuntu-based runner image and installed toolchains, `compose.yml` configures the service and replicas, and `entrypoint.sh` registers and starts each runner. `.env.example` documents local settings; copy it to the ignored `.env` file. There are currently no application source directories, test suites, or separate assets.

## Build and Development Commands

- `docker compose build` builds the runner image using the versions configured in `.env` or Compose defaults.
- `docker compose up --build -d` builds and starts the configured runner replicas.
- `docker compose logs -f runner` follows runner startup and job logs.
- `docker compose down` stops and removes the Compose service.

Set `GITHUB_TOKEN` in `.env` before starting. The entrypoint exchanges it for a short-lived registration token. Never commit `.env` or paste credentials into logs or pull requests.

## Style and Configuration

Keep shell code compatible with Bash and use `set -euo pipefail` for scripts. Use two-space indentation in shell and YAML, quote shell expansions, and keep Dockerfile installation steps explicit and version-configurable where practical. Keep Compose environment defaults aligned with `.env.example` and describe any new setting there and in `README.md`.

## Testing and Validation

No automated test suite or formatter is configured. Before proposing changes, validate Compose syntax and configuration with `docker compose config`; for image or startup changes, build with `docker compose build`. Avoid running a live runner unless you have a valid organization token and intend to register it.

## Commits and Pull Requests

Recent commits use short, imperative subjects, for example, “Update Rust installation in Dockerfile…” and “Add Docker setup…”. Follow that pattern and keep each commit focused. Pull requests should explain the operational effect, list relevant configuration or version changes, and include the validation commands and outcomes. Do not include tokens or other secrets.

## Security and Runtime Notes

The runner mounts `/var/run/docker.sock`, which lets workflows control the host Docker daemon. Treat workflows and repositories assigned to these runners as trusted. The container starts as root only to set Docker socket group access, then runs the GitHub runner as the non-root `runner` user; preserve this privilege drop when changing startup behavior.
