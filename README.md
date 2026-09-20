# Cloud Launchpad: Stage 2, Terraform (start)

Host a static website on S3 by declaring the infrastructure in Terraform and running it from
your own machine. In this stage **you write the Terraform**. The finished version is on the
`2-terraform-end` branch if you get stuck.

## Architecture

![AWS architecture: an engineer runs Terraform to create a public S3 bucket and upload the static files, and visitors load the site from the S3 website endpoint or a custom domain through Route 53](assets/images/architecture.svg)

Terraform, run from your machine, creates the public S3 bucket and uploads the static files.
Visitors load the site from the bucket's website endpoint, or from a custom domain through Route 53.

---

## Prerequisites

- An AWS account, with the AWS CLI configured (`aws configure`) so Terraform can use your credentials
- [Terraform](https://developer.hashicorp.com/terraform/install) 1.5 or newer

## Run the site locally

```bash
git clone git@github.com:gcodiac/aws-s3-static-site-cicd.git
cd aws-s3-static-site-cicd
git checkout 2-terraform-start

python3 -m http.server 8080    # http://localhost:8080
```

You can also use the VS Code Live Server extension.

## Your task

The site is ready, but there is no `infra/` folder and no Makefile yet. Create
`infra/main.tf` so that Terraform builds everything the diagram shows:

1. **Provider:** the `hashicorp/aws` provider, with the region as a variable.
2. **Bucket name:** a required `bucket_name` variable, since bucket names are globally unique.
3. **Bucket:** an `aws_s3_bucket`.
4. **Public access:** an `aws_s3_bucket_public_access_block` with all four settings set to `false`, because new buckets block public access by default.
5. **Website hosting:** an `aws_s3_bucket_website_configuration` with `index.html` as the index document and `404.html` as the error document.
6. **Public read:** an `aws_s3_bucket_policy` that allows `s3:GetObject` for everyone.
7. **Files:** one `aws_s3_object` for each site file, using `for_each` and `fileset`. Set the content type so the browser renders the files instead of downloading them.
8. **Output:** the website URL.

The Terraform documentation for the AWS provider has an example of each resource.

## Deploy

```bash
cd infra
terraform init                                   # download the AWS provider
terraform apply -var bucket_name=my-bucket-name  # shows the plan, then asks for approval
terraform destroy -var bucket_name=my-bucket-name  # delete everything when you are done
```

`terraform apply` prints the website URL when it finishes. Edit the site and run it again, and
Terraform uploads only the files that changed.

---

## Cost

S3 storage and requests only, which is pennies for a small site. Run `terraform destroy` when
you no longer need the bucket.

---

## Licence

MIT. See [LICENSE](LICENSE).
