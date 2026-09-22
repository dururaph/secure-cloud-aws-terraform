terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

resource "aws_vpc" "secure_cloud_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "secure-cloud-vpc"
    Project     = "SecureCloudProject"
    Environment = "dev"
  }
}



resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.secure_cloud_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "secure-cloud-public-1"
    Project     = "SecureCloudProject"
    Environment = "dev"
  }
}
# Internet Gateway: connects the VPC to the internet
resource "aws_internet_gateway" "secure_cloud_igw" {
  vpc_id = aws_vpc.secure_cloud_vpc.id

  tags = {
    Name        = "secure-cloud-igw"
    Project     = "SecureCloudProject"
    Environment = "dev"
  }
}

# Route table used by public subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.secure_cloud_vpc.id

  tags = {
    Name        = "secure-cloud-public-rt"
    Project     = "SecureCloudProject"
    Environment = "dev"
  }
}

# Send all non-local IPv4 traffic to the Internet Gateway
resource "aws_route" "public_internet_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.secure_cloud_igw.id
}

# Make public_subnet_1 use the public route table
resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.secure_cloud_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-west-2a"

  tags = {
    Name        = "secure-cloud-private-1"
    Project     = "SecureCloudProject"
    Environment = "dev"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.secure_cloud_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-west-2b"
  map_public_ip_on_launch = true

  tags = {
    Name        = "secure-cloud-public-2"
    Project     = "SecureCloudProject"
    Environment = "dev"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.secure_cloud_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-west-2b"

  tags = {
    Name        = "secure-cloud-private-2"
    Project     = "SecureCloudProject"
    Environment = "dev"
  }
}
resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}
# Route table for private subnets
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.secure_cloud_vpc.id

  tags = {
    Name        = "secure-cloud-private-rt"
    Project     = "SecureCloudProject"
    Environment = "dev"
  }
}

# Associate private subnet 1 with the private route table
resource "aws_route_table_association" "private_subnet_1_association" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}

# Associate private subnet 2 with the private route table
resource "aws_route_table_association" "private_subnet_2_association" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}
# Security group for public-facing EC2 instances
resource "aws_security_group" "public_sg" {
  name        = "secure-cloud-public-sg"
  description = "Security group for public-facing instances"
  vpc_id      = aws_vpc.secure_cloud_vpc.id

  ingress {
    description = "Allow HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "secure-cloud-public-sg"
    Project     = "SecureCloudProject"
    Environment = "dev"
  }
}

# Security group for private EC2 instances
resource "aws_security_group" "private_sg" {
  name        = "secure-cloud-private-sg"
  description = "Security group for private instances"
  vpc_id      = aws_vpc.secure_cloud_vpc.id

  ingress {
    description     = "Allow application traffic only from public tier"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "secure-cloud-private-sg"
    Project     = "SecureCloudProject"
    Environment = "dev"
  }
}
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "public_server" {
  ami                         = "ami-01309f00031b5ec72"
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_subnet_1.id
  vpc_security_group_ids      = [aws_security_group.public_sg.id]
  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name

  user_data = <<-EOF
            #!/bin/bash

            # Configure public web server
            dnf install -y nginx
            systemctl enable nginx
            systemctl start nginx

            # Ensure AWS Systems Manager Agent is enabled
            systemctl enable amazon-ssm-agent
            systemctl restart amazon-ssm-agent

            # Create test web page
            echo "<h1>Secure Cloud Public Server</h1>" > /usr/share/nginx/html/index.html
            EOF

  tags = {
    Name        = "secure-cloud-public-server"
    Project     = "SecureCloudProject"
    Environment = "dev"
  }
}

resource "aws_instance" "private_server" {
  ami                    = "ami-01309f00031b5ec72"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_subnet_1.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]

  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name

  tags = {
    Name        = "secure-cloud-private-server"
    Project     = "SecureCloudProject"
    Environment = "dev"
  }
}
# IAM role that EC2 instances can assume
resource "aws_iam_role" "ec2_ssm_role" {
  name = "secure-cloud-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project     = "SecureCloudProject"
    Environment = "dev"
  }
}

# Attach AWS-managed Systems Manager permissions
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile connects the IAM role to EC2
resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "secure-cloud-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}
# Security group for Systems Manager VPC endpoints
resource "aws_security_group" "ssm_endpoint_sg" {
  name        = "secure-cloud-ssm-endpoint-sg"
  description = "Allow private instances to reach SSM endpoints over HTTPS"
  vpc_id      = aws_vpc.secure_cloud_vpc.id

  ingress {
    description = "HTTPS from VPC instances to SSM endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "secure-cloud-ssm-endpoint-sg"
    Project     = "SecureCloudProject"
    Environment = "dev"
  }
}
# Private endpoint for the Systems Manager API
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.secure_cloud_vpc.id
  service_name        = "com.amazonaws.us-west-2.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_subnet_1.id]
  security_group_ids  = [aws_security_group.ssm_endpoint_sg.id]
  private_dns_enabled = true

  tags = {
    Name        = "secure-cloud-ssm-endpoint"
    Project     = "SecureCloudProject"
    Environment = "dev"
  }
}

# Private endpoint used for SSM Agent / Session Manager communication
resource "aws_vpc_endpoint" "ssm_messages" {
  vpc_id              = aws_vpc.secure_cloud_vpc.id
  service_name        = "com.amazonaws.us-west-2.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_subnet_1.id]
  security_group_ids  = [aws_security_group.ssm_endpoint_sg.id]
  private_dns_enabled = true

  tags = {
    Name        = "secure-cloud-ssmmessages-endpoint"
    Project     = "SecureCloudProject"
    Environment = "dev"
  }
}
# Monitor sustained high CPU on the public web server
resource "aws_cloudwatch_metric_alarm" "public_server_high_cpu" {
  alarm_name          = "secure-cloud-public-high-cpu"
  alarm_description   = "Alert when the public server CPU remains above 80 percent"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "missing"

  dimensions = {
    InstanceId = aws_instance.public_server.id
  }

  tags = {
    Project     = "SecureCloudProject"
    Environment = "dev"
  }
}

# Monitor sustained high CPU on the private backend server
resource "aws_cloudwatch_metric_alarm" "private_server_high_cpu" {
  alarm_name          = "secure-cloud-private-high-cpu"
  alarm_description   = "Alert when the private server CPU remains above 80 percent"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "missing"

  dimensions = {
    InstanceId = aws_instance.private_server.id
  }

  tags = {
    Project     = "SecureCloudProject"
    Environment = "dev"
  }
}