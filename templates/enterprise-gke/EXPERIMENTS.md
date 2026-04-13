# Experiments Log

| Attempt | Change | CI Result | Hypothesis | Next step |
|---|---|---|---|---|
| 1 | Disable Binary Authorization (KCC), align CIDRs to Slot 1, unique master CIDR | ❌ failure | Immutable field error for master CIDR | Rename KCC cluster |
| 2 | Rename KCC cluster, use null_resource pattern for Helm | TBD | Renaming cluster allows master CIDR change; null_resource avoids unreachable cluster error | Push and verify |
