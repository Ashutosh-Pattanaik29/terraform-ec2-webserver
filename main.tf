data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

# Reference the existing shared training VPC
data "aws_vpc" "training_vpc" {
  id = "vpc-0592cb2ddcc9797a5"
}

# Create and attach an Internet Gateway to the training VPC
resource "aws_internet_gateway" "training_igw" {
  vpc_id = data.aws_vpc.training_vpc.id

  tags = {
    Name = "terraform-web-igw"
  }
}

# Create a new Public Subnet using an unused CIDR block inside 10.0.0.0/24
resource "aws_subnet" "public_subnet" {
  vpc_id                  = data.aws_vpc.training_vpc.id
  cidr_block              = "10.0.0.128/28"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "terraform-public-subnet"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = data.aws_vpc.training_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.training_igw.id
  }

  tags = {
    Name = "terraform-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "web_sg" {
  name        = "terraform-web-sg-ashutosh"
  description = "Allow HTTP and SSH inbound traffic"
  vpc_id      = data.aws_vpc.training_vpc.id

  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-web-sg"
  }
}

resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-SCRIPT
              #!/bin/bash
              dnf update -y
              dnf install -y nginx
              systemctl start nginx
              systemctl enable nginx
              cat << 'HTML' > /usr/share/nginx/html/index.html
              <!DOCTYPE html>
              <html>
              <head>
                <title>Terraform AWS Web Server</title>
                <style>
                  body { font-family: Arial, sans-serif; text-align: center; margin-top: 80px; background-color: #f4f6f8; }
                  .card { background: white; padding: 40px; border-radius: 10px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); display: inline-block; }
                  h1 { color: #232f3e; }
                  p { color: #555; font-size: 18px; }
                </style>
              </head>
              <body>
                <div class="card">
                  <h1>Deployment Successful!</h1>
                  <p>This Linux EC2 Web Server was provisioned automatically using <strong>Terraform</strong>.</p>
                </div>
              </body>
              </html>
              HTML
              SCRIPT

  tags = {
    Name = "Terraform-Web-Server"
  }
}
