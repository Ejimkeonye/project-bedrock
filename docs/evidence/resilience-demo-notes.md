# Resilience Demo (Bonus 5.5)

## Test
Deleted the `ui` pod (`ui-6f577c4998-bvclt`) in the `retail-app` namespace to simulate
an unexpected pod failure, and observed Kubernetes' self-healing behavior.

## Timeline
- 0s: Pod deleted
- 5s: Replacement pod `ui-6f577c4998-n87jc` enters `ContainerCreating`
- 12s: Container running, not yet passing readiness probe
- 34s: Pod fully `Running 1/1` and back in service

**Total recovery time: ~34 seconds**, with zero manual intervention — the Deployment's
ReplicaSet controller detected the missing pod and rescheduled it automatically,
landing on a different node (`ip-10-0-10-77` vs original `ip-10-0-11-55`).

## Backup retention
Both RDS instances (`bedrock-catalog-mysql`, `bedrock-orders-postgres`) are configured
with `backup_retention_period = 7` (bumped from the default single-day retention) to
allow point-in-time recovery over a full week.

See `docs/evidence/before.txt` and `docs/evidence/after.txt` for raw pod state.
