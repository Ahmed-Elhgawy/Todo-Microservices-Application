resource "aws_key_pair" "key_pair" {
  key_name   = "key_pair"
  public_key = file(var.public_key_path)
}

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.main-vpc.id

  tags = merge(local.tags, {
    Name = "allow_tls"
  })
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_argocd_ipv4" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 8000
  ip_protocol       = "tcp"
  to_port           = 8000
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv4" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"] # Amazon official owner ID
}
resource "aws_instance" "bastion-instance" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  associate_public_ip_address = true
  key_name                    = aws_key_pair.key_pair.key_name
  subnet_id                   = aws_subnet.public-subnet.id
  vpc_security_group_ids = [
    aws_security_group.allow_tls.id
  ]
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  user_data            = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo amazon-linux-extras install docker -y
    systemctl enable docker
    systemctl start docker
    sudo usermod -a -G docker ec2-user

    sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
    sudo chmod 755 /usr/local/bin/docker-compose

    sudo yum install git -y

    sudo curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.34.1/2025-09-19/bin/linux/amd64/kubectl 
    sudo mv kubectl /usr/local/bin/
    sudo chmod 755 /usr/local/bin/kubectl
    mkdir -p /home/ec2-user/.kube
    sudo chown ec2-user:ec2-user /home/ec2-user/.kube
  EOF

  tags = merge(local.tags, {
    Name = "bastion-instance"
  })
}


resource "aws_iam_role" "bastion-instance-role" {
  name = "bastion-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ],
  })
}

resource "aws_iam_policy" "ecr-policy" {
  name        = "ecr-policy"
  path        = "/"
  description = "policy gives access to ECR repositories to login, pull and push images"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}
resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.bastion-instance-role.name
  policy_arn = aws_iam_policy.ecr-policy.arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "bastion-instance-profile"
  role = aws_iam_role.bastion-instance-role.name
}