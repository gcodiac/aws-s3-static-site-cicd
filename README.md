# Cloud Launchpad: Stage 2, Terraform (end)

Host a static website on S3 with Terraform, run from your own machine. This is the finished
version of stage 2. To build it yourself, start from the `2-terraform-start` branch.

## Architecture

![AWS architecture: an engineer runs Terraform to create a public S3 bucket and upload the static files, and visitors load the site from the S3 website endpoint or a custom domain through Route 53](assets/images/architecture.svg)

Terraform, run from your machine, creates the public S3 bucket and uploads the static files.
Visitors load the site from the bucket's website endpoint, or from a custom domain through Route 53.

---

## Prerequisites

- An AWS account, with the AWS CLI configured (`aws configure`) so Terraform can use your credentials
- [Terraform](https://developer.hashicorp.com/terraform/install) 1.5 or newer
- `make`, which is optional. The Makefile only wraps the Terraform commands.

## Run the site locally

```bash
git clone git@github.com:gcodiac/aws-s3-static-site-cicd.git
cd aws-s3-static-site-cicd
git checkout 2-terraform-end

make serve    # http://localhost:8080
```

## Deploy

```bash
make init                           # download the AWS provider
make deploy BUCKET=my-bucket-name   # terraform apply: shows the plan, then asks for approval
make destroy BUCKET=my-bucket-name  # delete everything when you are done
```

Bucket names are globally unique, so pick your own. `make deploy` prints the website URL when it
finishes. Edit the site and run it again, and Terraform uploads only the files that changed.

Without `make`, run the same commands directly:

```bash
cd infra
terraform init
terraform apply -var bucket_name=my-bucket-name
```

## What the Terraform creates

All of it is in the [infra/](infra/) folder. You do not need an existing bucket.

| Resource | Purpose |
| --- | --- |
| `aws_s3_bucket` | The bucket itself |
| `aws_s3_bucket_public_access_block` | Turns off the default block on public access |
| `aws_s3_bucket_website_configuration` | Serves `index.html`, and `404.html` for missing files |
| `aws_s3_bucket_policy` | Lets anyone read the objects |
| `aws_s3_object` | One per site file, with the right content type |

State is kept locally in `infra/terraform.tfstate`, which is not committed.

The S3 website endpoint serves HTTP only, and the bucket is public by design. That is fine for
learning. The next stage shows how to do it properly.

---

## Cost

S3 storage and requests only, which is pennies for a small site. Run `make destroy` when you
no longer need the bucket.

---

## Licence

MIT. See [LICENSE](LICENSE).
