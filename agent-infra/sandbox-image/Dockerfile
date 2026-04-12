FROM ghcr.io/gke-labs/gemini-for-kubernetes-development/generic-golang:latest

# Install HashiCorp Terraform
RUN apt-get update -qq && \
    apt-get install -y -qq gnupg software-properties-common lsb-release && \
    curl -fsSL https://apt.releases.hashicorp.com/gpg \
      | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
      https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
      > /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update -qq && \
    apt-get install -y -qq terraform && \
    terraform version

# Install Helm
RUN curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
      | HELM_INSTALL_DIR=/usr/local/bin bash && \
    helm version

# Install kubectl via gcloud components (requires gcloud to be present)
RUN gcloud components install kubectl --quiet && \
    kubectl version --client

# Install yq
RUN curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" \
      -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq && \
    yq --version

# Smoke test
RUN terraform version && helm version && kubectl version --client && yq --version
