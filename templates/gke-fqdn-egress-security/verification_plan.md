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
    -   Apply the `FQDNNetworkPolicy` allowing `api.anthropic.com` and `huggingface.co`.
    -   Verify `curl https://api.anthropic.com` returns a successful response (likely a 401 or similar from the API, but not a connection timeout).
    -   Verify `curl https://huggingface.co` succeeds.
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
