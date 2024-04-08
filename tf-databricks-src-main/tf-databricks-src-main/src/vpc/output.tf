output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "vpc_cidr_blocks" {
  value = concat(
    [aws_vpc.vpc.cidr_block],
    aws_vpc_ipv4_cidr_block_association.secondary_cidrs.*.cidr_block
  )
}

output "private_subnet_ids" {
  value = aws_subnet.private_subnets.*.id
}

output "public_subnet_ids" {
  value = aws_subnet.public_subnets.*.id
}

output "security_group_id" {
  value = aws_security_group.databricks_sg.id
}