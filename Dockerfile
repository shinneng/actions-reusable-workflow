# Stage 1: Pull GitOps binaries from reliable upstream source images
FROM line/kubectl-kustomize:1.34.1-5.7.1 AS k8s-source
FROM fluxcd/flux-cli:v2.7.5 AS flux-source

# Stage 2: Target the official GitHub Actions Runner base image
FROM ghcr.io/actions/actions-runner:2.329.0

# Switch to root to perform software installation
USER root

# Clean apt cache and install prerequisites + official GitHub CLI
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gnupg \
    openssh-client \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Copy binaries into the global system path from the multi-stage builds
COPY --from=k8s-source /usr/local/bin/kubectl /usr/local/bin/kubectl
COPY --from=k8s-source /usr/local/bin/kustomize /usr/local/bin/kustomize
COPY --from=flux-source /flux /usr/local/bin/flux

# Ensure all binaries have the correct execution permissions
RUN chmod +x /usr/local/bin/kubectl /usr/local/bin/kustomize /usr/local/bin/flux /usr/bin/gh

# Verify the installations work properly
RUN kubectl version --client && \
    kustomize version && \
    flux --version && \
    gh --version

# CRITICAL: Always switch back to the non-root runner user 
USER runner
