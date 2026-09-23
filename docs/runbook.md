# Runbook

Operational procedures for this stage. Written to be followed at speed by somebody who
did not build it.

Throughout, `<site-bucket>` is the value of the `S3_BUCKET` repository variable and
`<state-bucket>` is `TF_STATE_BUCKET`.

---

## First deployment

### 1. Bootstrap by hand, once

The pipeline cannot create its own login or its own state store, so these three come
first. Full click-by-click steps are in the README under **Setup**:

1. A second S3 bucket for the Terraform state, with versioning on.
2. The GitHub OIDC identity provider in IAM (one per AWS account — skip it if it is
   already there).
3. An IAM role, `cloud-launchpad-github-actions`, with the trust policy and the
   inline permissions policy from the README.

Then add four repository variables under *Settings → Secrets and variables → Actions →
Variables*: `AWS_ROLE_ARN`, `AWS_REGION`, `TF_STATE_BUCKET`, `S3_BUCKET`.

Variables, not secrets. None of them is confidential, and marking non-secrets as
secrets only makes the logs unreadable.

### 2. Move existing state, if you have any

Deployed from your laptop in the previous stage? Move that state into the bucket
rather than starting again:

```bash
cd infra
terraform init -migrate-state \
  -backend-config="bucket=<state-bucket>" \
  -backend-config="region=<region>"
```

Starting fresh, skip this. The first run creates everything.

### 3. Deploy

Push to `main` and watch the **Actions** tab, or start it by hand from the Actions tab
with **Deploy site and infrastructure**.

```bash
gh workflow run deploy.yml -f action="Deploy site and infrastructure"
gh run watch
```

The CloudFront distribution takes a few minutes the first time. When the run finishes,
the site address is on the run summary, and in the apply log as `cloudfront_url`.

---

## Everyday deploys

| You want to | Do this |
| --- | --- |
| Ship a site change | Push to `main`. The pipeline applies, syncs and invalidates |
| Review an infrastructure change first | Open a pull request. The run prints the plan and changes nothing |
| Preview a branch on the real site | Actions → Deploy → **Run workflow**, pick the branch, **Deploy site only** |
| Apply a branch's infrastructure | Same, but **Deploy site and infrastructure** |
| Take everything down | Same, but **Destroy everything**, and type the bucket name to confirm |

A manual site deploy makes the live site whatever branch you picked. The next push to
`main` puts `main` back.

Two things that catch people out: the workflow file must exist on the default branch
for the **Run workflow** button to appear at all, and a manual run uses the workflow
file from the branch you select, not from `main`.

---

## Deploy from a laptop

Useful when the pipeline itself is broken. Same state, same lock — so it is safe, but
do not do it while a run is in flight.

```bash
aws sts get-caller-identity     # confirm the account first

cd infra
terraform init \
  -backend-config="bucket=<state-bucket>" \
  -backend-config="region=<region>"
terraform plan                  # read this
terraform apply
```

Then upload the site and clear the cache from the repository root:

```bash
aws s3 sync . "s3://<site-bucket>" --delete \
  --exclude ".git/*" --exclude ".github/*" --exclude ".gitignore" \
  --exclude "infra/*" --exclude "docs/*" --exclude "Makefile" \
  --exclude "README.md" --exclude "LICENSE"

make invalidate
```

`make init`, `make deploy`, `make invalidate` and `make destroy` are the short forms —
but note that `make init` passes no `-backend-config`, so run the full `terraform init`
above the first time in a fresh clone.

---

## Roll back a bad deployment

Fastest first.

### Re-run the last good deployment

```bash
gh run list --workflow=deploy.yml --limit 10
gh run rerun <run-id>
```

A re-run checks out that run's commit again, so the bucket ends up matching a known
commit. Use this when the bad change is in the site content.

### Revert and push

The pipeline is the rollback mechanism, and this is almost always the right answer,
because the bucket ends up matching `main`.

```bash
git revert <bad-commit>
git push origin main
```

### Restore a single file

There is no object versioning on the site bucket, so a previous copy of a file does
not exist in S3 — the only source of truth is git. To put one file back in a hurry:

```bash
git show <good-commit>:index.html > index.html
aws s3 cp index.html "s3://<site-bucket>/index.html"
make invalidate
```

The bucket now no longer matches `main`. Follow up with a real deployment.

### Roll back infrastructure

```bash
cd infra
git revert <bad-commit>
terraform plan     # confirm it removes what you expect
terraform apply
```

Or revert on `main` and let the pipeline apply it.

---

