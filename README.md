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
2. **OIDC provider:** in IAM, add an identity provider for `token.actions.githubusercontent.com`, with the audience `sts.amazonaws.com`.
3. **IAM role:** create a role for that provider. Its trust policy should only allow your repository (`repo:<owner>/<repo>:*`). For learning, give it `AdministratorAccess`. A real project would scope the permissions down.
4. **Repository variables:** in the GitHub repository settings, under *Secrets and variables*, *Actions*, *Variables*, add `AWS_ROLE_ARN`, `AWS_REGION`, `TF_STATE_BUCKET` and `BUCKET_NAME`.

### Part 2: Change the Terraform

5. **Backend:** add `infra/backend.tf` that stores the state in the state bucket, using S3's native locking (`use_lockfile = true`). Raise `required_version` in `versions.tf` to `1.10` or newer, and move your existing state with `terraform init -migrate-state`.

### Part 3: Write the workflow

6. Create `.github/workflows/deploy.yml` that
   - runs on pull requests to `main` and on pushes to `main`
   - has the permissions `id-token: write` and `contents: read`
   - signs in with `aws-actions/configure-aws-credentials`, using `AWS_ROLE_ARN`
   - runs `terraform fmt -check`, `validate` and `plan` on a pull request
   - runs `terraform apply -auto-approve` on a push to `main`
   - then syncs the site files to the bucket with `aws s3 sync`, leaving out the repository files
   - then creates a CloudFront invalidation for `/*`

   The bucket name comes from the `BUCKET_NAME` variable, which CI also passes to Terraform as `TF_VAR_bucket_name`. The distribution ID comes from `terraform output -raw distribution_id`.

Push it to `main`, open the Actions tab and watch it run. Then open the `cloudfront_url`.

---

## Cost

S3 storage and requests, plus CloudFront usage. GitHub Actions is free for public repositories.
For a small site this is close to nothing. Run `make destroy` when you no longer need it, and delete the
state bucket separately.

---

## Licence

MIT. See [LICENSE](LICENSE).
