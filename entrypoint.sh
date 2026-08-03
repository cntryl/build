#!/usr/bin/env bash
set -euo pipefail

# The Docker socket's group is supplied by the host, so its GID is discovered
# at runtime before dropping privileges to the runner user.
if [[ "$(id -u)" == 0 ]]; then
  if [[ -S /var/run/docker.sock ]]; then
    socket_gid="$(stat -c '%g' /var/run/docker.sock)"
    socket_group="$(getent group "$socket_gid" | cut -d: -f1 || true)"
    if [[ -z "$socket_group" ]]; then
      socket_group=hostdocker
      groupadd --gid "$socket_gid" "$socket_group"
    fi
    usermod --append --groups "$socket_group" runner
  fi
  install --directory --owner=runner --group=runner "${RUNNER_HOME:-/runner}/_work"
  exec gosu runner "$0" "$@"
fi

: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
org_url=https://github.com/cntryl
github_org=cntryl
RUNNER_TOKEN="$(curl --fail --silent --show-error \
  --request POST \
  --header 'Accept: application/vnd.github+json' \
  --header "Authorization: Bearer ${GITHUB_TOKEN}" \
  --header 'X-GitHub-Api-Version: 2026-03-10' \
  "https://api.github.com/orgs/${github_org}/actions/runners/registration-token" \
  | jq --raw-output '.token')"
[[ -n "$RUNNER_TOKEN" && "$RUNNER_TOKEN" != "null" ]] || {
  echo "GitHub returned an empty runner registration token" >&2
  exit 1
}
unset GITHUB_TOKEN

runner_name="${RUNNER_NAME:-$(hostname)}"
runner_labels="${RUNNER_LABELS:-}"
configured=0
runner_pid=""

cleanup() {
  if [[ "$configured" == 1 ]]; then
    ./config.sh remove --unattended --token "$RUNNER_TOKEN" || true
  fi
}

on_signal() {
  if [[ -n "$runner_pid" ]] && kill -0 "$runner_pid" 2>/dev/null; then
    kill -TERM "$runner_pid" 2>/dev/null || true
    wait "$runner_pid" || true
  fi
  exit 143
}

trap cleanup EXIT
trap on_signal INT TERM

config_args=(
  --unattended
  --url "$org_url"
  --token "$RUNNER_TOKEN"
  --name "$runner_name"
  --replace
  --work _work
)
if [[ -n "$runner_labels" ]]; then
  config_args+=(--labels "$runner_labels")
fi

./config.sh "${config_args[@]}"
configured=1
./run.sh &
runner_pid=$!
wait "$runner_pid"
