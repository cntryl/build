FROM ubuntu:24.04

ARG TARGETARCH
ARG RUNNER_VERSION=2.328.0
ARG DOTNET_CHANNEL=10.0
ARG GO_VERSION=1.26.5
ARG NODE_VERSION=26.5.1
ARG PLAYWRIGHT_VERSION=1.62.1

# Keep Rust's default/test builds below the memory ceiling of the runner.
# A single codegen unit is unnecessarily peak-memory-heavy for CI.
ENV DEBIAN_FRONTEND=noninteractive \
    RUNNER_HOME=/runner \
    CARGO_HOME=/opt/rust/cargo \
    RUSTUP_HOME=/opt/rust/rustup \
    DOTNET_ROOT=/usr/share/dotnet \
    GOROOT=/usr/local/go \
    NODE_HOME=/usr/local/node \
    CARGO_BUILD_JOBS=2 \
    CARGO_PROFILE_DEV_CODEGEN_UNITS=16 \
    CARGO_PROFILE_DEV_DEBUG=0 \
    CARGO_PROFILE_DEV_OPT_LEVEL=0 \
    PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers \
    PATH=/opt/rust/cargo/bin:/usr/local/go/bin:/usr/local/node/bin:${PATH}

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
        ca-certificates \
        curl \
        git \
        jq \
        build-essential \
        pkg-config \
        tar \
        gzip \
        unzip \
        gosu \
        sudo \
        libicu74 \
        docker.io \
    && rm -rf /var/lib/apt/lists/*

# Download the pinned runner release and install its distribution-specific dependencies.
RUN case "${TARGETARCH:-amd64}" in \
      amd64) runner_arch=x64 ;; \
      arm64) runner_arch=arm64 ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && mkdir -p "${RUNNER_HOME}" \
    && curl --fail --location --retry 3 --output /tmp/actions-runner.tar.gz \
         "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${runner_arch}-${RUNNER_VERSION}.tar.gz" \
    && tar -xzf /tmp/actions-runner.tar.gz -C "${RUNNER_HOME}" \
    && rm /tmp/actions-runner.tar.gz \
    && "${RUNNER_HOME}/bin/installdependencies.sh" \
    && rm -rf /var/lib/apt/lists/* \
    && chown -R root:root "${RUNNER_HOME}"

# Install the stable Rust toolchain and the CI components used by Rust projects.
RUN mkdir -p /opt/rust \
    && curl --fail --location --retry 3 https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable \
    && rustup component add clippy rustfmt \
    && rustup update stable

# Install the .NET SDK for the selected release channel.
RUN curl --fail --location --retry 3 --output /tmp/dotnet-install.sh \
      https://dot.net/v1/dotnet-install.sh \
    && bash /tmp/dotnet-install.sh \
      --channel "${DOTNET_CHANNEL}" \
      --install-dir /usr/share/dotnet \
      --no-path \
    && rm /tmp/dotnet-install.sh \
    && ln -sf /usr/share/dotnet/dotnet /usr/local/bin/dotnet

# Install the pinned Go release for the target architecture.
RUN case "${TARGETARCH:-amd64}" in \
      amd64) go_arch=amd64 ;; \
      arm64) go_arch=arm64 ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && curl --fail --location --retry 3 --output /tmp/go.tar.gz \
      "https://go.dev/dl/go${GO_VERSION}.linux-${go_arch}.tar.gz" \
    && rm -rf /usr/local/go \
    && tar -xzf /tmp/go.tar.gz -C /usr/local \
    && rm /tmp/go.tar.gz

# Install the latest Node.js release with npm and npx.
RUN case "${TARGETARCH:-amd64}" in \
      amd64) node_arch=x64 ;; \
      arm64) node_arch=arm64 ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && curl --fail --location --retry 3 --output /tmp/node.tar.gz \
      "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.gz" \
    && rm -rf "${NODE_HOME}" \
    && mkdir -p "${NODE_HOME}" \
    && tar -xzf /tmp/node.tar.gz --strip-components=1 -C "${NODE_HOME}" \
    && rm /tmp/node.tar.gz

# Keep browser-based CI self-contained.  The shared browser path is readable
# by the non-root runner user and matches Playwright's cache contract.
RUN mkdir -p "${PLAYWRIGHT_BROWSERS_PATH}" \
    && npm install --global --omit=dev "@playwright/test@${PLAYWRIGHT_VERSION}" \
    && playwright install --with-deps chromium \
    && chmod -R a+rX "${PLAYWRIGHT_BROWSERS_PATH}"

COPY entrypoint.sh /entrypoint.sh
RUN chmod 0755 /entrypoint.sh

# GitHub's runner refuses to start as root. Keep image bootstrap-capable, but
# run the actual runner process as a dedicated non-root user. Playwright's
# --with-deps invokes sudo for apt-get; this runner already has Docker-socket
# host access, so non-interactive sudo avoids a password prompt.
RUN useradd --create-home --home-dir "${RUNNER_HOME}" --shell /bin/bash runner \
    && mkdir -p "${RUNNER_HOME}/_work" \
    && chown -R runner:runner "${RUNNER_HOME}" /opt/rust "${PLAYWRIGHT_BROWSERS_PATH}" \
    && printf '%s\n' 'runner ALL=(root) NOPASSWD: ALL' > /etc/sudoers.d/runner \
    && chmod 0440 /etc/sudoers.d/runner \
    && visudo --check --file=/etc/sudoers.d/runner

WORKDIR ${RUNNER_HOME}
# Entrypoint bootstraps socket permissions as root, then drops to `runner`.
ENTRYPOINT ["/entrypoint.sh"]
