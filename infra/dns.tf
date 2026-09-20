## OPTIONAL: Route 53 records for your own domain.
##
## Off by default. Uncomment together with acm.tf. It creates the records ACM needs to
## validate the certificate, and the record that points your domain at CloudFront.

# variable "hosted_zone_name" {
#   description = "The Route 53 hosted zone that already exists for your domain, for example example.com"
#   type        = string
# }
#
# data "aws_route53_zone" "site" {
#   name = var.hosted_zone_name
# }
#
# # The records ACM asks for, to prove you own the domain.
# resource "aws_route53_record" "validation" {
#   for_each = {
#     for option in aws_acm_certificate.site.domain_validation_options : option.domain_name => {
#       name   = option.resource_record_name
#       record = option.resource_record_value
#       type   = option.resource_record_type
#     }
#   }
#
#   zone_id         = data.aws_route53_zone.site.zone_id
#   name            = each.value.name
#   type            = each.value.type
#   records         = [each.value.record]
#   ttl             = 60
#   allow_overwrite = true
# }
#
# # Points your domain at the CloudFront distribution.
# resource "aws_route53_record" "site" {
#   zone_id = data.aws_route53_zone.site.zone_id
#   name    = var.domain_name
#   type    = "A"
#
#   alias {
#     name                   = aws_cloudfront_distribution.site.domain_name
#     zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
#     evaluate_target_health = false
#   }
# }
#
# output "custom_url" {
#   value = "https://${var.domain_name}"
# }
