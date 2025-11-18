output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block associated with the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "public_route_table_id" {
  description = "Route table ID for public subnets"
  value       = aws_route_table.public_rt.id
}

output "private_route_table_id" {
  description = "Route table ID for private subnets"
  value       = aws_route_table.private_rt.id
}

output "nat_gateway_id" {
  description = "ID of the NAT gateway"
  value       = aws_nat_gateway.nat_gw.id
}

output "flow_log_id" {
  description = "ID of the VPC flow log (null if disabled)"
  value       = try(aws_flow_log.vpc[0].id, null)
}

output "gateway_endpoint_ids" {
  description = "Gateway VPC endpoint IDs"
  value = compact([
    try(aws_vpc_endpoint.s3[0].id, null),
    try(aws_vpc_endpoint.dynamodb[0].id, null)
  ])
}

output "ssm_endpoint_ids" {
  description = "Interface VPC endpoint IDs created for SSM"
  value = compact([
    try(aws_vpc_endpoint.ssm[0].id, null),
    try(aws_vpc_endpoint.ssm_messages[0].id, null),
    try(aws_vpc_endpoint.ec2_messages[0].id, null)
  ])
}

output "interface_endpoint_security_group_id" {
  description = "Security group protecting interface endpoints"
  value       = try(aws_security_group.interface_endpoints[0].id, null)
}
