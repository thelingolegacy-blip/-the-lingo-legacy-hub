FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Install basic tools
RUN apt-get update && \
    apt-get install -y curl git build-essential python3 python3-pip ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Node.js 18
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create non-root vscode user if not present (devcontainer default)
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN id -u $USERNAME &>/dev/null || \
    (groupadd --gid $USER_GID $USERNAME || true && \
     useradd --uid $USER_UID --gid $USER_GID -m $USERNAME || true)

# Ensure scripts are in PATH
ENV PATH="/usr/local/bin:$PATH"
