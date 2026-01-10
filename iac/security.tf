# --- Security Group for Application (Lambda/EC2/Fargate) ---
resource "aws_security_group" "app_sg" {
  name        = "${var.environment}-app-sg"
  description = "Security group for the application"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-app-sg"
  }
}

# --- Security Group for RDS ---
resource "aws_security_group" "rds_sg" {
  name        = "${var.environment}-rds-sg"
  description = "Security group for the database"
  vpc_id      = aws_vpc.main.id

  # מאפשר כניסה רק ממי שיש לו את ה-Security Group של האפליקציה
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  tags = {
    Name = "${var.environment}-rds-sg"
  }
}