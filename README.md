# Cloud Launchpad: deploy directly to S3

The simplest way to host a static website on AWS: a public S3 bucket with static website
hosting turned on, and one `aws s3 sync` to upload the files. No Terraform, no pipeline.

## Architecture

![AWS architecture: an engineer uploads static files directly to a public S3 bucket, and visitors load the site from the S3 website endpoint or a custom domain through Route 53](assets/images/architecture.svg)

The engineer uploads the files straight to the bucket with the AWS CLI. Visitors load the
site from the bucket's website endpoint, or from a custom domain through Route 53.

---

## Prerequisites

- An AWS account and the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), configured with `aws configure`
- An S3 bucket that is public and has static website hosting turned on (setup below)
- `make`, which is optional. You can run the `aws s3 sync` command directly.

## Run locally

```bash
git clone git@github.com:gcodiac/aws-s3-static-site-cicd.git
cd aws-s3-static-site-cicd
git checkout 1-aws-cli-deploy

make serve    # http://localhost:8080
```

## Deploy

```bash
make deploy BUCKET=my-bucket-name
```

This runs `aws s3 sync`, which uploads new and changed files and, with `--delete`, removes
files from the bucket that no longer exist locally. The site is then live at:

```
http://<bucket>.s3-website-<region>.amazonaws.com
```

## Create the bucket (one time)

Choose the console or the CLI. Replace the bucket name and region with your own.

### Option A: AWS Console

1. Sign in to the [AWS Console](https://console.aws.amazon.com/) and pick your region (top right), for example **Europe (Ireland) eu-west-1**.
2. Search for **S3** in the search bar and open it.
3. Click **Create bucket**.
4. **Bucket name:** enter a globally unique name, for example `my-bucket-name`. Leave **Bucket type** as *General purpose*.
5. **Object Ownership:** leave *ACLs disabled (recommended)*.
6. **Block Public Access settings for this bucket:** untick **Block *all* public access**, then tick the warning box **I acknowledge that the current settings might result in this bucket and the objects within becoming public**.
7. Leave everything else as the default and click **Create bucket**.
8. Open your new bucket and go to the **Properties** tab.
9. Scroll to the bottom to **Static website hosting** and click **Edit**.
10. Select **Enable**, set **Hosting type** to *Host a static website*, and enter `index.html` as the **Index document** and `404.html` as the **Error document**. Click **Save changes**.
11. Go to the **Permissions** tab, find **Bucket policy** and click **Edit**.
12. Paste this policy, replace `my-bucket-name` with your bucket name, and click **Save changes**:

    ```json
    {
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Principal": "*",
        "Action": "s3:GetObject",
        "Resource": "arn:aws:s3:::my-bucket-name/*"
      }]
    }
    ```

13. Go back to **Properties**, scroll to **Static website hosting** and copy the **Bucket website endpoint**. This is your site's URL.
14. From this repository, run `make deploy BUCKET=my-bucket-name` and open the URL.

### Option B: AWS CLI

```bash
BUCKET=my-bucket-name
REGION=eu-west-1

aws s3api create-bucket --bucket $BUCKET --region $REGION \
  --create-bucket-configuration LocationConstraint=$REGION

# Allow public policies, which are blocked by default
aws s3api put-public-access-block --bucket $BUCKET --public-access-block-configuration \
  BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false

# Turn on static website hosting
aws s3 website s3://$BUCKET/ --index-document index.html --error-document 404.html

# Let anyone read the objects
aws s3api put-bucket-policy --bucket $BUCKET --policy '{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::'$BUCKET'/*"
  }]
}'
```

The S3 website endpoint serves HTTP only, and the bucket is public by design. That is fine for
learning. The course shows how to do it properly.

---

## Course

**[Open the Platform Engineering Course →](https://s3.aliskool.com/)**

---

## Cost

S3 storage and requests only. For a small static site that is pennies, but delete the
bucket when you no longer need it:

```bash
aws s3 rb s3://my-bucket-name --force
```

---

## Licence

MIT. See [LICENSE](LICENSE).
