# Cloud Launchpad: CI/CD with GitHub Actions (end)

Deploy the site automatically. When you push to `main`, GitHub Actions applies the Terraform,
uploads the site to S3 and clears the CloudFront cache, signing in to AWS with OIDC so there are
no access keys stored in GitHub. This is the finished version. To build it yourself, start from
the `6-cicd-start` branch.

## Architecture

![AWS architecture: a git push starts a GitHub Actions pipeline that gets temporary credentials from an IAM role through OIDC, runs Terraform, uploads the files to a private S3 bucket and invalidates the CloudFront cache](assets/images/architecture.svg)

The diagram shows the full platform. This stage adds the pipeline at the bottom and connects it
to the private S3 bucket and CloudFront from the previous stage:

1. **`git push`** starts the workflow.
2. **Checkout and checks:** the workflow fetches the code and validates it.
3. **OIDC:** GitHub proves who it is, and AWS hands back temporary credentials for an IAM role.
4. **Terraform** plans and applies the infrastructure.
5. **Upload to S3:** the site files are synced to the bucket.
6. **CloudFront invalidation:** the cache is cleared so visitors see the change.

Route 53, WAF and Certificate Manager are not part of this stage. Visitors use the
`*.cloudfront.net` address.

---

## Prerequisites

- Everything from the previous stage: an AWS account with the AWS CLI configured, and Terraform
- A GitHub repository you can push to, with Actions enabled (a fork of this one works)
- `make`, which is optional

## Run the site locally

```bash
git clone git@github.com:gcodiac/aws-s3-static-site-cicd.git
cd aws-s3-static-site-cicd
git checkout 7-cicd-end

make serve    # http://localhost:8080
```

## How it works

Two things changed from the previous stage:

- **Terraform no longer uploads the site files.** It builds the infrastructure, and the pipeline uploads the content.
- **State lives in S3.** [infra/backend.tf](infra/backend.tf) stores it in a state bucket with S3's native locking, because every workflow run starts on a fresh machine. That needs Terraform 1.10 or newer, which `versions.tf` now requires.

The pipeline is one file, [.github/workflows/deploy.yml](.github/workflows/deploy.yml):

| Trigger | What it does |
| --- | --- |
| Pull request to `main` | Signs in to AWS, then runs `terraform fmt -check`, `init`, `validate` and `plan`. Nothing changes in AWS. |
| Push to `main` | Does the same checks, then `terraform apply`, uploads the site with `aws s3 sync`, and creates a CloudFront invalidation. |

It signs in with OIDC (`id-token: write`), so there are no AWS keys stored in GitHub. The IAM role is
what makes that safe, and you create it by hand in the setup below.

## Setup

CI cannot create its own login, so you set these up by hand, once.

1. **State bucket:** create a second S3 bucket to hold the Terraform state, with versioning turned on. Every workflow run starts on a fresh machine, so the state has to live somewhere shared.
2. **OIDC provider:** in the IAM console go to *Identity providers*, then *Add provider*. Choose *OpenID Connect*, set the provider URL to `https://token.actions.githubusercontent.com` and the audience to `sts.amazonaws.com`, then click *Add provider*. An account only needs one of these, so skip this step if it already exists.
3. **Find your GitHub IDs:** GitHub now puts the numeric owner and repository IDs into the token it issues, so a name alone is no longer what AWS sees. Numeric IDs are never reused, which stops someone from deleting a repository, registering the same name and minting tokens your role would accept. Find yours:

   ```bash
   curl -s https://api.github.com/repos/<owner>/<repo> | jq '{owner_id: .owner.id, repo_id: .id}'
   ```

