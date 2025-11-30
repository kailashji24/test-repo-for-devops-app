# 📘 Lift & Shift Automation – End-to-End DevOps Project

This project demonstrates a full CI/CD pipeline deploying a Java application to AWS using:
* **Terraform** (Infrastructure as Code)
* **GitHub Actions** (CI)
* **AWS CodeDeploy** (CD)
* **EC2 + Auto Scaling Group + ALB** (Compute & Load Balancing)
* **S3** (Artifact storage)
* **IAM Permissions** (Secure auth between GitHub → AWS)

This is a complete **Lift & Shift migration** of an on-prem Java app into AWS Cloud with automated deployments.

---

## 🚀 1. High-Level Architecture
**Developer → GitHub → GitHub Actions → S3 → CodeDeploy → EC2 (ASG) → ALB → User**

**Flow Breakdown:**
1.  Dev writes code → pushes to `main` branch.
2.  **GitHub Actions**:
    * Builds Java app (Maven).
    * Creates artifact (Zip).
    * Uploads to S3.
    * Triggers CodeDeploy.
3.  **CodeDeploy** deploys the artifact to EC2 instances in the Auto Scaling Group.
4.  **ALB** routes traffic to healthy EC2 servers.
5.  App becomes available at **ALB DNS**.

---

## 📂 2. Repository Structure

```text
test-repo-for-devops-app/
│
├── .github/workflows/deploy.yml     # GitHub Actions CI/CD pipeline
│
├── scripts/
│   ├── stop_server.sh               # Stops old Java app
│   ├── fix_privileges.sh            # Ensures permissions
│   └── start_server.sh              # Starts new Java app
│
├── terraform/
│   ├── main.tf                      # AWS provider
│   ├── network_and_security.tf      # VPC + Subnets + Security Groups
│   ├── alb_and_asg.tf               # ASG + Launch Template + ALB
│   ├── codedeploy.tf                # CodeDeploy App + Deployment Group
│   ├── outputs.tf                   # Terraform outputs
│   └── user-data.sh                 # EC2 startup script (installs CodeDeploy agent)
│
├── appspec.yml                      # CodeDeploy deployment instructions
├── pom.xml                          # Java project's Maven build file
└── src/                             # Java source code

---

## ⚙️ 3. Infrastructure (Terraform)
Terraform automatically provisions:

* **Networking:** VPC, Security Groups, Subnets.
* **Compute:** Auto Scaling Group, Launch Template, EC2 instances (Amazon Linux 2).
* **Load Balancing:** Application Load Balancer, Listener (80), Target Groups.
* **CI/CD Components:** S3 bucket for artifacts, CodeDeploy Application & Group.
* **IAM Roles:** Roles for EC2 to access S3, and CodeDeploy service roles.

---

## 🔄 4. CI/CD (GitHub Actions)
**Workflow file:** `.github/workflows/deploy.yml`

**Pipeline Steps:**
1.  Trigger on push to `main`.
2.  Setup **Java 17**.
3.  Build using **Maven**.
4.  Zip artifacts.
5.  Authenticate to AWS (via Repository Secrets).
6.  Upload to S3.
7.  Trigger CodeDeploy deployment.

---

## 📦 5. Deployment (CodeDeploy)
CodeDeploy runs on the server in this order (defined in `appspec.yml`):
1.  **Download artifact** from S3.
2.  **ApplicationStop:** `stop_server.sh` (Stops existing app).
3.  **AfterInstall:** `fix_privileges.sh` (Sets execution permissions).
4.  **ApplicationStart:** `start_server.sh` (Starts the new jar file).

---

## ☁️ 6. Configuration & Setup
* **EC2 Configuration:** User Data script installs **Java 17** and the **CodeDeploy Agent**.
* **Secrets:** GitHub Actions uses `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` to talk to AWS.

---

## 🧪 7. How to Test the Deployment
1.  **Push Code:** Make a change and merge PR to `main`.
2.  **Verify Pipeline:** Check GitHub Actions logs for "Success".
3.  **Verify AWS:** Check CodeDeploy console for "Succeeded".
4.  **Verify App:** Open your ALB DNS in the browser:
    `http://<alb-dns-name>/hello`

**Expected Output:**
> Hello from Spring MVC!

---

## 👨‍💻 Author
**Kailash Chaudhary**
DevOps Engineer – Lift & Shift Automation Project
TechEazy Trainings