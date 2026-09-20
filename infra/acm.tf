## OPTIONAL: an HTTPS certificate for your own domain (AWS Certificate Manager).
##
## Off by default. To turn on a custom domain, uncomment acm.tf, dns.tf and waf.tf
## (select the whole file and press Ctrl+/ in VS Code), then follow the steps in the
## README section "Optional: custom domain, certificate and WAF".
##
## You need a domain whose DNS is hosted in Route 53.

# # CloudFront only accepts certificates from us-east-1, whatever region the rest of the stack uses.
# provider "aws" {
#   alias  = "us_east_1"
#   region = "us-east-1"
# }
#
# variable "domain_name" {
#   description = "The address visitors will use, for example site.example.com"
#   type        = string
# }
#
# resource "aws_acm_certificate" "site" {
#   provider          = aws.us_east_1
#   domain_name       = var.domain_name
#   validation_method = "DNS"
#
#   lifecycle {
#     create_before_destroy = true
#   }
# }
#
# # Waits until AWS has confirmed the DNS validation records, so the certificate is usable.
# resource "aws_acm_certificate_validation" "site" {
#   provider                = aws.us_east_1
#   certificate_arn         = aws_acm_certificate.site.arn
#   validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
# }
