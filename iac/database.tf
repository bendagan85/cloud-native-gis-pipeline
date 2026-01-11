# יצירת סיסמה רנדומלית למסד הנתונים
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# (הסרנו מכאן את ה-Security Group כי הוא נמצא ב-security.tf)

# ---------------------------------------------------------
# הגדרות הרשת והדאטה-בייס
# ---------------------------------------------------------

# קבוצת ה-Subnets (איפה ה-DB יישב - ברשת הפרטית בלבד)
resource "aws_db_subnet_group" "default" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.environment}-db-subnet-group"
  }
}

resource "aws_db_instance" "postgres" {
  identifier             = "${var.environment}-asterra-db"
  engine                 = "postgres"
  engine_version         = "16.3" 
  instance_class         = "db.t3.micro" 
  allocated_storage      = 20
  storage_type           = "gp2"
  username               = "dbadmin"
  password               = random_password.db_password.result
  db_name                = "asterragis"
   
  skip_final_snapshot    = true 
  publicly_accessible    = false 
  
  # טרהפורם יקרא את ה-ID הזה מהקובץ security.tf
  vpc_security_group_ids = [aws_security_group.rds_sg.id] 
  
  db_subnet_group_name   = aws_db_subnet_group.default.name

  tags = {
    Name = "${var.environment}-postgres-db"
  }
}

# שמירת הסיסמה ב-AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${var.environment}/db/credentials"
  recovery_window_in_days = 0 
}

resource "aws_secretsmanager_secret_version" "db_credentials_val" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = aws_db_instance.postgres.username
    password = random_password.db_password.result
    host     = aws_db_instance.postgres.address
    dbname   = aws_db_instance.postgres.db_name
  })
}

# ---------------------------------------------------------
# Outputs
# ---------------------------------------------------------

output "rds_endpoint" {
  description = "The endpoint of the RDS instance"
  value       = aws_db_instance.postgres.address
}

output "rds_db_name" {
  description = "The name of the database"
  value       = aws_db_instance.postgres.db_name
}

output "rds_username" {
  description = "The master username for the database"
  value       = aws_db_instance.postgres.username
}

output "rds_password" {
  description = "The random password created by Terraform"
  value       = random_password.db_password.result
  sensitive   = true 
}