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

# ---------------------------------------------------------
# אוטומציה: תור הודעות (SQS) לקליטת קבצים
# ---------------------------------------------------------

resource "aws_sqs_queue" "ingest_queue" {
  name                      = "${var.environment}-ingest-queue"
  message_retention_seconds = 86400 # הודעות נשמרות ליום אחד
  visibility_timeout_seconds = 60   # זמן לעיבוד הודעה לפני שהיא חוזרת לתור
}

# הרשאות: נותנים ל-S3 אישור לשלוח הודעות לתור הזה
resource "aws_sqs_queue_policy" "ingest_queue_policy" {
  queue_url = aws_sqs_queue.ingest_queue.id
  policy    = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.ingest_queue.arn}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${aws_s3_bucket.ingest_bucket.arn}"
        }
      }
    }
  ]
}
POLICY
}

# הטריגר: חיבור הדלי לתור (כל קובץ geojson שנוצר שולח הודעה)
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.ingest_bucket.id

  queue {
    queue_arn     = aws_sqs_queue.ingest_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".geojson"
  }
}

# ---------------------------------------------------------
# Outputs (כדי שנוכל להשתמש בזה בקוד)
# ---------------------------------------------------------

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.ingest_bucket.id
}

output "sqs_queue_url" {
  description = "URL of the SQS Queue"
  value       = aws_sqs_queue.ingest_queue.url
}