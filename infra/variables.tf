variable "bucket_name" {
  description = "Globally unique name for the S3 bucket"
  type        = string

  # Optional: uncomment and replace with a name that nobody else has used.
  # Bucket names are unique across all of AWS, so copying this one will fail.
  # default = "my-unique-bucket-name"
}

variable "region" {
  description = "AWS region for the bucket"
  type        = string
  default     = "eu-west-1"
}
