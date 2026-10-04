# CI/CD Blueprint — AWS SaaS Application

I would design the CI/CD platform using GitHub, GitHub Actions, Argo CD, and Argo Rollouts.

The application consists of two independently deployable services:

- Frontend: React Single Page Application (SPA)
- Backend: Python REST API

The frontend and backend are independently deployable and maintained in separate repositories. A third GitOps repository contains the desired deployment state for Kubernetes workloads.

## Repository Architecture

I recommend three separate GitHub repositories.

```text
GitHub Organization
│
├── saas-frontend
│   └── React SPA
│
├── saas-backend
│   └── Python API
│
└── saas-gitops
    └── Deployment configuration / desired state
```

### Design Goals

The CI/CD architecture is designed around the following goals:

- Independent frontend and backend releases
- Automated quality and security validation
- Immutable application artifacts
- GitOps-based Kubernetes deployments
- Automated staging deployment
- Controlled production deployment
- Blue/green deployment for the backend
- Least-privilege AWS access
- No long-lived AWS credentials in GitHub
- Fast rollback and operational visibility

### Tools

| Tool / Service | Role |
|---|---|
| **GitHub** | Source control, branches, pull requests, code reviews, and branch protection |
| **GitHub Actions** | CI workflow orchestration |
| **SonarQube** | Code quality, SAST, and quality gates |
| **Gitleaks** | Secret detection |
| **Trivy** | Dependency, container, and IaC vulnerability scanning |
| **Testing** | **Frontend:** Vitest/Jest, React Testing Library, and Playwright<br>**Backend:** pytest and pytest-cov<br>**Security:** SonarQube, Trivy, and Gitleaks<br>**Integration/E2E:** Playwright and API integration tests |
| **Docker** | Containerized builds and backend packaging |
| **Helm** | Kubernetes application packaging |
| **Argo CD** | GitOps continuous delivery |
| **Argo Rollouts** | Blue/green production deployments |
| **AWS IAM** | Access control and permissions management |
| **GitHub OIDC** | Short-lived GitHub-to-AWS authentication |

---

## CI/CD Flow Digram

                         ┌───────────────────┐
                         │    Developer      │
                         └─────────┬─────────┘
                                   │
                              git push
                                   │
                                   ▼
                         ┌───────────────────┐
                         │      GitHub       │
                         │  Application Repo │
                         └─────────┬─────────┘
                                   │
                              Pull Request
                                   │
                                   ▼
                       ┌───────────────────────┐
                       │   GitHub Actions CI   │
                       │                       │
                       │ Lint                  │
                       │ Unit Tests            │
                       │ Coverage ≥ 80%        │
                       │ SAST                  │
                       │ Dependency/CVE Scan   │
                       │ Secret Scan           │
                       │ SonarQube             │
                       │ IaC Scan              │
                       └───────────┬───────────┘
                                   │
                          PASS + Peer Review
                                   │
                                   ▼
                            Merge to staging
                                   │
                    ┌──────────────┴──────────────┐
                    │                             │
                    ▼                             ▼
             React Frontend                 Python Backend
                    │                             │
             GitHub Actions                 GitHub Actions
                    │                             │
             Containerized Build             Docker Build
                    │                             │
                    ▼                             ▼
              Static Assets                    ECR
                    │                             │
                    ▼                             │
              S3 Staging                         │
                    │                             │
                    ▼                             ▼
              CloudFront                    GitOps Repo
                    │                             │
                    │                             ▼
                    │                         Argo CD
                    │                             │
                    │                             ▼
                    │                         EKS Staging
                    │                             │
                    └──────────────┬──────────────┘
                                   │
                                   ▼
                          Integration / E2E Tests
                                   │
                                   ▼
                              QA Validation
                                   │
                                   ▼
                         Production Release PR
                                   │
                             QA Approval
                                   │
                                   ▼
                         Promote SAME Artifact
                         ┌─────────┴──────────┐
                         │                    │
                         ▼                    ▼
                   React Frontend        Python Backend
                         │                    │
                         ▼                    ▼
                    S3 + CloudFront       ECR + EKS
                                              │
                                           Argo CD
                                              │
                                       Argo Rollouts
                                              │
                                         Green Stack
                                              │
                                      Integration Tests
                                              │
                                      Manual Promotion
                                              │
                                              ▼
                                        LIVE TRAFFIC


### Deployment Strategy — Blue/Green

I would use **Blue/Green deployment using Argo Rollouts**.

```text
                    Production
                         │
                  ┌──────┴──────┐
                  │             │
                BLUE          GREEN
               Stable           New
                  │             │
                  │       Integration Tests
                  │             │
                  │            PASS
                  │             │
                  └──────┬──────┘
                         │
                  Manual Approval
                         │
                         ▼
                       GREEN
                         │
                         ▼
                    Live Traffic
```

## Deployment sequence

1. Current version continues serving production traffic.
2. New version is deployed as the green stack.
3. Green health checks are performed.
4. Smoke and integration tests are executed.
5. Production approval is requested.
6. Green is promoted to receive production traffic.
7. Blue is retained for a controlled rollback period.
8. Blue is removed after the release is considered stable.

## Rollback

If validation fails:

```text
Green → Abort
Blue  → Continues serving traffic
```

This provides controlled releases, minimal downtime and fast rollback.

---
