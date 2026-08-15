# Cluster Autoscaler Scale-Up Demo

**Trigger:** `kubectl scale deployment ui -n retail-app --replicas=10`

**Before:** 2 nodes (project-bedrock-nodes desired=2)

**Observed:**
- New node ip-10-0-10-9.ec2.internal appeared as NotReady immediately after scale command
- Reached Ready status ~19-21s after first appearing
- All 10 ui pods scheduled successfully (1/1 Running) across the 3 nodes

**After:** 3 nodes total

**Note:** IMDS hop limit had to be raised from 1 to 2 on running node instances
(`aws ec2 modify-instance-metadata-options --http-put-response-hop-limit 2`)
for the autoscaler pod to reach instance credentials via IMDS. This is a
known EKS managed-node-group default; a permanent fix would set
`http_put_response_hop_limit = 2` in a custom launch template attached to
the Terraform node group resource — not yet applied here.
