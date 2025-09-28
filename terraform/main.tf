terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
  state = "available"
}


locals {
  tags = {
    Environment = "porduction"
    Project     = "microservice"
    Terraform   = "true"
  }
}

resource "null_resource" "ansible" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    working_dir = "../ansible"
    command     = <<-EOF
      ansible-playbook --ssh-common-args='-o ProxyCommand="ssh -W %h:%p -q -o StrictHostKeyChecking=no ec2-user@${aws_instance.bastion-instance.public_ip}"' playbook.yml
    EOF
  }
  connection {
    type                = "ssh"
    user                = "ubuntu"
    host                = aws_instance.master-instance.private_ip
    private_key         = file("~/.ssh/id_rsa")
    bastion_host        = aws_instance.bastion-instance.public_ip
    bastion_user        = "ec2-user"
    bastion_private_key = file("~/.ssh/id_rsa")
  }
  provisioner "remote-exec" {
    inline = [
      "kubectl create namespace argocd",
      "kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
    ]
  }

  depends_on = [
    aws_instance.bastion-instance,
    aws_instance.master-instance,
    aws_instance.worker-instance
  ]
}