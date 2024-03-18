# Create a Key Pair
resource "aws_key_pair" "mobann-key" {
  key_name   = "mobann-key"
  public_key = tls_private_key.mobann-key.public_key_openssh
}

# Generate a new RSA key pair
resource "tls_private_key" "mobann-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# create a local file to store the private key
resource "local_file" "mobann-key" {
  filename = "mobann-key.pem"
  content  = tls_private_key.mobann-key.private_key_pem
}

# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon-linux-2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*"]
  }
}

# Create a default VPC
# resource "aws_default_vpc" "default" {
# }

# Create a Security Group for the EC2 instance
resource "aws_security_group" "mobann-sg" {
  name        = "allow_web_traffic"
  description = "Allow inbound traffic from port 22 and 80"
  #   vpc_id      = aws_default_vpc.default.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP Connections"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Mobann Security Group"
  }
}

# Create an EC2 Instance
resource "aws_instance" "mobann-instance" {
  ami             = data.aws_ami.amazon-linux-2.id
  instance_type   = "t3.micro"
  key_name        = aws_key_pair.mobann-key.key_name
  vpc_security_group_ids = [aws_security_group.mobann-sg.id]
  user_data       = file("userdata.tpl")

  tags = {
    Name = "Mobann Instance"
  }
}

# Create a launch template
resource "aws_launch_template" "mobann-launch-template" {
  name                   = "mobann-lt"
  image_id               = data.aws_ami.amazon-linux-2.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.mobann-key.key_name
  vpc_security_group_ids = [aws_security_group.mobann-sg.id]
  user_data              = filebase64("userdata.tpl")

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "Mobann Instance"
    }
  }
}

# Create an Auto Scaling Group
resource "aws_autoscaling_group" "mobann-asg" {
  desired_capacity   = 2
  max_size           = 3
  min_size           = 2
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  launch_template {
    id      = aws_launch_template.mobann-launch-template.id
    version = "$Latest"
  }
}
