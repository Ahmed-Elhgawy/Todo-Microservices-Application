# 📝 Todo Microservices Application

A **production-grade Todo application** showcasing modern DevOps practices. \
This project demonstrates how to build, containerize, deploy, and manage a microservices application using **Docker**, **Terraform**, **Ansible**, **Jenkins**, and **ArgoCD** on **AWS**.

---

## 📌 Architecture Overview

The application consists of three microservices and supporting infrastructure:

### Application Layers

- **Frontend** – Simple UI for managing todos.
- **API** – Backend service that handles requests, writes to *RabbitMQ*, and connects to *MySQL*.
- **Worker** – Consumes tasks from *RabbitMQ* and writes them into the database.
- **MySQL 8.0** – Persistent database with initialization SQL.
- **RabbitMQ 3.11 (management enabled)** – Messaging broker.

All services are containerized with individual `Dockerfiles` and orchestrated with **Kubernetes**.

### Infrastructure (Terraform on AWS)

- **Networking:** VPC, 1 public subnet, 2 private subnets, Internet Gateway, NAT Instance.
- **Compute:** Bastion host (with Docker, Compose, kubectl), Kubernetes master and worker EC2 instances.
- **Storage:** EBS for database and RabbitMQ (via StatefulSets & PVs).
- **Registry:** 3 ECR repositories (frontend, API, worker).
- **Security:** IAM roles with least privilege.
- **Automation:** Kubernetes bootstrapped with `kubeadm` + Containerd runtime, ArgoCD installed via `remote-exec`.

### Configuration Management (Ansible)

- Dynamic inventory using AWS EC2 tags.
- Installs **containerd**, **runc**, **kubeadm**, **kubelet**, **kubectl**, **CNI plugins**.
- Initializes master, configures worker nodes, and sets up cluster networking.

### CI/CD (Jenkins Pipeline)

**Build:** Docker images for each service.
**Security Scan:** Trivy scan, reports published to Jenkins UI.
**Deploy (test env):** Docker Compose on bastion host.
**Promote:** Manual gate approval.
**Push:** Images uploaded to ECR.
**GitOps:** Updates Kubernetes manifests, pushes to GitHub → ArgoCD syncs to cluster.
**Notify:** Slack integration (success/failure).

---

## 📊 High-Level Architecture Diagram

![Disgram](./photo/diagram.png)

---

## ⚙️ Environment Variables

### Frontend
```env
PORT=80
API=http://api-service:3000
```

### API
```env
NODE_ENV=production
PORT=3000
DB_PORT=3306
DB_NAME=<database_name>
DB_USER=<database_user>
DB_PASS=<database_password>
DB_HOST=<database_host>
RABBIT_URL=<rabbitmq_url>
```

### Worker
```env
NODE_ENV=production
PORT=3000
DB_PORT=3306
DB_NAME=<database_name>
DB_USER=<database_user>
DB_PASS=<database_password>
DB_HOST=<database_host>
RABBIT_URL=<rabbitmq_url>
```

### Jenkins
```env
DOCKER_INSTANCE_IP=<bastion_instance_public_ip>
ARGOCD_REPO=<destination_argocd_repo>
ECR_REPO=<account_id>.dkr.ecr.us-east-1.amazonaws.com
```

---

## ⚙️ Terraform Variables

| Variable                   | Description                                   | Example Value       |
| -------------------------- | --------------------------------------------- | ------------------- |
| `region`                   | AWS region where resources will be created    | `us-east-1`         |
| `vpc_cidr`                 | CIDR block for the VPC                        | `10.0.0.0/16`       |
| `public_key_path`          | Path to the SSH public key for EC2 access     | `~/.ssh/id_rsa.pub` |
| `instance_type`            | EC2 instance type for bastion host            | `t3.micro`          |
| `kubernetes_instance_type` | EC2 instance type for K8s master/worker nodes | `t3.medium`         |

---

## 🚀 Installation & Deployment

### 1.Clone Repository
```bash
git clone https://github.com/Ahmed-Elhgawy/todo-microservice-app.git
cd todo-microservice-app/terraform
```

