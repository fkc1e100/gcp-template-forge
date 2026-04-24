# Verification Plan: GKE FQDN Network Policies

This plan outlines the steps to verify the implementation of GKE FQDN Network Policies for secure AI egress.

## Prerequisites
- GCP Project with GKE Enterprise enabled (or trial).
- Terraform and kubectl installed.

## Infrastructure Verification
1.  **Dataplane V2:** Ensure the cluster is created with `datapathProvider: ADVANCED_DATAPATH`.
2.  **FQDN Policy Flag:** Ensure `enableFqdnNetworkPolicy: true` is set in the cluster configuration.
3.  **Network Topology:** Verify private nodes are used with Cloud NAT for external access.

## Workload Verification
1.  **Default Deny:**
    -   Apply the `NetworkPolicy` that denies all egress for pods labeled `app: egress-test`.
    -   Verify that without any other policies, all external `curl` commands fail.
2.  **FQDN Allow-list:**
    -   Apply the `FQDNNetworkPolicy` allowing `anthropic.com`, `api.anthropic.com`, `huggingface.co`, and `hf.co`.
    -   Verify `curl https://anthropic.com`, `curl https://www.anthropic.com`, and `curl https://api.anthropic.com` return successful responses (not a connection timeout).
    -   Verify `curl https://huggingface.co`, `curl https://api.huggingface.co`, `curl https://hf.co`, and `curl https://www.hf.co` succeed.
    -   Verify `curl https://google.com` is actively blocked by the CNI.

## Automated Validation
Run the provided `validate.sh` script which automates these checks:
```bash
./validate.sh
```

## Success Criteria
- Cluster has Dataplane V2 and FQDN policies enabled.
- `FQDNNetworkPolicy` resource is successfully admitted by the GKE control plane.
- Egress to allowed FQDNs is successful.
- Egress to non-allowed FQDNs is blocked.
