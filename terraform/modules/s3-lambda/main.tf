variable "student_id" { type = string }

resource "aws_s3_bucket" "assets" {
  bucket = "bedrock-assets-${var.student_id}"
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket                  = aws_s3_bucket.assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "lambda" {
  name = "bedrock-asset-processor-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_scoped" {
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.assets.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:us-east-1:*:*"
      }
    ]
  })
}

resource "aws_lambda_function" "processor" {
  function_name    = "bedrock-asset-processor"
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  filename         = "../../lambda/function.zip"
  source_code_hash = filebase64sha256("../../lambda/function.zip")
  timeout          = 10
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.assets.arn
}

resource "aws_s3_bucket_notification" "trigger" {
  bucket = aws_s3_bucket.assets.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events               = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.allow_s3]
}

output "bucket_name" { value = aws_s3_bucket.assets.id }

output "bucket_arn" { value = aws_s3_bucket.assets.arn }
