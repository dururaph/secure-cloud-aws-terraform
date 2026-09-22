output "vpc_id" {
  description = "ID of the Secure Cloud VPC"
  value       = aws_vpc.secure_cloud_vpc.id
}

output "public_server_instance_id" {
  description = "Instance ID of the public EC2 server"
  value       = aws_instance.public_server.id
}

output "public_server_public_ip" {
  description = "Public IP address of the public EC2 server"
  value       = aws_instance.public_server.public_ip
}

output "public_server_private_ip" {
  description = "Private IP address of the public EC2 server"
  value       = aws_instance.public_server.private_ip
}

output "private_server_instance_id" {
  description = "Instance ID of the private EC2 server"
  value       = aws_instance.private_server.id
}

output "private_server_private_ip" {
  description = "Private IP address of the private EC2 server"
  value       = aws_instance.private_server.private_ip
}

output "ssm_endpoint_id" {
  description = "VPC endpoint ID for AWS Systems Manager"
  value       = aws_vpc_endpoint.ssm.id
}

output "ssm_messages_endpoint_id" {
  description = "VPC endpoint ID for SSM Session Manager messaging"
  value       = aws_vpc_endpoint.ssm_messages.id
}