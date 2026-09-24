# 3-Tier Application on AWS EC2

A production-style, highly-available 3-tier web application (Web / App / Database) deployed on
AWS EC2 using immutable AMIs (Packer), Auto Scaling Groups behind Application Load Balancers,
Amazon RDS (MySQL), and a fully automated GitHub Actions CI/CD pipeline provisioning
infrastructure with Terraform.

## Architecture

```
                                   Internet
                                      │
                            Route53 (dev.<domain> / staging / ...)
                                      │
                         ┌────────────▼────────────┐
                         │   Web ALB (public, TLS)  │
                         └────────────┬────────────┘
                                      │
                     ┌────────────────▼────────────────┐
                     │  Web tier ASG (private subnets)  │
                     │  Nginx + built React static app  │
                     └────────────────┬────────────────┘
                                      │ /api/* proxy
                         ┌────────────▼────────────┐
                         │  App ALB (internal only) │
                         └────────────┬────────────┘
                                      │
                     ┌────────────────▼────────────────┐
                     │  App tier ASG (private subnets)  │
                     │  Node.js/Express API (pm2)       │
                     └────────────────┬────────────────┘
                                      │
                         ┌────────────▼────────────┐
                         │  RDS MySQL (Multi-AZ)     │
                         │  private DB subnets       │
                         └───────────────────────────┘
```

* **Web tier** — Nginx serves the built React app and reverse-proxies `/api/*` to the internal
  App ALB. Instances live in private subnets behind a public-facing ALB with HTTPS (ACM cert).
* **App tier** — Node.js/Express REST API, managed by `pm2`, reads DB credentials from AWS
  Secrets Manager at boot. Instances live in private subnets behind an **internal** ALB.
* **Data tier** — Amazon RDS for MySQL in private DB subnets, Multi-AZ, encrypted storage,
  automated backups.
* **Cross-cutting** — CloudWatch Agent ships nginx/app logs and host metrics (mem/disk) to
  per-environment log groups; CloudWatch alarms cover ALB health/5XX/latency and RDS
  CPU/storage/connections; an SNS topic fans out alerts; a bastion host provides SSH access into
  the private subnets.

## Repository layout

| Path | Purpose |
|---|---|
| `application_code/app_files` | Node.js/Express backend (`/healthz`, `/api/transaction`, etc.) |
| `application_code/web_files` | React frontend (Create React App) |
| `application_code/nginx.conf` | Nginx config installed onto web-tier instances |
| `application_code/app.sh`, `web.sh` | Scripts run at instance boot to start/build each tier |
| `app_user_data.sh`, `web_user_data.sh` | EC2 user-data bootstrap scripts (rendered via Terraform `templatefile()`) |
| `packer/backend`, `packer/frontend` | Packer templates that bake hardened, dependency-preinstalled AMIs |
| `modules/*` | Terraform modules: `vpc`, `sg`, `alb`, `asg`, `rds`, `route53`, `secrets`, `bastion-server` |
| `*.tfvars`, `*-apply.sh`, `*-destroy.sh` | Per-environment Terraform variables and apply/destroy helper scripts |
| `.github/workflows/ci-cd.yaml` | CI/CD pipeline: build/test, lint, security scans, Terraform plan/apply |
| `docker-compose.yml` | Local full-stack (db + backend + frontend) for development, independent of AWS |

## Local development

The fastest way to run the full stack locally (no AWS account required) is Docker Compose:

```bash
docker compose up --build
```

This starts:
* `db` — MySQL 8, seeded from `application_code/appdb.sql`
* `backend` — Node/Express API on `http://localhost:3000` (`/healthz`, `/api/transaction`)
* `frontend` — Nginx-served React build on `http://localhost:8080` (proxies `/api/` to `backend`)

Tear down with `docker compose down -v`.

### Running the backend without Docker

```bash
cd application_code/app_files
npm install
DB_HOST=127.0.0.1 DB_PORT=3306 DB_USER=admin DB_PASSWORD=password DB_NAME=webappdb npm start
npm test        # node:test smoke tests
npm run lint    # ESLint
```

### Running the frontend without Docker

```bash
cd application_code/web_files
npm install
npm start
```

## Infrastructure (Terraform)

Each environment has its own tfvars file and apply/destroy helper script:

| Environment | tfvars | Apply script |
|---|---|---|
| Development | `dev.tfvars` | `./dev-apply.sh` |
| Staging | `staging.tfvars` | `./staging-apply.sh` |
| Production | `prod.tfvars` | `./prod-apply.sh` (requires interactive confirmation before `apply`) |

Each apply script builds the frontend/backend AMIs with Packer if they don't already exist, then
runs `terraform init` + `terraform apply -var-file=<env>.tfvars`. State is stored remotely in S3
with encryption and native state locking (see `backend.tf`).

