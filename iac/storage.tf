resource "aws_s3_bucket" "ingest_bucket" {
  # השם חייב להיות ייחודי גלובלית, אז נוסיף לו סיומת רנדומלית אוטומטית בהמשך
  bucket_prefix = "asterra-ingest-" 
  force_destroy = true # מוחק את הדלי גם אם יש בו קבצים (רק לפיתוח!)

  tags = {
    Name = "${var.environment}-ingest-bucket"
  }
}

# חסימת גישה ציבורית לדלי (Best Practice)
resource "aws_s3_bucket_public_access_block" "ingest_bucket_block" {
  bucket = aws_s3_bucket.ingest_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}