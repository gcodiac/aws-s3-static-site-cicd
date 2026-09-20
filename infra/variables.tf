variable "bucket_name" {
  description = "Globally unique name for the S3 bucket"
  type        = string
}

variable "region" {
  description = "AWS region for the bucket"
  type        = string
  default     = "eu-west-1"
}
