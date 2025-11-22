# 🚀 SmartRoad Web Deployment Guide

Complete step-by-step guide to deploy your Flutter web app to a public domain.

## 📋 Prerequisites

- Flutter SDK installed
- Git installed
- Account on one of these platforms (all free):
  - [Vercel](https://vercel.com) (Recommended - Easiest)
  - [Netlify](https://netlify.com)
  - [Firebase Hosting](https://firebase.google.com)
  - [GitHub Pages](https://pages.github.com)

---

## 🎯 Option 1: Vercel (Recommended - Easiest & Free)

### Step 1: Build Your Flutter Web App

```bash
# Navigate to your project directory
cd SmartRoad

# Build for web (production)
flutter build web --release
```

This creates a `build/web` folder with all your app files.

### Step 2: Install Vercel CLI (Optional - Can use web interface)

```bash
npm install -g vercel
```

### Step 3: Deploy to Vercel

**Option A: Using Vercel CLI**

```bash
# Login to Vercel
vercel login

# Deploy (from project root)
vercel --prod

# Follow prompts:
# - Set up and deploy? Yes
# - Which scope? (your account)
# - Link to existing project? No
# - Project name? smartroad (or your choice)
# - Directory? build/web
```

**Option B: Using Vercel Web Interface (Easier)**

1. Go to [vercel.com](https://vercel.com) and sign up/login
2. Click "Add New Project"
3. Import your Git repository (GitHub/GitLab/Bitbucket)
4. Configure:
   - **Framework Preset**: Other
   - **Root Directory**: Leave as is
   - **Build Command**: `flutter build web --release`
   - **Output Directory**: `build/web`
5. Click "Deploy"

### Step 4: Add Custom Domain (Free)

1. Go to your project on Vercel dashboard
2. Click "Settings" → "Domains"
3. Click "Add Domain"
4. Enter your domain (e.g., `smartroad.com` or `www.smartroad.com`)
5. Follow DNS configuration instructions:
   - Add a CNAME record pointing to `cname.vercel-dns.com`
   - Or add an A record with Vercel's IP addresses
6. Wait for DNS propagation (5-60 minutes)
7. SSL certificate is automatically configured (HTTPS)

**Your app will be live at:** `https://your-domain.com`

---

## 🌐 Option 2: Netlify (Free & Easy)

### Step 1: Build Your Flutter Web App

```bash
flutter build web --release
```

### Step 2: Deploy to Netlify

**Option A: Using Netlify CLI**

```bash
# Install Netlify CLI
npm install -g netlify-cli

# Login
netlify login

# Deploy
netlify deploy --prod --dir=build/web
```

**Option B: Using Netlify Web Interface**

1. Go to [netlify.com](https://netlify.com) and sign up/login
2. Drag and drop your `build/web` folder to Netlify dashboard
3. Your site is live immediately!

**Option C: Using Git (Recommended)**

1. Push your code to GitHub/GitLab
2. Go to Netlify dashboard → "Add new site" → "Import an existing project"
3. Connect your repository
4. Configure build settings:
   - **Build command**: `flutter build web --release`
   - **Publish directory**: `build/web`
5. Click "Deploy site"

### Step 3: Add Custom Domain

1. Go to Site settings → Domain management
2. Click "Add custom domain"
3. Enter your domain
4. Follow DNS instructions (similar to Vercel)
5. SSL is automatic

---

## 🔥 Option 3: Firebase Hosting (Google)

### Step 1: Install Firebase CLI

```bash
npm install -g firebase-tools
```

### Step 2: Login to Firebase

```bash
firebase login
```

### Step 3: Initialize Firebase in Your Project

```bash
# From your project root
firebase init hosting

# Follow prompts:
# - Select existing project or create new
# - Public directory? build/web
# - Configure as single-page app? Yes
# - Set up automatic builds? No (or Yes if you want)
# - Overwrite index.html? No
```

### Step 4: Build and Deploy

```bash
# Build your app
flutter build web --release

# Deploy
firebase deploy --only hosting
```

### Step 5: Add Custom Domain

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project → Hosting
3. Click "Add custom domain"
4. Enter your domain
5. Follow DNS verification steps
6. SSL is automatic

---

## 📄 Option 4: GitHub Pages (Free)

### Step 1: Build Your App

```bash
flutter build web --release --base-href "/smartroad/"
```

**Note:** Replace `/smartroad/` with your repository name if different.

### Step 2: Create GitHub Actions Workflow

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy Flutter Web to GitHub Pages

on:
  push:
    branches: [ main ]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
      
      - run: flutter pub get
      - run: flutter build web --release --base-href "/smartroad/"
      
      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./build/web
```

### Step 3: Enable GitHub Pages

1. Go to your repository → Settings → Pages
2. Source: GitHub Actions
3. Save

### Step 4: Add Custom Domain (Optional)

1. Create `CNAME` file in repository root with your domain
2. Add CNAME record in your DNS pointing to GitHub Pages
3. GitHub will automatically configure SSL

---

## 🔧 Build Configuration

### Optimize Build Size

Add to `web/index.html` before `</head>`:

```html
<meta name="viewport" content="width=device-width, initial-scale=1.0">
```

### Environment Variables for Production

For production builds, you may need to set environment variables:

**Vercel/Netlify:**
- Go to Project Settings → Environment Variables
- Add: `SUPABASE_URL` and `SUPABASE_ANON_KEY` (if using Supabase)

**Firebase:**
- Use Firebase Functions or `.env` file (handled differently)

---

## 🌍 Custom Domain Setup (All Platforms)

### DNS Configuration

1. **Get your hosting provider's DNS records:**
   - Vercel: CNAME to `cname.vercel-dns.com` or A records
   - Netlify: CNAME to your-site.netlify.app
   - Firebase: A records (provided in console)

2. **Add DNS records in your domain registrar:**
   - Log in to your domain provider (GoDaddy, Namecheap, etc.)
   - Go to DNS Management
   - Add the records provided by your hosting platform

3. **Wait for DNS propagation:**
   - Usually 5-60 minutes
   - Check with: `nslookup your-domain.com`

4. **SSL Certificate:**
   - All platforms provide free SSL (HTTPS)
   - Automatically configured after DNS verification

---

## 📱 PWA Configuration (Progressive Web App)

Your app is already configured as a PWA! The `web/manifest.json` file handles this.

To test PWA features:
1. Deploy your app
2. Visit on mobile device
3. "Add to Home Screen" option will appear

---

## 🚀 Quick Deploy Commands

### Build for Production

```bash
# Standard build
flutter build web --release

# With custom base href (for subdirectory)
flutter build web --release --base-href "/your-path/"

# With web renderer (for better performance)
flutter build web --release --web-renderer canvaskit
```

### Test Build Locally

```bash
# Serve the build locally
cd build/web
python -m http.server 8000
# Or
npx serve

# Visit: http://localhost:8000
```

---

## 🎯 Recommended Setup for SmartRoad

**For MVP/Demo:**
- **Platform**: Vercel (easiest, free, fast)
- **Domain**: Use Vercel's free subdomain first (`smartroad.vercel.app`)
- **Custom Domain**: Add later when ready

**For Production:**
- **Platform**: Vercel or Netlify (both excellent)
- **Domain**: Your own domain (e.g., `smartroad.com`)
- **CDN**: Automatic (included)
- **SSL**: Automatic (free)

---

## ✅ Post-Deployment Checklist

- [ ] App loads correctly
- [ ] Map displays (OpenStreetMap tiles)
- [ ] Location permission works
- [ ] Authentication works (if using Supabase)
- [ ] Images upload correctly
- [ ] Mobile responsive design works
- [ ] HTTPS is enabled (check for padlock icon)
- [ ] Custom domain is working
- [ ] PWA features work (if applicable)

---

## 🐛 Troubleshooting

### Build Errors

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build web --release
```

### Routing Issues (404 on refresh)

- Vercel: Automatically handles this
- Netlify: Add `_redirects` file in `build/web`:
  ```
  /*    /index.html   200
  ```
- Firebase: Configured automatically

### Environment Variables Not Working

- Make sure they're set in hosting platform's dashboard
- Rebuild and redeploy after adding variables

---

## 📞 Need Help?

- Vercel Docs: https://vercel.com/docs
- Netlify Docs: https://docs.netlify.com
- Firebase Docs: https://firebase.google.com/docs/hosting
- Flutter Web: https://docs.flutter.dev/deployment/web

---

**Your SmartRoad app will be live and accessible worldwide! 🌍**

