# יצירת סיסמה רנדומלית למסד הנתונים
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

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
  engine_version         = "16.3" # גרסה עדכנית
  instance_class         = "db.t3.micro" # Free Tier Eligible
  allocated_storage      = 20
  storage_type           = "gp2"
  username               = "dbadmin"
  password               = random_password.db_password.result
  db_name                = "asterragis"
  
  skip_final_snapshot    = true # חוסך זמן במחיקה
  publicly_accessible    = false # אבטחה: לא נגיש מהאינטרנט
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.default.name

  tags = {
    Name = "${var.environment}-postgres-db"
  }
}

# שמירת הסיסמה ב-AWS Secrets Manager (בונוס אבטחה רציני!)
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${var.environment}/db/credentials"
  recovery_window_in_days = 0 # מחיקה מידית כשהורסים
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