# Summon The Oracle

Voice-enabled AI assistant backend + frontend with FastAPI, OpenAI GPT-4o, and AWS (S3, ECS, ECR).

Receives voice input, generates sarcastic AI responses, converts to speech, stores audio privately in S3, serves presigned URL for playback.

---

## Prerequisites and Assumptions

**AWS Infrastructure**

- AWS account with permissions to create/manage: S3 buckets, ECS Cluster & Service (Fargate), ECR repo, IAM Roles & Policies (including ECS task role and GitHub Actions role).

**DNS and Domain**

- Route 53 hosted zone for your domain (e.g., pwoodward.info).
- DNS records pointing to your AWS Load Balancer or CloudFront.
- SSL certificates from AWS Certificate Manager.

> DNS and SSL setup not included in this repo.

**GitHub Setup**

- GitHub repo with this codebase.
- GitHub Secrets configured (see Required GitHub Secrets).
- IAM OIDC Identity Provider configured in AWS linked to GitHub.
- IAM Role with trust policy for GitHub Actions to assume and permissions to push Docker images and update ECS.

---

## Repo Structure

- `backend/` — FastAPI backend code (`main.py`).
- `ui/` — Static frontend (HTML, JS, audio).
- `oracle-infra/` — Terraform AWS infrastructure code.
- `dockerfile` — Docker build instructions.
- `docker-ecr.yml` — GitHub Actions workflow.
- `config.json` — Backend config (voice settings).
- `requirements.txt` — Python dependencies.

---

## Workflow Overview

**Development:** write code in `backend/` and `ui/`.

**Containerization:** build Docker image locally or via GitHub Actions.

**Infrastructure:** provision AWS resources with Terraform in `oracle-infra/`.

**Deployment:** push to `main` branch triggers GitHub Actions to build, push image to ECR, update ECS service.

**Runtime:** ECS runs container which accepts voice input, calls OpenAI chat and TTS, uploads audio to S3, serves presigned URLs and frontend.

---

## Required GitHub Secrets

- `AWS_ROLE_TO_ASSUME`: IAM role ARN for GitHub Actions.
- `OPENAI_API_KEY`: OpenAI API key.
- `ECR_REPO`: Full ECR repo URI.
- `ECS_CLUSTER`: ECS cluster name.
- `ECS_SERVICE`: ECS service name.
- `TASK_DEF_FAMILY`: ECS task definition family.

---

## Runtime Environment Variables (ECS task)

- `AWS_REGION`: AWS region (e.g., us-east-2).
- `S3_BUCKET`: S3 bucket name for audio.
- `OPENAI_API_KEY`: OpenAI API key.

---

## How to Use

1. Clone the repo.
2. Customize backend/frontend.
3. Run `terraform apply` in `oracle-infra/`. (After filling out your tfvars appropriately)
4. Push to `main` to trigger deployment.
5. Visit your frontend URL (e.g., https://oracle.pwoodward.info).

---

## Notes

- S3 bucket is private; audio URLs are presigned and temporary.
- Use presigned URLs as provided (no manual encoding).
- ECS task role needs permissions for S3, ECS, ECR.
- Keep clocks synced to avoid AWS signature errors.
- Use short expiration for presigned URLs.
- Keep your OpenAI API key secure.

---

If you want help adding commands or setup instructions, just say the word.
Any additional questions/problems? Feel free to e-mail me personally at patrick@pwoodward.info