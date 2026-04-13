# Experiments Log

| Attempt | Change | CI Result | Hypothesis | Next step |
|---|---|---|---|---|
| 1 | Move removeDefaultNodePool to annotations in KCC | ❌ failure | TF provider version mismatch and unreachable cluster error | Fix version and use null_resource |
| 2 | Pin google provider ~> 6.0, use null_resource for Helm | TBD | Correct version and robust Helm auth should fix TF apply | Push and verify |
