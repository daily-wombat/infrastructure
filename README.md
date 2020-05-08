# Introduction
This project contains all of the infrastructure for the `dailywombat.com` website.  This includes the following...

* The S3 bucket that contains the static content for the site.
* The CloudFront distribution that sits in front of the S3 bucket.
* The SSL certificate that gets added to the CloudFront distribution.  This will be validated with DNS.
* The Route53 hosted zone for the site.

# Remote State
State and variable management is handled by Terraform Cloud in the [dailywombat](https://app.terraform.io/app/dailywombat/workspaces) organization.  Environment management (dev, prod, etc) is a little wonky with Terraform Cloud.  Each environment (e.g. `prod`) will be represented by one local workspace named `prod` and two remote workspaces with `prod` combined with the particular infrastructure folder (e.g. `site-prod`).  Currently, the only environment is `prod`, so that means the Terraform Cloud organization currently has `hostedzone-prod` and `site-prod`.  If I added a `dev` environment, I would also have `hostedzone-dev` and `site-dev`.   Unfortunately, that means I have to repeat many of the same variables in all of them.  I'm not really sure of a better way to manage this.  Local `tfvars` files will force me to complicate my `terraform` commands, and some of these variables contain secrets.

Currently, each remote environment carries the following variables...

* `aws_access_key_id` for the `jlarge` IAM user.
* `aws_secret_access_key` for the `jlarge` IAM user.
* `environment` - My original attempt was to avoid having this variable and instead refer `var.workspace` in the config, but that always brings back the value `default` for some reason.  I found an [issue](https://github.com/hashicorp/terraform/issues/22802) out there that gets into that confusion, but it appears to remain unresolved.

# The hostedzone folder
This folder contains the DNS hosted zone for `dailywombat.com`.  It should be stood up before applying the `site` folder.  **Important:**  When applying, do not run `terraform apply` on its own.  Instead, run `./tfapply` which will also run an AWS CLI command to sync the name servers between the newly created hosted zone and the domain registration.  This is admittedly pretty awkward, which is why I separated this part into its own folder.  While it should be fine to tear down and repave the rest of the infrastructure in this project, the hosted zone should probably be left alone once it's been created, especially since it costs $0.50 every time you create a new one.  For more details about these name server sync issues, I've provided more details further down in this writeup.

# The site folder
This folder contains the rest of the infrastructure.  You should be able to repave this as many times as you want, but whenever you do, you'll also need to push the static content up again by pulling down the [main-ui](https://github.com/daily-wombat/main-ui) project and running `npm run deploy`.

# Building from scratch
This section will provide you with instructions to completely build the Daily Wombat infrastructure.  The following assumptions are made...

* None of the infrastructure is currently stood up.
* You are starting with a freshly cloned copy of this repo and the [main-ui](https://github.com/daily-wombat/main-ui) repo.

To build everything, do the following...
1. Navigate to the `hostedzone` folder.
2. Run `terraform init`.  You'll be prompted to choose a workspace.  The only option right now is `prod`, so choose that.
3. Run `./tfapply` and say `yes` when it prompts for confirmation.  It's important that you don't run `terraform apply` on its own.  The `tfapply` script does some name server syncing that is explained further down in this writeup.
4. Navigate to the `site` folder.
5. Run `terraform init`.  You'll be prompted to choose a workspace.  The only option right now is `prod`, so choose that.
6. Run `terraform apply` and say `yes` when it prompts for confirmation.  The creation of the CloudFront distribution takes a while.  The last time I ran this apply, it took around 10 minutes.
7. Navigate to the `main-ui` folder.
8. Run `npm run deploy`.  This will do a build and then push the contents up to your newly created S3 bucket.
9. Wait about an hour for your DNS and certificate to be fully propagated.  The wait time varies, and I don't know enough to say why.
10. Visit `dailywombat.com` on your browser.  It should open up with a generic ReactJS page.

# Problems with name servers
By far, my biggest hurdle in getting all of this to work is that every time the DNS hosted zone is recreated, four new name servers are randomly assigned to it, and these will not be the same servers that are in the domain registration.  It took me a day of troubleshooting before I realized this, mainly because I'm not experienced in troubleshooting DNS issues (I'm still pretty bad at it).  Once I saw this as the issue, I tried the following things...

### Attempt 1:  Go into the AWS console and manually update the name servers
This solved my problem right away, but I didn't want to stay with a manual solution very long.

### Attempt 2:  See if there is a Terraform resource for the domain registration
I did see a somewhat popular [issue](https://github.com/hashicorp/terraform/issues/5368) where somebody asked for a resource called `aws_route53_domain`, but from the looks of it, it kind of died on the vine.

### Attempt 3:  Add a local-exec provisioner with a script that syncs the name servers
I think I could get this to work if I was doing local Terraform, but I ran into problems with Terraform Cloud because its worker servers don't have much software on them.  In particular, they don't have the AWS CLI.  I went down this road for a while but ultimately gave up on it.

### Attempt 4:  Create a separate script that runs terraform apply and then syncs up the name servers
This is what I went with.  It works, and it's better than dealing with things manually, but it's not my favorite thing in the world.  First of all, it takes that name server syncing out of Terraform, so technically you could argue that it's a form of configuration drift.  Second, it's real easy for somebody to forget about this script and simply run `terraform apply`.  I mitigate this somewhat by placing this stuff in its own folder and advising that we don't touch it once it's created.
