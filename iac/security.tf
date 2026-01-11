# --- Security Group for Application (Lambda/EC2/Fargate) ---
resource "aws_security_group" "app_sg" {
  name        = "${var.environment}-app-sg"
  description = "Security group for the application"
  vpc_id      = aws_vpc.main.id # תיקון: חזרנו להתייחסות למשאב עצמו

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
  vpc_id      = aws_vpc.main.id # תיקון: חזרנו להתייחסות למשאב עצמו

  # חוק כניסה: מאפשר לכל הרשת הפנימית לגשת לפורט 5432
  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] 
  }

  # חוק יציאה: מאפשר ל-DB לדבר החוצה
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-rds-sg"
  }
}