# --- Your IP, so SSH is locked down to just you ---
# Find it with: curl ifconfig.me
variable "my_ip" {
  description = "Your public IP in CIDR form, e.g. 203.0.113.4/32"
  type        = string
}

# --- Security group: SSH only from your IP, HTTP open to everyone ---
resource "aws_security_group" "web" {
  name        = "study-web-sg"
  description = "Allow SSH from my IP and HTTP from anywhere"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from my IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "HTTP from anywhere"
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
    Name = "study-web-sg"
  }
}

# --- Key pair for SSH access ---
# Generate locally first: ssh-keygen -t ed25519 -f study-key -N ""
variable "public_key_path" {
  description = "Path to your SSH public key file"
  type        = string
  default     = "study-key.pub"
}

resource "aws_key_pair" "study" {
  key_name   = "study-key"
  public_key = file(var.public_key_path)
}

# --- Latest Amazon Linux 2023 AMI, so this stays current automatically ---
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# --- EC2 instance ---
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.study.key_name

  tags = {
    Name = "study-ec2"
  }
}
