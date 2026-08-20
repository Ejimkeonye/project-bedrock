# Project Bedrock

InnovateMart Inc. — Production-grade EKS deployment (AltSchool Tinyuka 2025, Third Semester Capstone)

Provisions a secure Amazon EKS cluster and deploys the [retail-store-sample-app](https://github.com/aws-containers/retail-store-sample-app) with managed AWS data services, secured developer access, full observability, an event-driven S3→Lambda extension, and automated CI/CD.

Infrastructure is live and running — no setup is required to test the app, `kubectl` access, or the S3→Lambda trigger.

---

## Architecture

See `docs/architecture.png` for the full diagram (VPC/subnet layout, EKS cluster, managed data layer, ALB ingress, S3→Lambda flow).

**Region:** us-east-1
**EKS Cluster:** `project-bedrock-cluster`
**VPC:** `project-bedrock-vpc` (10.0.0.0/16), public + private subnets across 2 AZs, single shared NAT Gateway
**Data layer:** RDS MySQL (`bedrock-catalog-mysql`) for catalog, RDS PostgreSQL (`bedrock-orders-postgres`) for orders, DynamoDB (`bedrock-carts`) for carts
**In-cluster services:** RabbitMQ, Redis (Helm chart defaults, per spec)

## Repository Structure
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
├── eks-charts/              # Helm chart used for deployment
├── lambda/                  # S3 event → CloudWatch log function
├── .github/workflows/       # Terraform CI/CD (plan on PR, apply on merge)
└── docs/
├── architecture.png
└── evidence/             # bonus objective evidence
## Accessing the Store

- **HTTP:** `http://k8s-retailap-retailui-dd768ff5c0-2132271463.us-east-1.elb.amazonaws.com`
- **HTTPS (bonus):** `https://98-81-57-231.nip.io` — browser will show a certificate warning; certificate is self-signed and imported directly into ACM since nip.io can't complete standard DNS validation. See `docs/evidence/tls-demo-notes.md`.

## Secure Developer Access — `bedrock-dev-view`

IAM user with `ReadOnlyAccess` (AWS Console) + scoped `s3:PutObject` on the assets bucket, plus an EKS Access Entry granting `AmazonEKSViewPolicy` scoped to the `retail-app` namespace only.

```bash
kubectl get pods -n retail-app          # ✅ works
kubectl delete pod <name> -n retail-app # ❌ Forbidden
Credentials are provided separately in the deliverables document — never committed to this repository.

#Observability
EKS control plane logging enabled (API, Audit, Authenticator, ControllerManager, Scheduler) → CloudWatch Log Groups
Amazon CloudWatch Observability EKS Add-on installed for container log/metric shipping
View at: AWS Console → CloudWatch → Log groups → /aws/containerinsights/project-bedrock-cluster/application
Event-Driven Extension (S3 → Lambda)
Uploading a file to the bedrock-assets-alt-soe-tin-025-0166 bucket triggers bedrock-asset-processor, which logs Image received: <filename> to CloudWatch.

Bonus Objectives — All Completed
#
Objective
Evidence
5.1
Helm-based deployment
eks-charts/, k8s/helm-values/values.yaml
5.2
TLS via ACM + nip.io
docs/evidence/tls-demo-notes.md
5.3
Cluster Autoscaler + scale-up demo
docs/evidence/autoscaler-demo-notes.md
5.4
Network Policies (per-service)
k8s/base/network-policies.yaml
5.5
Resilience demo + backup retention
docs/evidence/resilience-demo-notes.md

#Cost Guardrails
Single NAT Gateway (not one per AZ)
AWS Budget set at $20/month, 80% email alert threshold
Infrastructure will be torn down immediately after grading is confirmed complete

#Teardown
Full teardown steps (Kubernetes-level LB cleanup → terraform destroy → manual S3/log group cleanup → state bucket removal) are documented in the deliverables document, and are only run after grading is confirmed complete, using admin credentials.

#Grading Data
terraform/envs/grading.json is generated via terraform output -json, containing only the 5 required non-sensitive root outputs: cluster_endpoint, cluster_name, region, vpc_id, assets_bucket_name