```bash
# Example: deploy the dev environment
./dev-apply.sh

# Tear it down
./dev-destroy.sh
```

> Production credentials/secrets in `prod.tfvars` are placeholders — replace `db_password`,
> `secret_password`, `sns_topic_arn`, `hosted_zone_name`, and bastion AMI/key values with your
> real production values (ideally injected via CI secrets rather than committed in plaintext).

## CI/CD pipeline

`.github/workflows/ci-cd.yaml` runs on every PR/push to `main`, and can also be triggered
manually (`workflow_dispatch`) to plan/apply a chosen environment (`dev`, `staging`, `prod`):

1. **Backend build/test/lint** — `npm ci`, `npm test` (node:test), `npm run lint` (ESLint).
2. **Frontend build/test** — `npm ci`, `npm test`, `npm run build`.
3. **Terraform fmt/validate** and **Checkov** static analysis of the Terraform modules.
4. **Security scan** — Trivy application config scan plus Trivy image scans of the built backend/frontend
   Docker images (catches OS/package vulnerabilities in what actually ships).
5. **Terraform plan** — produces a plan artifact for the selected environment (requires the prior
   jobs, including the security scan, to pass).
6. **Terraform apply** — gated behind a GitHub **environment** approval and the `deploy` input,
   authenticates to AWS via GitHub OIDC (no long-lived AWS keys stored in the repo).

## Observability

* **Logs** — CloudWatch Log Groups `/three-tier/<environment>/web` and `/three-tier/<environment>/app`
  receive nginx access/error logs and backend stdout/stderr (via the CloudWatch Agent installed in
  each Packer AMI and configured by the user-data scripts), with retention controlled by
  `log_retention_days` (default 14 days, 90 in `prod.tfvars`).
* **Metrics/alarms** — ALB target health, 5XX error count, and response time alarms for both the
  web and app tiers; RDS CPU utilization, free storage, and connection count alarms. All alarms
  publish to the SNS topic configured via `sns_topic_arn`.
* **Dashboard** — `cloudwatch_dashboard.tf` provisions a single CloudWatch dashboard summarizing
  ALB, ASG, and RDS metrics for the deployed environment.

## Security

* Only the public web ALB is internet-facing; the app ALB is internal-only, and web/app/db tier
  instances sit in private subnets with no public IPs.
* IAM is split per tier (`modules/asg/iam.tf`): the app role can only `GetSecretValue` on its own
  secret ARN (not `*`); the web role has no secrets access at all. Both share a scoped
  CloudWatch-only policy instead of the broad AWS-managed `CloudWatchAgentServerPolicy`.
  Access is granted via least-privilege IAM instance profiles rather than embedded credentials.
* DB credentials are stored in AWS Secrets Manager and fetched at boot; local development uses
  the `DB_*` environment variables instead (see `DbConfig.js`).
* CI performs Trivy vulnerability scanning (IaC + container images) and Checkov policy scanning
  before any `terraform apply` is allowed to run.

## Operational runbook

### Smoke test after a deploy

1. Confirm the target group health checks are passing:
   `aws elbv2 describe-target-health --target-group-arn <web-or-app-tg-arn>`
2. Hit the public endpoint: `curl -sf https://<record_name>.<hosted_zone_name>/healthz`
3. Hit the API through the web tier's proxy: `curl -sf https://<record_name>.<hosted_zone_name>/api/transaction`
4. Check the CloudWatch dashboard and confirm no alarms are in `ALARM` state.
5. Tail the new log streams in `/three-tier/<environment>/web` and `/app` for unexpected errors.

### Rollback

* **Application-level rollback** — re-run the CI/CD workflow (`workflow_dispatch`) against the
  previously known-good commit/tag on `main`; the ASG launch template will roll out instances
  built from the AMIs associated with that commit once rebuilt, or simply redeploy the prior
  Packer-built AMI IDs recorded in `packer/ami_ids/*.txt`.
* **Infrastructure-level rollback** — use `terraform plan -var-file=<env>.tfvars` against the
  previous commit to review the diff, then `terraform apply` it; state is versioned/locked in the
  S3 backend so concurrent applies are safe.
* If a bad deploy is actively serving traffic, the fastest mitigation is scaling the ASG's
  `desired_capacity` down to `min_size` old instances (if still running) or terminating the
  unhealthy instances so the ASG replaces them from the last-good AMI.

### Release checklist

- [ ] `terraform fmt -check -recursive` and `terraform validate` pass
- [ ] Backend/frontend tests, lint, and build succeed in CI
- [ ] Trivy and Checkov scans show no new high/critical findings
- [ ] Terraform plan reviewed and approved for the target environment
- [ ] Smoke tests (above) pass after apply
- [ ] CloudWatch dashboard/alarms reviewed for anomalies post-deploy
