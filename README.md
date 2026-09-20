# Cloud Launchpad: S3 + CloudFront (start)

Put CloudFront in front of the site and make the S3 bucket private. In this stage **you extend
the Terraform** from the previous stage. The finished version is on the `5-cloudfront-end` branch
if you get stuck.

## Architecture

![AWS architecture: an engineer runs Terraform to create a private S3 bucket that is served through CloudFront using Origin Access Control](assets/images/architecture.svg)

The diagram shows the full platform. In this stage you build the part in the middle:

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
git checkout 4-cloudfront-start

make serve    # http://localhost:8080
```

## Starting point

`infra/` already has working Terraform for a **public** bucket with website hosting. Deploy it
first if you want to see the difference:

```bash
cp infra/terraform.tfvars.example infra/terraform.tfvars   # set your own bucket_name
make init
make deploy
```

## Your task

Change `infra/` so the bucket is private and CloudFront is the only way in:

1. **Make the bucket private:** set all four settings in `aws_s3_bucket_public_access_block` to `true`, and remove the website configuration. CloudFront reads the bucket through its normal endpoint, not the website endpoint.
2. **Origin Access Control:** add an `aws_cloudfront_origin_access_control` for S3, signing requests with `sigv4`.
3. **Distribution:** add an `aws_cloudfront_distribution` that
   - uses the bucket's regional domain name as its origin, with the access control attached
   - sets `index.html` as the default root object
   - redirects HTTP to HTTPS
   - uses one of the AWS managed cache policies
   - uses the default CloudFront certificate
   - shows `404.html` for missing files
4. **Bucket policy:** replace the public-read policy with one that lets the CloudFront service principal (`cloudfront.amazonaws.com`) run `s3:GetObject`, but only when the source ARN is your distribution.
5. **Output:** print the CloudFront URL, `https://<distribution domain name>`.

The Terraform documentation for the AWS provider has an example of each resource.

## Deploy

```bash
make init
make deploy
```

CloudFront takes a few minutes to create, so be patient. When it finishes, open the printed URL.
When you are done, `make destroy` deletes everything.

---

## Cost

S3 storage and requests, plus CloudFront usage. For a small site this is close to nothing, and
CloudFront has a free monthly allowance. Run `make destroy` when you no longer need it.

---

## Licence

MIT. See [LICENSE](LICENSE).
