resource "aws_security_group" "databricks_sg" {
  name        = "${var.team}-${var.product}-${var.env}-sg-${var.aws_region}"
  description = "${var.team}-${var.product}-${var.env}-sg-${var.aws_region}"
  vpc_id      = aws_vpc.vpc.id

  // Ingress rule to allow TCP traffic from the same security group
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  // Ingress rule to allow UDP traffic from the same security group
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "udp"
    self      = true
  }

  # Egress (Outbound) Rules
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.team}-${var.product}-${var.env}-sg-${var.aws_region}"
  }
}