4. **IAM role:** in IAM go to *Roles*, then *Create role*. Choose *Web identity*, select the GitHub provider and the audience `sts.amazonaws.com`, and continue without attaching any permissions yet. Name it `cloud-launchpad-github-actions`. Then open the role, choose *Trust relationships*, *Edit trust policy*, and paste this, with your own values:

   <details>
   <summary>Trust policy</summary>

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Principal": {
         "Federated": "arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com"
       },
       "Action": "sts:AssumeRoleWithWebIdentity",
       "Condition": {
         "StringEquals": {
           "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
         },
         "StringLike": {
           "token.actions.githubusercontent.com:sub": [
             "repo:<owner>@<owner_id>/<repo>@<repo_id>:ref:refs/heads/main",
             "repo:<owner>@<owner_id>/<repo>@<repo_id>:pull_request",
             "repo:<owner>/<repo>:ref:refs/heads/main",
             "repo:<owner>/<repo>:pull_request"
           ]
         }
       }
     }]
   }
   ```

   </details>

   The `sub` condition is the whole security boundary. It names one repository, and only its `main` branch and its pull requests. Never write it as `repo:<owner>/*`, and never leave it out: without it, any GitHub Actions workflow in any repository could assume your role.

   The first two lines are the ID form that GitHub is rolling out. The last two are the classic form, for repositories that have not switched yet. Once you know which one your repository uses, delete the other pair. If a run fails with `Not authorized to perform sts:AssumeRoleWithWebIdentity`, the claim did not match. Look up the failed `AssumeRoleWithWebIdentity` event in CloudTrail to see the exact `sub` value GitHub sent.

5. **Permissions:** on the same role, choose *Add permissions*, *Create inline policy*, *JSON*, and paste this. Replace `<site-bucket>` and `<state-bucket>` with your two bucket names. Name it `cloud-launchpad-deploy`.

   <details>
   <summary>Permissions policy</summary>

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "SiteBucket",
         "Effect": "Allow",
         "Action": "s3:*",
         "Resource": [
           "arn:aws:s3:::<site-bucket>",
           "arn:aws:s3:::<site-bucket>/*"
         ]
       },
       {
         "Sid": "TerraformStateList",
         "Effect": "Allow",
         "Action": "s3:ListBucket",
         "Resource": "arn:aws:s3:::<state-bucket>"
       },
       {
         "Sid": "TerraformStateObjects",
         "Effect": "Allow",
         "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
         "Resource": "arn:aws:s3:::<state-bucket>/*"
       },
       {
         "Sid": "CloudFront",
         "Effect": "Allow",
         "Action": [
           "cloudfront:CreateDistribution",
           "cloudfront:GetDistribution",
           "cloudfront:GetDistributionConfig",
           "cloudfront:UpdateDistribution",
           "cloudfront:DeleteDistribution",
           "cloudfront:ListDistributions",
           "cloudfront:TagResource",
           "cloudfront:ListTagsForResource",
           "cloudfront:CreateOriginAccessControl",
           "cloudfront:GetOriginAccessControl",
           "cloudfront:UpdateOriginAccessControl",
           "cloudfront:DeleteOriginAccessControl",
           "cloudfront:ListOriginAccessControls",
           "cloudfront:ListCachePolicies",
           "cloudfront:GetCachePolicy",
           "cloudfront:CreateInvalidation",
           "cloudfront:GetInvalidation",
           "cloudfront:ListInvalidations"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

   </details>

   What each part is for:

   | Statement | Why the pipeline needs it |
   | --- | --- |
   | `SiteBucket` | Terraform creates and configures the site bucket, and `aws s3 sync` uploads to it. This is limited to that one bucket. |
   | `TerraformStateList` and `TerraformStateObjects` | Terraform reads and writes its state file, and its lock file, in the state bucket. Nothing else in that bucket is reachable. |
   | `CloudFront` | Terraform manages the distribution and the Origin Access Control, and the pipeline clears the cache. CloudFront cannot limit *create* actions to one resource, so this uses `*`. |

   There is no `iam:*`, no access to other buckets and no `AdministratorAccess`. The role cannot create users, read other data or touch other services. If a run fails with `AccessDenied`, the error names the missing action, so add exactly that one.

6. **Repository variables:** in the GitHub repository settings, under *Secrets and variables*, *Actions*, *Variables*, add `AWS_ROLE_ARN` (the role's ARN), `AWS_REGION`, `TF_STATE_BUCKET` and `BUCKET_NAME`.

## First deployment

1. Do the setup above.
2. If you already deployed the infrastructure from your laptop, move its state into the state bucket:

   ```bash
   cd infra
   terraform init -migrate-state \
     -backend-config="bucket=<state-bucket>" \
     -backend-config="region=<region>"
   ```

   Starting fresh? Skip this. The first pipeline run creates everything.
3. Push to `main`, open the **Actions** tab and watch the run.
4. When it finishes, open the site. The address is in the run's Terraform apply log as `cloudfront_url`, and in the CloudFront console as the distribution's domain name.

From now on, edit the site, push, and the pipeline deploys it. To try the pull request path, open a
pull request and read the plan in the workflow log.

### If something fails

| Symptom | Likely cause |
| --- | --- |
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | The trust policy's `sub` does not match. Look up the failed event in CloudTrail to see the exact value GitHub sent. |
| `AccessDenied` on an S3 or CloudFront action | The role's permissions policy is missing that action. The error names it, so add it. |
| `Error acquiring the state lock` | Another run is using the state, or a run was cancelled. Wait, or delete the `.tflock` object in the state bucket. |
| The site shows old content | Give the cache invalidation a minute, then refresh. |

## Optional: custom domain, certificate and WAF

The diagram also shows Route 53, Certificate Manager and WAF. They are **off by default**, because they
need a domain and add cost, but the Terraform is already in the repository, commented out, so you can
try them:

- [infra/acm.tf](infra/acm.tf): an HTTPS certificate for your domain
- [infra/dns.tf](infra/dns.tf): the Route 53 records that validate the certificate and point the domain at CloudFront
- [infra/waf.tf](infra/waf.tf): a web application firewall using AWS's common-attacks rule set

You need a domain whose DNS is already hosted in Route 53.

1. **Uncomment the three files.** In VS Code, open each one, select everything and press `Ctrl+/`.
2. **Uncomment the two lines and the certificate block in [infra/cloudfront.tf](infra/cloudfront.tf):** `aliases`, `web_acl_id`, and the second `viewer_certificate` (delete the first one).
3. **Set your domain:** uncomment `domain_name` and `hosted_zone_name` in `infra/terraform.tfvars`.
4. **For the pipeline:** add the repository variables `DOMAIN_NAME` and `HOSTED_ZONE_NAME`, and uncomment the two `TF_VAR_` lines in `.github/workflows/deploy.yml`.
5. **Give the role more permissions.** Add these statements to the role's inline policy:

   <details>
   <summary>Extra permissions</summary>

   ```json
   {
     "Sid": "Certificates",
     "Effect": "Allow",
     "Action": [
       "acm:RequestCertificate",
       "acm:DescribeCertificate",
       "acm:DeleteCertificate",
       "acm:AddTagsToCertificate",
       "acm:ListTagsForCertificate"
     ],
     "Resource": "*"
   },
   {
     "Sid": "DnsRecords",
     "Effect": "Allow",
     "Action": [
       "route53:GetHostedZone",
       "route53:ListResourceRecordSets",
       "route53:ChangeResourceRecordSets",
       "route53:ListTagsForResource"
     ],
     "Resource": "arn:aws:route53:::hostedzone/<zone-id>"
   },
   {
     "Sid": "DnsLookups",
     "Effect": "Allow",
     "Action": ["route53:ListHostedZonesByName", "route53:GetChange"],
     "Resource": "*"
   },
   {
     "Sid": "Firewall",
     "Effect": "Allow",
     "Action": [
       "wafv2:CreateWebACL",
       "wafv2:GetWebACL",
       "wafv2:UpdateWebACL",
       "wafv2:DeleteWebACL",
       "wafv2:ListTagsForResource",
       "wafv2:TagResource"
     ],
     "Resource": "*"
   }
   ```

   </details>

6. **Push to `main`.** The certificate validates through DNS, which can take a few minutes. Then open your own domain.

Route 53 charges for the hosted zone, and WAF has a monthly charge plus a per-request one. If you only want to look, do not uncomment anything.

---

## Cost

S3 storage and requests, plus CloudFront usage. GitHub Actions is free for public repositories.
For a small site this is close to nothing. Run `make destroy` when you no longer need it, and delete the
state bucket separately.

---

## Licence

MIT. See [LICENSE](LICENSE).
