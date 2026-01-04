# 🚀 GitHub Pages Deployment Guide

## 🎯 Overview

Deploy your Flutter PWA to GitHub Pages automatically using GitHub Actions. Every time you push to the `main` branch, your app will automatically build and deploy!

---

## ✨ Benefits of GitHub Pages Deployment

- ✅ **100% Free** - No hosting costs
- ✅ **Automatic Deployment** - Push to deploy
- ✅ **HTTPS Included** - Secure by default
- ✅ **Global CDN** - Fast worldwide
- ✅ **No Server Setup** - GitHub handles everything
- ✅ **Version Control** - Built-in rollback
- ✅ **Custom Domain Support** - Optional

---

## 📋 Prerequisites

- ✅ GitHub account
- ✅ Repository pushed to GitHub
- ✅ Flutter project configured for web

---

## 🚀 Deployment Steps

### Step 1: Enable GitHub Pages

1. Go to your repository on GitHub:
   ```
   https://github.com/mashkurulalamohi37/-baust-project-showcase
   ```

2. Click **Settings** (top menu)

3. Scroll down to **Pages** (left sidebar)

4. Under **Source**, select:
   - Source: **GitHub Actions**

5. Click **Save**

### Step 2: Push the Workflow File

The workflow file has already been created at:
`.github/workflows/deploy.yml`

Just commit and push:

```powershell
git add .
git commit -m "Add GitHub Actions workflow for automatic deployment"
git push origin main
```

### Step 3: Wait for Deployment

1. Go to the **Actions** tab in your repository
2. You'll see the workflow running
3. Wait for it to complete (usually 2-5 minutes)
4. Once complete, your app is live!

---

## 🌐 Your App URLs

### GitHub Pages URL:
```
https://mashkurulalamohi37.github.io/-baust-project-showcase/
```

### Repository URL:
```
https://github.com/mashkurulalamohi37/-baust-project-showcase
```

---

## 🎨 How It Works

### Automatic Workflow:

```
1. You push code to main branch
   ↓
2. GitHub Actions triggers
   ↓
3. Flutter environment sets up
   ↓
4. Dependencies install
   ↓
5. Web app builds
   ↓
6. Deploys to GitHub Pages
   ↓
7. Your app is live!
```

### What Happens on Each Push:

- ✅ Automatic build
- ✅ Automatic deployment
- ✅ No manual steps needed
- ✅ Build logs available
- ✅ Rollback if needed

---

## 📱 Testing Your Deployment

### On Desktop:
1. Open: `https://mashkurulalamohi37.github.io/-baust-project-showcase/`
2. Check: All features work
3. Test: Offline mode (disconnect internet)
4. Verify: Service worker registers

### On iPhone (Safari):
1. Open Safari
2. Navigate to your GitHub Pages URL
3. Wait for install banner (3 seconds)
4. Tap Share → Add to Home Screen
5. Test standalone mode

### On Android (Chrome):
1. Open Chrome
2. Navigate to your GitHub Pages URL
3. Install prompt should appear
4. Add to Home Screen
5. Test standalone mode

---

## 🔧 Customization

### Change Flutter Version

Edit `.github/workflows/deploy.yml`:

```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.24.0'  # Change this
    channel: 'stable'
```

### Add Build Optimizations

Edit `.github/workflows/deploy.yml`:

```yaml
- name: Build web
  run: |
    flutter build web --release \
      --base-href "/-baust-project-showcase/" \
      --dart-define=FLUTTER_WEB_USE_SKIA=true
```

### Deploy Only on Tags

Edit `.github/workflows/deploy.yml`:

```yaml
on:
  push:
    tags:
      - 'v*'
```

---

## 🎯 Custom Domain (Optional)

### Add Your Own Domain:

1. **Buy a domain** (e.g., from Namecheap, GoDaddy)

2. **Add CNAME file** to your project:
   ```powershell
   echo "yourdomain.com" > web/CNAME
   ```

3. **Update DNS records** at your domain provider:
   ```
   Type: CNAME
   Name: www
   Value: mashkurulalamohi37.github.io
   ```

4. **Configure in GitHub:**
   - Go to Settings → Pages
   - Enter your custom domain
   - Wait for DNS check
   - Enable HTTPS

5. **Update base-href** in workflow:
   ```yaml
   flutter build web --release --base-href "/"
   ```

---

## 📊 Monitoring Deployments

### View Build Status:

1. Go to **Actions** tab
2. Click on latest workflow run
3. View build logs
4. Check for errors

### Build Badge (Optional):

Add to your README.md:

```markdown
![Deploy Status](https://github.com/mashkurulalamohi37/-baust-project-showcase/workflows/Deploy%20Flutter%20Web%20to%20GitHub%20Pages/badge.svg)
```

---

## 🔄 Update Workflow

### When You Make Changes:

```powershell
# 1. Make your code changes

# 2. Commit and push
git add .
git commit -m "Your changes"
git push origin main

# 3. Automatic deployment starts!
# Check Actions tab for progress
```

**No manual build or deploy needed!**

---

## 🐛 Troubleshooting

### Build Fails?

**Check the Actions log:**
1. Go to Actions tab
2. Click failed workflow
3. Read error messages

