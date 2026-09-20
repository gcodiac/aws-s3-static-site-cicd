# Cloud Launchpad: S3 + CloudFront (end)

Serve the site through CloudFront and keep the S3 bucket private. This is the finished
version. To build it yourself, start from the `4-cloudfront-start` branch.

## Architecture

![AWS architecture: an engineer runs Terraform to create a private S3 bucket that is served through CloudFront using Origin Access Control](assets/images/architecture.svg)

The diagram shows the full platform. This stage builds the part in the middle:

- a **private S3 bucket**, with all public access blocked
- a **CloudFront distribution** that serves the site over HTTPS
- **Origin Access Control (OAC)** and a **bucket policy**, so only that distribution can read the bucket

Route 53, WAF and Certificate Manager come in later stages. Visitors use the
`*.cloudfront.net` address, which already has HTTPS.

---

## Prerequisites

- An AWS account, with the AWS CLI configured (`aws configure`) so Terraform can use your credentials
- [Terraform](https://developer.hashicorp.com/terraform/install) 1.5 or newer
- `make`, which is optional. The Makefile only wraps the Terraform commands.

## Run the site locally

```bash
git clone git@github.com:gcodiac/aws-s3-static-site-cicd.git
cd aws-s3-static-site-cicd
git checkout 5-cloudfront-end

make serve    # http://localhost:8080
```

## Deploy

Bucket names are unique across all of AWS, so choose your own.

```bash
cp infra/terraform.tfvars.example infra/terraform.tfvars   # set your own bucket_name
make init
make deploy     # terraform apply: shows the plan, then asks for approval
```

Or pass the name each time: `make deploy BUCKET=my-bucket-name`.

CloudFront takes a few minutes to create. When it finishes, `make deploy` prints
the `cloudfront_url`. Open it.

Without `make`, run the same commands directly:

```bash
cd infra
terraform init
terraform apply
```

### Changing the site

Edit a file and run `make deploy` again. Terraform uploads only the files that changed. CloudFront
caches files for up to a day, so clear its cache to see the change straight away:

```bash
make invalidate
```

### Clean up

```bash
make destroy    # add BUCKET=... if you used it with make deploy
```

## What the Terraform creates

All of it is in the [infra/](infra/) folder. You do not need an existing bucket.

| Resource | Purpose |
| --- | --- |
| `aws_s3_bucket` | The bucket, kept private |
| `aws_s3_bucket_public_access_block` | Blocks all public access |
| `aws_cloudfront_origin_access_control` | Lets CloudFront sign its requests to S3 |
| `aws_cloudfront_distribution` | Serves the site over HTTPS and shows `404.html` for missing files |
| `aws_s3_bucket_policy` | Lets only this distribution read the bucket |
| `aws_s3_object` | One per site file, with the right content type |

Visitors use the `*.cloudfront.net` address, which has HTTPS from the default CloudFront
certificate. Opening the bucket's own S3 address returns Access Denied, which is the point.

State is kept locally in `infra/terraform.tfstate`, which is not committed.

---

## Cost

S3 storage and requests, plus CloudFront usage. For a small site this is close to nothing, and
CloudFront has a free monthly allowance. Run `make destroy` when you no longer need it.

---

## Licence

MIT. See [LICENSE](LICENSE).
