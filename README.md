
# 🌍 Geo-SRE: Cloud-Native Geospatial Data Pipeline

## 📖 Project Overview

**Geo-SRE** is a production-grade, event-driven DevOps project designed to ingest, validate, and visualize geospatial data automatically.

The system features a **Zero-Touch workflow**: Data uploaded to S3 triggers a complex chain of events—processed securely inside a private Kubernetes network and visualized in real-time.

---

## 🏗️ Architecture & Infrastructure

The entire environment is provisioned via **Terraform** (IaC) and follows strict security best practices, including network isolation in Private Subnets and Least Privilege IAM Roles.

### High-Level Data Flow

1. **Ingest:** User uploads `GeoJSON` to a Private S3 Bucket.
2. **Event:** S3 Notification triggers an SQS Queue message.
3. **Process:** Python Worker (running on EKS) consumes the message and parses the geometry.
4. **Storage:** Data is written to AWS RDS (PostgreSQL + PostGIS).
5. **Visualization:** Flask App serves live data via a Load Balancer.

### Infrastructure (AWS EKS)

*The active Kubernetes cluster provisioned by Terraform:*

### 📂 Project Structure

*Modular organization using Helm Charts for Kubernetes and Terraform for Infrastructure:*

---

## 🛡️ Robust CI/CD Pipeline (DevSecOps)

The pipeline implements a **"Shift-Left"** security approach, ensuring no code reaches production without passing automated gates.

### Pipeline Flow:

The lifecycle is divided into **Integration & Security** testing followed by **Automated Deployment** to EKS.

### Quality & Security Gates:

* **Security Scanning (Trivy):** Scans the container image for CVEs before the build completes.
* **Ephemeral Testing (Kind):** Spins up a **Kubernetes in Docker (Kind)** cluster inside the CI runner to test the deployment in a real environment.
* **Smoke Tests:** Deploys a temporary Postgres DB and the App to verify connectivity *before* pushing to AWS.

---

## 🚀 Kubernetes Scaling & Reliability

The application is hosted on **Amazon EKS** with high availability and automated scaling.

### Horizontal Pod Autoscaler (HPA)

The system automatically scales application pods based on real-time CPU utilization.

**Autoscaling Proof:**

---

## 🛠️ Tech Stack

| Category | Technology | Usage |
| --- | --- | --- |
| **Cloud** | AWS | EKS, RDS, S3, SQS, VPC, IAM |
| **IaC** | Terraform | Full environment provisioning with S3 Remote State |
| **Orchestration** | Kubernetes | Helm Charts, HPA, Deployments, Services |
| **CI/CD** | GitHub Actions | Trivy Security, Kind Integration Tests |
| **Database** | PostgreSQL | PostGIS extension for geospatial storage |
| **Backend** | Python (Flask) | REST API & SQS Worker |

---

## 📸 End-to-End Demo

### Live Dashboard

The final result: A live dashboard updating automatically as data is processed through the pipeline.

---

## 💻 How to Run

1. **Provision Infrastructure:**
```bash
cd iac
terraform init && terraform apply

```


2. **Deploy:**
Pushing to the `main` branch triggers the automated CI/CD pipeline.

---
