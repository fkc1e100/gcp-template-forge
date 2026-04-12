# Kueue installation
resource "helm_release" "kueue" {
  name             = "kueue"
  repository       = "oci://us-docker.pkg.dev/gke-release-packages/helm-charts"
  chart            = "kueue"
  version          = "0.9.1"
  namespace        = "kueue-system"
  create_namespace = true
}

# ResourceFlavor for L4 GPUs
resource "kubernetes_manifest" "l4_flavor" {
  manifest = {
    apiVersion = "kueue.x-k8s.io/v1beta1"
    kind       = "ResourceFlavor"
    metadata = {
      name = "l4-flavor"
    }
    spec = {
      nodeLabels = {
        "nvidia.com/gpu" = "present"
      }
    }
  }
  depends_on = [helm_release.kueue]
}

# ClusterQueue
resource "kubernetes_manifest" "cluster_queue" {
  manifest = {
    apiVersion = "kueue.x-k8s.io/v1beta1"
    kind       = "ClusterQueue"
    metadata = {
      name = "cluster-queue"
    }
    spec = {
      namespaceSelector = {}
      resourceGroups = [
        {
          coveredResources = ["nvidia.com/gpu"]
          flavors = [
            {
              name = "l4-flavor"
              resources = [
                {
                  name         = "nvidia.com/gpu"
                  nominalQuota = "1"
                }
              ]
            }
          ]
        }
      ]
    }
  }
  depends_on = [kubernetes_manifest.l4_flavor]
}

# LocalQueue in gemma namespace
resource "kubernetes_manifest" "local_queue" {
  manifest = {
    apiVersion = "kueue.x-k8s.io/v1beta1"
    kind       = "LocalQueue"
    metadata = {
      name      = "local-queue"
      namespace = "gemma"
    }
    spec = {
      clusterQueue = "cluster-queue"
    }
  }
  depends_on = [kubernetes_manifest.cluster_queue, helm_release.workload]
}
