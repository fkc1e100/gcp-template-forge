FROM ghcr.io/gke-labs/gemini-for-kubernetes-development/generic-golang:latest

# Install HashiCorp Terraform (binary download — no lsb_release/apt repo needed)
RUN apt-get update -qq && apt-get install -y -qq unzip && \
    TF_VER="1.7.0" && \
    curl -fsSL "https://releases.hashicorp.com/terraform/${TF_VER}/terraform_${TF_VER}_linux_amd64.zip" \
      -o /tmp/terraform.zip && \
    unzip -q /tmp/terraform.zip -d /usr/local/bin/ && \
    rm /tmp/terraform.zip && \
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
