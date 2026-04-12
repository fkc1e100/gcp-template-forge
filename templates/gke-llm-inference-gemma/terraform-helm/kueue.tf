# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Kueue installation
resource "helm_release" "kueue" {
  name             = "kueue"
  repository       = "oci://us-docker.pkg.dev/gke-release-packages/helm-charts"
  chart            = "kueue"
  version          = "0.9.1"
  namespace        = "kueue-system"
  create_namespace = true
}

# Kueue resources (ResourceFlavor, ClusterQueue, LocalQueue) via Helm
# to avoid plan-time connection issues with kubernetes_manifest.
resource "helm_release" "kueue_resources" {
  name       = "kueue-resources"
  chart      = "${path.module}/kueue-chart"
  namespace  = "kueue-system" # Cluster-wide resources like ClusterQueue can go here
  depends_on = [helm_release.kueue]
}