## Common failures

| Symptom | Cause | Fix |
| --- | --- | --- |
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | The OIDC `sub` claim does not match the trust policy — usually the immutable claim form (`repo:owner@1234/name@5678:…`) against a policy that lists only the classic form, or a branch outside `refs/heads/*` | Look up the failed `AssumeRoleWithWebIdentity` event in CloudTrail to see the exact `sub` GitHub sent, then add that form to the trust policy |
| `AccessDenied` on an S3 or CloudFront call | The role's inline policy is missing that action | The error names the action. Add exactly that one — not `s3:*` on `*` |
| `Error acquiring the state lock` | Another run holds the lock, or a run was cancelled mid-apply | Wait for the other run. If nothing is running, delete the `.tflock` object under `cloud-launchpad/` in the state bucket |
| `terraform fmt -check` fails the run before anything else | Formatting | `terraform fmt` in `infra/`, then commit |
| Site returns 403 for every path | Bucket policy missing, or `AWS:SourceArn` does not match the distribution | `terraform apply`; check `aws_s3_bucket_policy.cloudfront_read` |
| Changes not visible after a deploy | Edge cache still holding the old object | Give the invalidation a minute; confirm with `curl -sI <url> \| grep -i x-cache` |
| A missing page returns 403 rather than the 404 page | `custom_error_response` not applied | Check both blocks on the distribution in [infra/cloudfront.tf](../infra/cloudfront.tf) |
| `BucketAlreadyExists` on the first apply | Bucket names are globally unique across all of AWS | Choose another `bucket_name`, and update the `S3_BUCKET` variable and the role policy to match |
| `Run workflow` button is missing | The workflow file is not on the default branch | Merge it to `main` first |
| Custom domain shows a certificate error | Certificate not in `us-east-1`, or not `ISSUED` yet | Certificates for CloudFront must be requested in `us-east-1`; DNS validation takes a few minutes |
| `terraform destroy` fails on the bucket | The bucket still contains the uploaded site, which Terraform does not know about | Empty it first: `aws s3 rm "s3://<site-bucket>" --recursive`. The pipeline's destroy does this for you |

Useful one-liners while debugging:

```bash
# What is the edge actually serving?
curl -sI https://<distribution>.cloudfront.net/ | grep -iE 'x-cache|age|etag'

# Is the bucket genuinely private? This must return 403.
curl -s -o /dev/null -w '%{http_code}\n' \
  "https://<site-bucket>.s3.<region>.amazonaws.com/index.html"

# What does Terraform think exists?
cd infra && terraform output && terraform state list
```

---

## Check for drift

Drift is the gap between what Terraform believes and what AWS actually has — usually
created by somebody making a change in the console.

```bash
cd infra
terraform plan     # an empty plan means no drift
```

Opening a pull request does the same thing in CI, and prints the plan in the log.

An unexpected diff means either the console was used, or someone changed the
configuration without applying it. Both are worth understanding before you apply.

---

## Tear it down

### From the pipeline

Actions → **Deploy** → **Run workflow** → **Destroy everything**, and type the site
bucket name into the confirmation box. The run empties the bucket, then runs
`terraform destroy`. It waits a few minutes for CloudFront to finish deleting.

```bash
gh workflow run deploy.yml \
  -f action="Destroy everything" \
  -f confirm_bucket="<site-bucket>"
```

### From a laptop

```bash
aws s3 rm "s3://<site-bucket>" --recursive
cd infra && terraform destroy
```

### What is left behind

The destroy removes the site bucket, the distribution and the access control. It
deliberately does not touch the three bootstrap resources, because the pipeline needs
them to run at all. When you are completely finished:

```bash
aws s3 rm "s3://<state-bucket>" --recursive   # current versions only
aws s3api delete-bucket --bucket "<state-bucket>"
aws iam delete-role-policy --role-name cloud-launchpad-github-actions \
  --policy-name cloud-launchpad-deploy
aws iam delete-role --role-name cloud-launchpad-github-actions
```

A versioned bucket is not empty until its old versions are gone too, so if the delete
fails, remove the versions in the console (or with `list-object-versions` and
`delete-objects`) and try again.

Leave the OIDC identity provider alone unless you are sure nothing else in the account
uses it — it is shared account-wide.

Finally, confirm nothing is still running:

```bash
aws s3 ls
aws cloudfront list-distributions --query 'DistributionList.Items[].DomainName'
```

To bring the site back later, run **Deploy site and infrastructure**. **Deploy site
only** would fail, because the bucket no longer exists.
