## OPTIONAL: a web application firewall (AWS WAF) in front of CloudFront.
##
## Off by default. Uncomment together with acm.tf and dns.tf, then uncomment the
## web_acl_id line in cloudfront.tf. WAF adds a small monthly charge.

# # A web application firewall in front of CloudFront. It must be created in us-east-1.
# resource "aws_wafv2_web_acl" "site" {
#   provider = aws.us_east_1
#   name     = "${var.bucket_name}-waf"
#   scope    = "CLOUDFRONT"
#
#   default_action {
#     allow {}
#   }
#
#   # AWS's own rule set for common attacks, such as bad inputs and known exploit patterns.
#   rule {
#     name     = "aws-common-rules"
#     priority = 1
#
#     override_action {
#       none {}
#     }
#
#     statement {
#       managed_rule_group_statement {
#         name        = "AWSManagedRulesCommonRuleSet"
#         vendor_name = "AWS"
#       }
#     }
#
#     visibility_config {
#       cloudwatch_metrics_enabled = true
#       metric_name                = "aws-common-rules"
#       sampled_requests_enabled   = true
#     }
#   }
#
#   visibility_config {
#     cloudwatch_metrics_enabled = true
#     metric_name                = "${var.bucket_name}-waf"
#     sampled_requests_enabled   = true
#   }
# }
