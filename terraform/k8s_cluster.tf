# Master Security Group
resource "aws_security_group" "master_allow_tls" {
  name        = "master_allow_tls"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.main-vpc.id

  tags = merge(local.tags, {
    Name = "master_allow_tls"
  })
}

resource "aws_vpc_security_group_ingress_rule" "master_allow_6443_ipv4" {
  security_group_id = aws_security_group.master_allow_tls.id
  cidr_ipv4         = var.vpc_cidr
  from_port         = 6443
  ip_protocol       = "tcp"
  to_port           = 6443
}

resource "aws_vpc_security_group_ingress_rule" "master_allow_6783_ipv4" {
  security_group_id = aws_security_group.master_allow_tls.id
  cidr_ipv4         = var.vpc_cidr
  from_port         = 6783
  ip_protocol       = "tcp"
  to_port           = 6783
}

resource "aws_vpc_security_group_ingress_rule" "master_allow_udp_ipv4" {
  security_group_id = aws_security_group.master_allow_tls.id
  cidr_ipv4         = var.vpc_cidr
  from_port         = 6783
  ip_protocol       = "udp"
  to_port           = 6784
}

resource "aws_vpc_security_group_egress_rule" "master_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.master_allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# workers Security Group
resource "aws_security_group" "worker_allow_tls" {
  name        = "worker_allow_tls"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.main-vpc.id

  tags = merge(local.tags, {
    Name = "worker_allow_tls"
  })
}

resource "aws_vpc_security_group_ingress_rule" "worker_allow_10250_ipv4" {
  security_group_id = aws_security_group.worker_allow_tls.id
  cidr_ipv4         = var.vpc_cidr
  from_port         = 10250
  ip_protocol       = "tcp"
  to_port           = 10250
}

resource "aws_vpc_security_group_ingress_rule" "worker_allow_6783_ipv4" {
  security_group_id = aws_security_group.worker_allow_tls.id
  cidr_ipv4         = var.vpc_cidr
  from_port         = 6783
  ip_protocol       = "tcp"
  to_port           = 6783
}

resource "aws_vpc_security_group_ingress_rule" "worker_allow_udp_ipv4" {
  security_group_id = aws_security_group.worker_allow_tls.id
  cidr_ipv4         = var.vpc_cidr
  from_port         = 6783
  ip_protocol       = "udp"
  to_port           = 6784
}

resource "aws_vpc_security_group_egress_rule" "worker_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.worker_allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# SSH Security Group
resource "aws_security_group" "ssh_allow_tls" {
  name        = "ssh_allow_tls"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.main-vpc.id

  tags = merge(local.tags, {
    Name = "ssh_allow_tls"
  })
}

resource "aws_vpc_security_group_ingress_rule" "ssh_allow_ssh_ipv4" {
  security_group_id            = aws_security_group.ssh_allow_tls.id
  referenced_security_group_id = aws_security_group.allow_tls.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

resource "aws_instance" "master-instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.kubernetes_instance_type
  key_name      = aws_key_pair.key_pair.key_name
  subnet_id     = aws_subnet.private-subnets[0].id
  vpc_security_group_ids = [
    aws_security_group.master_allow_tls.id,
    aws_security_group.ssh_allow_tls.id
  ]

  tags = merge(local.tags, {
    Name   = "master-instance"
    Member = "Kubernetes"
  })
}

resource "aws_instance" "worker-instance" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.kubernetes_instance_type
  key_name             = aws_key_pair.key_pair.key_name
  subnet_id            = aws_subnet.private-subnets[1].id
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  vpc_security_group_ids = [
    aws_security_group.worker_allow_tls.id,
    aws_security_group.ssh_allow_tls.id
  ]
  user_data = <<-EOF
    #!/bin/bash
    
    mkdir -p /mnt/mysql-data/master
    mkdir -p /mnt/rabbitmq-data
  EOF

  tags = merge(local.tags, {
    Name   = "worker-instance"
    Member = "Kubernetes"
  })
}

resource "aws_iam_role" "worker-instance-role" {
  name = "worker-instance-role"

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
resource "aws_iam_role_policy_attachment" "ecr_worker_access" {
  role       = aws_iam_role.worker-instance-role.name
  policy_arn = aws_iam_policy.ecr-policy.arn
}

resource "aws_iam_instance_profile" "worker_instance_profile" {
  name = "worker-instance-profile"
  role = aws_iam_role.worker-instance-role.name
}