# Cloud Launchpad: CI/CD with GitHub Actions (start)

Deploy the site automatically. When you push to `main`, GitHub Actions applies the Terraform,
uploads the site to S3 and clears the CloudFront cache, signing in to AWS with OIDC so there are
no access keys stored in GitHub. In this stage **you build the pipeline**. The finished version
is on the `7-cicd-end` branch if you get stuck.

## Architecture

![AWS architecture: a git push starts a GitHub Actions pipeline that gets temporary credentials from an IAM role through OIDC, runs Terraform, uploads the files to a private S3 bucket and invalidates the CloudFront cache](assets/images/architecture.svg)

The diagram shows the full platform. This stage builds the pipeline at the bottom and connects it
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
git checkout 6-cicd-start

make serve    # http://localhost:8080
```

## Starting point

`infra/` builds a private S3 bucket and a CloudFront distribution, as in the previous stage. One
thing changed: **Terraform no longer uploads the site files**. The pipeline does that, so the
bucket is empty until your workflow runs.

Deploy the infrastructure once from your laptop, so there is something to deploy to:

```bash
cp infra/terraform.tfvars.example infra/terraform.tfvars   # set your own bucket_name
make init
make deploy
```

## Your task

### Part 1: One-time setup in AWS and GitHub

CI cannot create its own login, so you set these up by hand.

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

6. **Repository variables:** in the GitHub repository settings, under *Secrets and variables*, *Actions*, *Variables*, add `AWS_ROLE_ARN` (the role's ARN), `AWS_REGION`, `TF_STATE_BUCKET` and `S3_BUCKET`.

### Part 2: Change the Terraform

7. **Backend:** add `infra/backend.tf` that stores the state in the state bucket, using S3's native locking (`use_lockfile = true`). Raise `required_version` in `versions.tf` to `1.10` or newer, and move your existing state with `terraform init -migrate-state`.

### Part 3: Write the workflow

8. Create `.github/workflows/deploy.yml` that
   - runs on pull requests to `main` and on pushes to `main`
   - has the permissions `id-token: write` and `contents: read`
   - signs in with `aws-actions/configure-aws-credentials`, using `AWS_ROLE_ARN`
   - runs `terraform fmt -check`, `validate` and `plan` on a pull request
   - runs `terraform apply -auto-approve` on a push to `main`
   - then syncs the site files to the bucket with `aws s3 sync`, leaving out the repository files
   - then creates a CloudFront invalidation for `/*`

   The bucket name comes from the `S3_BUCKET` variable, which CI also passes to Terraform as `TF_VAR_bucket_name`. The distribution ID comes from `terraform output -raw distribution_id`.

Push it to `main`, open the Actions tab and watch it run. Then open the `cloudfront_url`.

---

## Cost

S3 storage and requests, plus CloudFront usage. GitHub Actions is free for public repositories.
For a small site this is close to nothing. Run `make destroy` when you no longer need it, and delete the
state bucket separately.

---

## Licence

MIT. See [LICENSE](LICENSE).