### 2.Provision Infrastructure
```bash
terraform init
terraform apply -auto-approve
```

### 3.Access Bastion Host
```bash
eval $(ssh-agent)
ssh-add ~/.ssh/id_rsa
ssh ec2-user@$(terraform output bation_instance_public_ip | sed 's/"//g')
```

### 4.Configure Kubernetes
```bash
scp ubuntu@<master_instance_ip>:.kube/config ~/.kube/config

# Create registry secret
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account_id>.dkr.ecr.us-east-1.amazonaws.com
kubectl create secret generic regcred --from-file=.dockerconfigjson=/home/ec2-user/.docker/config.json --type=kubernetes.io/dockerconfigjson
```

### 5.Create Secrets
```bash
kubectl create secret generic database-secret \
  --from-literal MYSQL_DATABASE=todo_app \
  --from-literal MYSQL_PASSWORD=password \
  --from-literal MYSQL_ROOT_PASSWORD=PaSsW0Rd! \
  --from-literal MYSQL_USER=user

kubectl create secret generic rabbitmq-secret \
  --from-literal RABBITMQ_DEFAULT_USER=guest \
  --from-literal RABBITMQ_DEFAULT_PASS=guest \
  --from-literal RABBITMQ_URL=amqp://guest:guest@rabbitmq-headless:5672
```

### 6.Access ArgoCD
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
kubectl port-forward svc/argocd-server -n argocd --address 0.0.0.0 8000:443
```

👉 Open https://localhost:8000

### 7.Jenkins Pipeline

- Build, scan, deploy test env.
- Confirm manual gate.
- Push to ECR & GitHub.
- ArgoCD syncs to cluster.

### 8.Test Application
```bash
kubectl port-forward service/frontend-service --address 0.0.0.0 8000:80
```

Open http://localhost:8000

### 9.Cleanup
```bash
aws ecr batch-delete-image --repository-name todo-api \
    --region us-east-1 --image-ids \
    "$(aws ecr list-images --repository-name todo-api --region us-east-1 --query 'imageIds[*]' --output json)"
aws ecr batch-delete-image --repository-name todo-worker \
    --region us-east-1 --image-ids \
    "$(aws ecr list-images --repository-name todo-worker --region us-east-1 --query 'imageIds[*]' --output json)"
aws ecr batch-delete-image --repository-name frontend \
    --region us-east-1 --image-ids \
    "$(aws ecr list-images --repository-name frontend --region us-east-1 --query 'imageIds[*]' --output json)"
terraform destroy -auto-approve
```

---

## 📂 Kubernetes Manifests

- `database.yaml` → StatefulSet, Service, PV, ConfigMap (SQL init).
- `rabbitmq.yaml` → StatefulSet, Service, PV.
- `storageClass.yaml` → StorageClass.
- `deployments.yaml` → API, frontend, worker Deployments (2 replicas).
- `services.yaml` → API, frontend Services.

---

## 🛠️ Tools & Technologies

- **Cloud:** AWS (VPC, EC2, IAM, ECR).
- **IaC:** Terraform.
- **Config Mgmt:** Ansible.
- **Containers:** Docker, Kubernetes, Containerd.
- **CI/CD:** Jenkins, Trivy, Slack notifications.
- **GitOps:** ArgoCD.

---

## 🎯 Key Highlights for Recruiters

✔️ Full DevOps lifecycle: from code → container → cloud → cluster → GitOps. \
✔️ Secure CI/CD pipeline with scanning & manual approvals. \
✔️ Infrastructure as Code & Configuration Management best practices. \
✔️ Scalable microservices with messaging (RabbitMQ) and persistent DB.

---

## 👤 Author

Ahmed Elhgawy
DevOps Engineer | Cloud & Automation Enthusiast \
[📧 Email](mailto:ahmedelhgawy182@gmail.com) \
[🔗 LinkedIn](https://www.linkedin.com/in/ahmed-elhgawy-a16310268)