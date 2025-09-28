resource "aws_security_group" "nat_allow_tls" {
  name        = "nat_allow_tls"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.main-vpc.id

  tags = merge(local.tags, {
    Name = "nat_allow_tls"
  })
}

resource "aws_vpc_security_group_ingress_rule" "nat_allow_ssh_ipv4" {
  security_group_id = aws_security_group.nat_allow_tls.id
  cidr_ipv4         = var.vpc_cidr
  from_port         = 0
  ip_protocol       = "tcp"
  to_port           = 65535
}

resource "aws_vpc_security_group_egress_rule" "nat_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.nat_allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_instance" "nat" {
  ami                         = "ami-00a9d4a05375b2763"
  instance_type               = "t3.micro"
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public-subnet.id
  vpc_security_group_ids = [
    aws_security_group.nat_allow_tls.id
  ]
  source_dest_check = false

  tags = merge(local.tags, {
    Name = "NAT-Instance"
  })
}