# SlightBuild AWS Deployment Guide

This comprehensive guide covers deploying the SlightBuild website to AWS using Amplify with CI/CD, cost optimization, and best practices.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Cost Optimization](#cost-optimization)
- [CI/CD Pipeline](#cicd-pipeline)
- [Security Configuration](#security-configuration)
- [Monitoring & Alerts](#monitoring--alerts)
- [Troubleshooting](#troubleshooting)
- [Maintenance](#maintenance)

## 🚀 Prerequisites

### Required Tools
- **AWS CLI**: [Install AWS CLI](https://aws.amazon.com/cli/)
- **Terraform**: [Install Terraform](https://terraform.io/downloads) (v1.0+)
- **Git**: Version control
- **GitHub Account**: For repository hosting
- **AWS Account**: With appropriate permissions

### Required Permissions
Your AWS user/role needs the following permissions:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "amplify:*",
                "iam:*",
                "s3:*",
                "cloudfront:*",
                "route53:*",
                "certificatemanager:*",
                "budgets:*",
                "sns:*",
                "cloudwatch:*",
                "ce:*"
            ],
            "Resource": "*"
        }
    ]
}
```

## ⚡ Quick Start

### 1. Repository Setup
```bash
# Clone your repository
git clone https://github.com/yourusername/slightbuild-website.git
cd slightbuild-website

# Install development dependencies (optional)
npm install
```

### 2. AWS Configuration
```bash
# Configure AWS CLI
aws configure
# Enter your AWS Access Key ID, Secret, Region (us-east-1), and output format (json)

# Verify connection
aws sts get-caller-identity
```

### 3. GitHub Token Setup
1. Go to GitHub → Settings → Developer Settings → Personal Access Tokens
2. Generate token with `repo` scope
3. Save token securely (you'll need it for Terraform)

### 4. Infrastructure Deployment

#### Option A: AWS Amplify (Recommended)
```bash
# Navigate to Terraform directory
cd infrastructure/terraform

# Copy and configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Initialize and deploy
terraform init
terraform plan
terraform apply
```

#### Option B: Manual Amplify Setup
1. Go to [AWS Amplify Console](https://console.aws.amazon.com/amplify/)
2. Click "New app" → "Host web app"
3. Connect your GitHub repository
4. Configure build settings using the provided `amplify.yml`
5. Deploy

### 5. GitHub Actions Setup
Add these secrets to your GitHub repository (Settings → Secrets and variables → Actions):

```bash
# Required secrets
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AMPLIFY_APP_ID=your_amplify_app_id
PRODUCTION_DOMAIN=your_domain.com
```

Optional secrets for enhanced features:
```bash
SNYK_TOKEN=your_snyk_token
SENTRY_DSN=your_sentry_dsn
```

## 📋 Detailed Setup

### Environment Configuration

#### 1. Production Environment (.env.production)
Configure your production environment variables:
```bash
cp .env.example .env.production
# Edit with your actual values
```

Key configurations:
- **Analytics IDs**: Google Analytics, Facebook Pixel, Hotjar
- **Contact Form**: EmailJS configuration
- **Domain Settings**: Production and staging domains
- **Feature Flags**: Enable/disable features
- **Business Information**: Contact details

#### 2. Security Headers (customHttp.yml)
The `customHttp.yml` file configures security headers:
- **Content Security Policy**: Prevents XSS attacks
- **HSTS**: Forces HTTPS connections
- **Frame Options**: Prevents clickjacking
- **Cache Control**: Optimizes performance

### Terraform Infrastructure

#### Directory Structure
```
infrastructure/terraform/
├── main.tf              # Main infrastructure
├── variables.tf         # Input variables
├── outputs.tf          # Output values
├── monitoring.tf       # CloudWatch & cost monitoring
└── terraform.tfvars   # Your configuration
```

#### Key Resources Created
- **AWS Amplify App**: Main application
- **Amplify Branches**: Production (and optional staging)
- **Custom Domain**: SSL certificate and DNS
- **IAM Roles**: Service permissions
- **CloudWatch**: Monitoring and alerts
- **Cost Budgets**: Spending controls

### Custom Domain Setup

#### 1. Using Route 53 (Recommended)
```bash
# If you bought domain through Route 53, it's automatic
# Terraform will handle DNS validation
```

#### 2. Using External DNS Provider
1. Deploy infrastructure with `domain_name` in terraform.tfvars
2. Note the domain verification DNS record from Terraform output
3. Add the DNS record to your domain provider
4. Wait for verification (can take up to 24 hours)

## 💰 Cost Optimization

### Estimated Monthly Costs

| Service | Cost | Notes |
|---------|------|-------|
| AWS Amplify | $1-3 | Based on traffic and build minutes |
| Route 53 Hosted Zone | $0.50 | Only if using custom domain |
| SSL Certificate | $0 | Free with AWS Certificate Manager |
| CloudWatch | <$0.50 | Minimal monitoring |
| **Total** | **$1.50-4** | For typical small business site |

### Cost Controls
1. **Budget Alerts**: Set at $10/month by default
2. **Cost Anomaly Detection**: Automatic unusual spending alerts
3. **Resource Cleanup**: Automatic deletion of old build artifacts
4. **Optimized Caching**: Reduces bandwidth costs

### Free Tier Benefits
- **Amplify**: 1000 build minutes, 15GB storage/month
- **CloudFront**: 50GB data transfer out/month
- **Route 53**: First 25 hosted zones
- **Certificate Manager**: Unlimited SSL certificates

## 🔄 CI/CD Pipeline

### GitHub Actions Workflow

The `.github/workflows/deploy.yml` provides:

#### Automated Testing
- HTML validation
- Link checking
- File size monitoring
- Security scanning

#### Multi-Environment Deployment
- **Pull Requests**: Preview deployments
- **Main Branch**: Production deployment
- **Staging Branch**: Optional staging environment

#### Performance Monitoring
- Lighthouse CI audits
- Performance budgets
- Accessibility checks

### Workflow Triggers
- **Push to main**: Production deployment
- **Pull Request**: Preview deployment
- **Manual**: On-demand deployment

### Build Process
1. **Test Phase**: Validation and security checks
2. **Build Phase**: Asset optimization
3. **Deploy Phase**: Amplify deployment
4. **Verify Phase**: Health checks and performance audit

## 🔒 Security Configuration

### Security Headers
Configured in `customHttp.yml`:
- **CSP**: Content Security Policy prevents XSS
- **HSTS**: HTTP Strict Transport Security
- **X-Frame-Options**: Clickjacking protection
- **X-Content-Type-Options**: MIME sniffing protection

### Access Control
- **Private Repository**: Code protected on GitHub
- **IAM Roles**: Least privilege access
- **Secrets Management**: GitHub Secrets for sensitive data
- **Branch Protection**: Main branch requires PR approval

### SSL/TLS
- **Automatic SSL**: AWS Certificate Manager
- **HTTPS Redirect**: Force secure connections
- **Perfect Forward Secrecy**: Modern encryption

## 📊 Monitoring & Alerts

### CloudWatch Dashboard
Access at: AWS Console → CloudWatch → Dashboards

Monitors:
- **Request Volume**: Page views and API calls
- **Error Rates**: 4xx/5xx errors
- **Response Times**: Performance metrics
- **Build Status**: CI/CD pipeline health

### Cost Monitoring
- **Budget Alerts**: Email notifications at 80% and 100% of budget
- **Anomaly Detection**: Unusual spending patterns
- **Cost Explorer**: Detailed cost breakdown

### Performance Monitoring
- **Lighthouse CI**: Automated performance audits
- **Core Web Vitals**: User experience metrics
- **Uptime Monitoring**: Site availability

## 🔧 Troubleshooting

### Common Issues

#### 1. Domain Verification Fails
**Problem**: Custom domain shows "Pending verification"
**Solution**:
```bash
# Check DNS records
nslookup -type=CNAME _your_verification_record your_domain.com

# Force verification
aws amplify start-domain-association --app-id YOUR_APP_ID --domain-name your_domain.com
```

#### 2. Build Failures
**Problem**: Amplify build fails
**Solution**:
1. Check build logs in Amplify Console
2. Verify `amplify.yml` syntax
3. Check GitHub repository access
4. Review environment variables

#### 3. Performance Issues
**Problem**: Site loads slowly
**Solution**:
1. Enable performance mode in Amplify
2. Check image optimization
3. Verify CDN configuration
4. Review cache headers

#### 4. Security Warnings
**Problem**: Browser security warnings
**Solution**:
1. Check CSP configuration in `customHttp.yml`
2. Verify all resources use HTTPS
3. Update security headers
4. Test with security tools

### Debug Commands
```bash
# Check Amplify app status
aws amplify get-app --app-id YOUR_APP_ID

# View recent deployments
aws amplify list-jobs --app-id YOUR_APP_ID --branch-name main

# Test local development
npm run serve

# Validate HTML
npm run validate

# Run security checks
npm run security
```

## 🔄 Maintenance

### Regular Tasks

#### Weekly
- [ ] Review cost dashboard
- [ ] Check security alerts
- [ ] Monitor performance metrics

#### Monthly
- [ ] Update dependencies
- [ ] Review and rotate access keys
- [ ] Analyze traffic patterns
- [ ] Optimize based on metrics

#### Quarterly
- [ ] Security audit
- [ ] Performance optimization review
- [ ] Cost optimization analysis
- [ ] Backup verification

### Updates and Upgrades

#### Terraform Updates
```bash
cd infrastructure/terraform
terraform plan  # Review changes
terraform apply  # Apply updates
```

#### GitHub Actions Updates
- Monitor for security updates in workflow dependencies
- Update action versions in `.github/workflows/deploy.yml`

#### Amplify Updates
- AWS automatically updates Amplify platform
- Monitor AWS announcements for new features

## 📚 Additional Resources

### Documentation
- [AWS Amplify Documentation](https://docs.aws.amazon.com/amplify/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

### Tools and Utilities
- [AWS Cost Calculator](https://calculator.aws/)
- [Lighthouse CI](https://github.com/GoogleChrome/lighthouse-ci)
- [Security Headers Analyzer](https://securityheaders.com/)

### Community and Support
- [AWS Amplify Discord](https://discord.gg/amplify)
- [Terraform Community Forum](https://discuss.hashicorp.com/c/terraform-core/)
- [GitHub Community](https://github.com/community)

---

## 🎯 Next Steps

After successful deployment:

1. **Verify Everything Works**
   - Test all pages and functionality
   - Check mobile responsiveness  
   - Verify contact forms work

2. **Set Up Analytics**
   - Configure Google Analytics
   - Set up conversion tracking
   - Monitor user behavior

3. **SEO Optimization**
   - Submit sitemap to search engines
   - Set up Google Search Console
   - Optimize meta tags and content

4. **Marketing Integration**
   - Set up social media pixels
   - Configure email marketing
   - Add chat support if needed

5. **Ongoing Optimization**
   - A/B test key pages
   - Optimize conversion funnels
   - Monitor and improve performance

---

**Questions or Issues?**
- Check the troubleshooting section
- Review AWS Amplify logs
- Contact support with specific error messages

**Happy Deploying! 🚀**