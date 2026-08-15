# Project Bedrock

InnovateMart Inc. — Production-grade EKS deployment (AltSchool Tinyuka 2025, Third Semester Capstone)

Provisions a secure Amazon EKS cluster and deploys the [retail-store-sample-app](https://github.com/aws-containers/retail-store-sample-app) with managed AWS data services, secured developer access, full observability, an event-driven S3→Lambda extension, and automated CI/CD.

---

## ⚠️ Grader Note: Infrastructure Is Scaled to Zero

To control costs on a pay-as-you-go account, the EKS node group is scaled to `desiredSize=0` and both RDS instances are stopped between work sessions. **Before testing the live store URL, `kubectl` access, or the S3→Lambda trigger, scale the infrastructure back up:**

```bash
aws eks update-nodegroup-config \
  --cluster-name project-bedrock-cluster \
  --nodegroup-name project-bedrock-nodes \
  --scaling-config minSize=2,maxSize=4,desiredSize=2 \
  --region us-east-1

aws rds start-db-instance --db-instance-identifier bedrock-catalog-mysql --region us-east-1
aws rds start-db-instance --db-instance-identifier bedrock-orders-postgres --region us-east-1
```

Allow 3–5 minutes for nodes to join and RDS instances to become available. The `bedrock-dev-view` grading user has **read-only** access and cannot run these commands — they require admin credentials.

---

## Architecture

See `docs/architecture.png` for the full diagram (VPC/subnet layout, EKS cluster, managed data layer, ALB ingress, S3→Lambda flow).

**Region:** us-east-1
**EKS Cluster:** `project-bedrock-cluster`
**VPC:** `project-bedrock-vpc` (10.0.0.0/16), public + private subnets across 2 AZs, single shared NAT Gateway
**Data layer:** RDS MySQL (`bedrock-catalog-mysql`) for catalog, RDS PostgreSQL (`bedrock-orders-postgres`) for orders, DynamoDB (`bedrock-carts`) for carts — all replacing the Helm chart's default in-cluster databases
**In-cluster services:** RabbitMQ, Redis (Helm chart defaults, per spec)

## Repository Structure

```
project-bedrock/
├── terraform/
│   ├── envs/              # root module (main.tf, backend.tf, outputs.tf, grading.json)
│   └── modules/
│       ├── vpc/
│       ├── eks/
│       ├── rds/
│       ├── dynamodb/
│       ├── s3-lambda/
│       └── iam-dev-user/
├── k8s/
│   ├── base/               # namespace, ingress, network policies
│   └── helm-values/        # values.yaml overriding the data layer
├── eks-charts/              # vendored/local Helm chart used for deployment (bonus 5.1)
├── lambda/                  # S3 event → CloudWatch log function
├── .github/workflows/       # Terraform CI/CD (plan on PR, apply on merge)
└── docs/
    ├── architecture.png
    └── evidence/             # bonus objective evidence (autoscaler, resilience, TLS demos)
```

## Prerequisites & Local Setup

Install: AWS CLI v2, Terraform ≥1.11, kubectl, Helm 3. See official install docs for each.

```bash
aws configure                     # use an AdministratorAccess IAM user for provisioning
```

> **Windows/Git Bash users:** prefix AWS CLI commands that contain a leading `/` with `MSYS_NO_PATHCONV=1` to avoid path-mangling issues (also applies to `openssl` commands with `-subj "/CN=..."`).

## Deploying

**Automated (recommended):**
1. Open a PR touching `terraform/**` → GitHub Actions runs `terraform plan` and posts the output as a PR comment
2. Merge to `main` → GitHub Actions runs `terraform apply` automatically via GitHub OIDC (no long-lived AWS keys stored in the repo)

**Manual bootstrap (first run only, before CI/CD exists):**
```bash
cd terraform/envs
terraform init
terraform plan
terraform apply

aws eks update-kubeconfig --name project-bedrock-cluster --region us-east-1

helm upgrade --install retail-app ./eks-charts/retail-store-sample-app \
  -n retail-app -f k8s/helm-values/values.yaml

kubectl apply -f k8s/base/
```

## Accessing the Store

- **HTTP:** `http://k8s-retailap-retailui-dd768ff5c0-2132271463.us-east-1.elb.amazonaws.com`
- **HTTPS (bonus 5.2):** `https://98-81-57-231.nip.io` — browser will show a certificate warning; the certificate is self-signed and imported directly into ACM, since nip.io is a shared public domain and can't complete standard DNS validation. See `docs/evidence/tls-demo-notes.md`.

## Secure Developer Access — `bedrock-dev-view`

IAM user with `ReadOnlyAccess` (AWS Console) + scoped `s3:PutObject` on the assets bucket, plus an EKS Access Entry granting `AmazonEKSViewPolicy` scoped to the `retail-app` namespace only.

```bash
kubectl get pods -n retail-app          # ✅ works
kubectl delete pod <name> -n retail-app # ❌ Forbidden
```

Credentials are provided separately in the deliverables document — never committed to this repository.

## Observability

- EKS control plane logging enabled (API, Audit, Authenticator, ControllerManager, Scheduler) → CloudWatch Log Groups
- Amazon CloudWatch Observability EKS Add-on installed for container log/metric shipping
- View at: AWS Console → CloudWatch → Log groups → `/aws/containerinsights/project-bedrock-cluster/application`

## Event-Driven Extension (S3 → Lambda)

Uploading a file to the `bedrock-assets-alt-soe-tin-025-0166` bucket triggers `bedrock-asset-processor`, which logs `Image received: <filename>` to CloudWatch.

```bash
aws s3 cp test.jpg s3://bedrock-assets-alt-soe-tin-025-0166/ --profile bedrock-dev-view
aws logs tail /aws/lambda/bedrock-asset-processor --follow
```

## Bonus Objectives (5.1–5.5) — All Completed

| # | Objective | Status | Evidence |
|---|---|---|---|
| 5.1 | Helm-based deployment | ✅ | `eks-charts/`, `k8s/helm-values/values.yaml` |
| 5.2 | TLS via ACM + nip.io | ✅ | `docs/evidence/tls-demo-notes.md`, `docs/evidence/tls-ingress-config.yaml` |
| 5.3 | Cluster Autoscaler + scale-up demo | ✅ | `docs/evidence/autoscaler-demo-notes.md` |
| 5.4 | Network Policies (per-service) | ✅ | `k8s/base/network-policies.yaml`, `docs/evidence/` |
| 5.5 | Resilience demo + backup retention | ✅ | `docs/evidence/resilience-demo-notes.md` |

**Known limitation (5.3):** EKS-managed node groups default to an IMDS hop limit of 1, which prevented the Cluster Autoscaler pod from reading node IAM credentials (`no EC2 IMDS role found`). Fixed by raising the hop limit to 2 on running instances via `aws ec2 modify-instance-metadata-options`. Not yet made permanent in Terraform — would require a custom launch template with `http_put_response_hop_limit = 2` attached to the node group resource, since new autoscaled nodes currently default back to hop limit 1.

## Cost Guardrails

- Single NAT Gateway (not one per AZ)
- AWS Budget set at $20/month, 80% email alert threshold, scoped to `Project: tinyuka-2025-capstone`
- **Note:** budget alerts are notifications only, not automatic shutoffs — they do not stop billing on their own
- Standard practice: scale EKS node group to 0 and stop RDS instances between work sessions (see grader note above)

## Teardown

Full step-by-step teardown guide (Kubernetes-level LB cleanup → `terraform destroy` → manual S3/log group cleanup → state bucket removal) is documented in the deliverables document, Section 5, and should only be run **after grading is confirmed complete**, using credentials with destroy permissions (not `bedrock-dev-view`).

## Grading Data

`terraform/envs/grading.json` is generated via `terraform output -json` and committed to the repo root, containing only the 5 required non-sensitive root outputs: `cluster_endpoint`, `cluster_name`, `region`, `vpc_id`, `assets_bucket_name`.
