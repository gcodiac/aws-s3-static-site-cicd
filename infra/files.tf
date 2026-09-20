locals {
  site_root = "${path.module}/.."

  # Only the website files are uploaded, never the repository plumbing.
  files = setunion(
    fileset(local.site_root, "*.html"),
    fileset(local.site_root, "{css,js,assets}/**"),
  )

  content_types = {
    html = "text/html"
    css  = "text/css"
    js   = "application/javascript"
    svg  = "image/svg+xml"
    png  = "image/png"
  }
}

# One object per site file. The etag makes Terraform re-upload a file when it changes.
resource "aws_s3_object" "site" {
  for_each = local.files

  bucket       = aws_s3_bucket.site.id
  key          = each.value
  source       = "${local.site_root}/${each.value}"
  etag         = filemd5("${local.site_root}/${each.value}")
  content_type = lookup(local.content_types, reverse(split(".", each.value))[0], "application/octet-stream")
}
