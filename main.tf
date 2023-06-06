# Set the AWS provider and region
provider "aws" {
  region = "us-east-2"
}
# Create a VPC with a single public subnet and Internet Gateway
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "my-vpc"
  cidr   = "10.0.0.0/16"
  azs             = ["us-east-2a"]
  private_subnets = []
  public_subnets  = ["10.0.1.0/24"]
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
# Create a security group that allows SSH, RDP, and ICMP traffic from your IP only
resource "aws_security_group" "allow_rdp_ssh_icmp" {
  name_prefix = "allow-rdp-ssh-icmp"
  vpc_id      = module.vpc.vpc_id
  ingress {
    description = "SSH access from your IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["98.61.237.21/32"]
  }
  ingress {
    description = "RDP access from your IP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["98.61.237.21/32"]
  }
  ingress {
    description = "ICMP access from your IP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["98.61.237.21/32"]
  }
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# Launch an EC2 instance using the Ubuntu Server 20.04 LTS AMI
resource "aws_instance" "ubuntu_desktop" {
  ami           = "ami-0122295b0eb922138"
  instance_type = "t3.small"
  subnet_id     = module.vpc.public_subnets[0]
  key_name               = "spot-pair-ed25519"
  vpc_security_group_ids = [aws_security_group.allow_rdp_ssh_icmp.id]
  # Install XFCE desktop environment and RDP server
  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              # apt-get -y install firefox xfce4 xfce4-goodies xrdp pulseaudio
              apt-get -y install ubuntu-desktop xrdp pulseaudio
              systemctl enable xrdp
              EOF
  # Tag the instance for easy identification
  tags = {
    Name = "ubuntu-desktop"
  }
}
output "public_ip" {
  value = aws_instance.ubuntu_desktop.public_ip
}
output "ssh_keyscan_command" {
  value = "ssh-keyscan ${aws_instance.ubuntu_desktop.public_ip} >> ~/.ssh/known_hosts"
}
output "ssh_command" {
  value = "ssh -i ~/.ssh/spot-pair-ed25519.pem ubuntu@${aws_instance.ubuntu_desktop.public_ip}"
}
output "rdp_connection_string" {
  value = "ip:${aws_instance.ubuntu_desktop.public_ip} username:ubuntu password:<your_password_here> resolution:1280x720"
}
output "rdp_url" {
  value = "rdp://${aws_instance.ubuntu_desktop.public_ip}:3389/?username=ubuntu"
}
output "ping_command" {
  value = "ping {aws_instance.ubuntu_desktop.public_ip}"
}
# Need to automate these fixes
output "remaining_commands" {
  value = "echo xfce4-session | tee .xsession\nsudo usermod -a -G ssl-cert xrdp\nsudo passwd ubuntu"
}
