# --- IAM Role (הזהות של הלמבדה) ---
resource "aws_iam_role" "lambda_role" {
  name = "${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# הרשאות בסיסיות (לוגים + גישה לרשת)
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# הרשאה לקרוא מה-S3 הספציפי שלנו
resource "aws_iam_role_policy" "s3_access" {
  name = "s3_access_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.ingest_bucket.arn,
        "${aws_s3_bucket.ingest_bucket.arn}/*"
      ]
    }]
  })
}

# --- Lambda Function (הקונטיינר שלנו) ---
resource "aws_lambda_function" "processor" {
  function_name = "${var.environment}-geo-processor"
  role          = aws_iam_role.lambda_role.arn
  package_type  = "Image"
  
  # שימוש בכתובת ה-ECR שיצרנו + התגית latest
  image_uri     = "${aws_ecr_repository.app_repo.repository_url}:latest"
  
  timeout       = 60  # נותן לו דקה לעבד קובץ (אפשר להגדיל)
  memory_size   = 512 # חצי ג'יגה זיכרון

  # חיבור לרשת (כדי שיוכל לדבר עם ה-RDS ב-Private Subnet)
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.app_sg.id]
  }

  # משתני סביבה (הסודות עוברים מכאן לקוד)
  environment {
    variables = {
      DB_HOST = aws_db_instance.postgres.address
      DB_NAME = aws_db_instance.postgres.db_name
      DB_USER = aws_db_instance.postgres.username
      DB_PASS = aws_db_instance.postgres.password # (בפרודקשן אמיתי היינו מושכים מ-Secrets Manager)
    }
  }
}

# --- S3 Trigger (ההדק) ---
# נותן ל-S3 רשות להפעיל את הלמבדה
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ingest_bucket.arn
}

# מגדיר שכל קובץ עם סיומת .json או .geojson יפעיל את הלמבדה
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.ingest_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".geojson"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}