**Common fixes:**
```powershell
# Fix pubspec.yaml errors
flutter pub get

# Test build locally first
flutter build web --release

# If local build works, push again
git push origin main
```

### Page Not Loading?

**Wait a few minutes:**
- GitHub Pages can take 5-10 minutes to propagate
- Check Actions tab for completion

**Clear cache:**
- Hard refresh: Ctrl+Shift+R (Windows) or Cmd+Shift+R (Mac)
- Try incognito mode

**Check base-href:**
- Should be: `--base-href "/-baust-project-showcase/"`
- Must match repository name

### 404 Error?

**Verify GitHub Pages is enabled:**
1. Settings → Pages
2. Source should be "GitHub Actions"

**Check repository name:**
- URL must match: `https://username.github.io/repo-name/`
- Base-href must match repo name

---

## 🎨 Workflow Features

### Current Configuration:

- ✅ **Auto-deploy on push** to main branch
- ✅ **Manual trigger** available (workflow_dispatch)
- ✅ **Flutter caching** for faster builds
- ✅ **Artifact upload** for debugging
- ✅ **Concurrent deployment** prevention

### Workflow Triggers:

```yaml
# Automatic on push to main
on:
  push:
    branches:
      - main
  
  # Manual trigger from Actions tab
  workflow_dispatch:
```

---

## 📈 Performance

### Build Time:
- **First build:** 3-5 minutes
- **Cached builds:** 1-2 minutes

### Deployment Time:
- **Total:** 2-5 minutes from push to live

### Limits:
- **Storage:** 1 GB
- **Bandwidth:** 100 GB/month
- **Build time:** 2000 minutes/month (free tier)

---

## 🔐 Security

### Automatic HTTPS:
- ✅ GitHub provides free SSL
- ✅ Automatic certificate renewal
- ✅ HTTPS enforced

### Permissions:
- ✅ Read-only content access
- ✅ Write access for deployment
- ✅ ID token for authentication

---

## 🎯 Comparison: GitHub Pages vs Firebase

| Feature | GitHub Pages | Firebase Hosting |
|---------|--------------|------------------|
| **Cost** | ✅ Free | ✅ Free (with limits) |
| **Setup** | ✅ Easier | ⚠️ Requires Firebase CLI |
| **Deployment** | ✅ Automatic (Git push) | ⚠️ Manual command |
| **Custom Domain** | ✅ Yes | ✅ Yes |
| **HTTPS** | ✅ Automatic | ✅ Automatic |
| **CDN** | ✅ Yes | ✅ Yes (faster) |
| **Analytics** | ❌ No (use Google Analytics) | ✅ Built-in |
| **Build Time** | ⚠️ 2-5 min | ⚡ Instant (pre-built) |
| **Rollback** | ✅ Git revert | ✅ Console |

---

## 🎉 Advantages of This Setup

### For You:
- ✅ **No manual deployment** - Just push code
- ✅ **No CLI tools needed** - GitHub handles everything
- ✅ **Version history** - Built into Git
- ✅ **Easy rollback** - Revert commits
- ✅ **Build logs** - Debug easily

### For Users:
- ✅ **Always latest version** - Auto-updates
- ✅ **Fast loading** - GitHub CDN
- ✅ **Secure** - HTTPS by default
- ✅ **Reliable** - GitHub infrastructure

---

## 📱 Share Your App

### Copy-Paste Message:

```
🎓 BAUST Project Showcase is now live!

🌐 Visit: https://mashkurulalamohi37.github.io/-baust-project-showcase/

📱 Install on iPhone:
1. Open the link in Safari
2. Tap Share (📤) → Add to Home Screen
3. Tap Add

💻 Works on any device with a browser!

✨ Features:
- Browse trending projects
- Upload your own work
- Works offline
- Fast and responsive
```

---

## 🔄 Advanced: Multiple Environments

### Production (main branch):
```
https://mashkurulalamohi37.github.io/-baust-project-showcase/
```

### Staging (develop branch):
Create another workflow for staging:

```yaml
# .github/workflows/deploy-staging.yml
on:
  push:
    branches:
      - develop
```

---

## 📚 Additional Resources

- **GitHub Pages Docs:** https://docs.github.com/en/pages
- **GitHub Actions:** https://docs.github.com/en/actions
- **Flutter Web:** https://docs.flutter.dev/platform-integration/web

---

## ✅ Deployment Checklist

Before first deployment:
- [x] Workflow file created
- [x] GitHub Pages enabled in settings
- [ ] Code committed and pushed
- [ ] Workflow running in Actions tab
- [ ] Deployment successful
- [ ] App accessible at GitHub Pages URL
- [ ] Tested on mobile devices
- [ ] Install banner works on iOS

---

## 🚀 Ready to Deploy!

**Just push your code:**

```powershell
git add .
git commit -m "Add GitHub Actions deployment workflow"
git push origin main
```

**Then watch the magic happen:**
1. Go to Actions tab
2. Watch the build progress
3. Wait for completion
4. Visit your live app!

### Your App Will Be Live At:
## 🌐 https://mashkurulalamohi37.github.io/-baust-project-showcase/

---

**Automatic deployment is now configured! 🎉**

Every push to `main` will automatically deploy your app!
