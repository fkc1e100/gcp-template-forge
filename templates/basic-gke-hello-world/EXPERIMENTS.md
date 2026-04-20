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

# Experiments Log - basic-gke-hello-world

| Attempt | Change | CI Result | Hypothesis | Next step |
|---|---|---|---|---|
| 1 | Initial setup | ❌ Timeout | GKE Standard might be more reliable than Autopilot | Convert to Standard |
| 2 | Convert to Standard, rename KCC to -v2 | ❌ CI Fail | Install gke-gcloud-auth-plugin failed | Fix workflow repo |
| 3 | Fix workflow repo | ✅ Success | Repo fix resolves CI | Add KCC workload manifest |
| 4 | Add KCC workload manifest & sync labels | ✅ Success | Explicit workload manifest provides parity | Final naming sync |
| 5 | Sync KCC resource naming with template | ✅ Success | Prefixed names enable dynamic CI runs | PR Ready |
| 6 | Final sync of resource labels and provider cleanup | ✅ Success | Full parity and clean configuration | Merge |
| 7 | Final compliance check and label synchronization | ✅ Success | Ensured full adherence to 2026 mandates and label parity | PR Ready |
| 8 | Add missing --project flags to gcloud commands | ✅ Success | Aligned with best practices and confirmed consistency | Final Review |
