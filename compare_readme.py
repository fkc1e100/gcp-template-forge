
import re

template_path = 'agent-infra/scaffolds/README.template.md'
readme_path = 'templates/basic-gke-hello-world/README.md'

with open(template_path, 'r') as f:
    template = f.read()

# Placeholders to replace
replacements = {
    '{{DISPLAY_NAME}}': 'Basic GKE Hello World',
    '{{ONE_LINE_DESCRIPTION}}': 'A minimal GKE Standard cluster deploying a Hello World web service via Helm (terraform-helm path) and Config Connector (config-connector path). Exposes the workload via a LoadBalancer Service and validates via HTTP endpoint.',
    '{{DESCRIBE_THE_ARCHITECTURE_HERE}}': 'This template provides a foundational GKE Standard architecture. It includes a VPC with secondary ranges for Pods and Services, a regional GKE Standard cluster with a single Spot node pool for cost-efficiency, and a simple Hello World workload exposed via a LoadBalancer.',
    '{{REGION}}': 'us-central1',
    '{{CLUSTER_TYPE}}': 'Standard',
    '{{SHORT_NAME}}': 'gke-basic',
    '{{NODE_POOL_DESCRIPTION}}': '1x e2-standard-2 Spot node pool',
    '{{WORKLOAD_DESCRIPTION}}': "Hello World workload (Google's `hello-app` container)",
    '{{NODE_POOL_TYPE}}': 'Spot',
    '{{NODE_COUNT}}': '1',
    '{{MACHINE_TYPE}}': 'e2-standard-2',
    '{{NODE_COST}}': '15',
    '{{TOTAL_COST}}': '108',
    '{{TEMPLATE_DIR}}': 'basic-gke-hello-world',
    '{{TEMPLATE_NAME}}': 'Basic GKE Hello World',
    '{{KCC_LIMITATIONS_SECTION}}': '{{KCC_LIMITATIONS_SECTION}}' # Keep it as is for comparison
}

for k, v in replacements.items():
    template = template.replace(k, v)

with open('/tmp/rendered_template.md', 'w') as f:
    f.write(template)
