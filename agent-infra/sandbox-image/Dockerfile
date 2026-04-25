FROM ghcr.io/gke-labs/gemini-for-kubernetes-development/generic-golang:latest

# Install HashiCorp Terraform (binary download — no lsb_release/apt repo needed)
RUN apt-get update -qq && apt-get install -y -qq unzip && \
    TF_VER=$(curl -fsSL https://api.releases.hashicorp.com/v1/releases/terraform/latest \
      | python3 -c "import json,sys; print(json.load(sys.stdin)['version'])") && \
    curl -fsSL "https://releases.hashicorp.com/terraform/${TF_VER}/terraform_${TF_VER}_linux_amd64.zip" \
      -o /tmp/terraform.zip && \
    unzip -q /tmp/terraform.zip -d /usr/local/bin/ && \
    rm /tmp/terraform.zip && \
    terraform version

# Install Helm (direct binary download for better security)
RUN HELM_VER=$(curl -fsSL https://api.github.com/repos/helm/helm/releases/latest | python3 -c "import json,sys; print(json.load(sys.stdin)['tag_name'])") && \
    curl -fsSL "https://get.helm.sh/helm-${HELM_VER}-linux-amd64.tar.gz" -o /tmp/helm.tar.gz && \
    tar -zxvf /tmp/helm.tar.gz -C /tmp && \
    mv /tmp/linux-amd64/helm /usr/local/bin/helm && \
    rm -rf /tmp/helm.tar.gz /tmp/linux-amd64 && \
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
