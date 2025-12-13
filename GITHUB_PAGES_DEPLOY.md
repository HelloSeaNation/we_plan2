# Deploying to GitHub Pages

This guide will help you deploy your Flutter web app to GitHub Pages using two methods:
1. **Automatic deployment** (Recommended) - Using GitHub Actions
2. **Manual deployment** - Build and push manually

---

## Prerequisites

1. Your project is already on GitHub (or create a new repository)
2. GitHub Pages enabled in your repository settings
3. Flutter SDK installed

---

## Method 1: Automatic Deployment with GitHub Actions (Recommended) ✅

This method automatically builds and deploys your app whenever you push to the main branch.

### Step 1: Create GitHub Actions Workflow

Create the workflow file:

1. Create folder: `.github/workflows/` (if it doesn't exist)
2. Create file: `.github/workflows/deploy.yml`

The workflow file is already created for you! See `deploy.yml` in `.github/workflows/`

### Step 2: Configure Repository Name

**Important:** You need to update the repository name in the workflow file.

1. Open `.github/workflows/deploy.yml`
2. Find the line with `base-href: "/your-repo-name/"`
3. Replace `your-repo-name` with your actual GitHub repository name

For example, if your repo is `https://github.com/username/we_plan2`, use:
```yaml
base-href: "/we_plan2/"
```

### Step 3: Enable GitHub Pages

1. Go to your GitHub repository
2. Click **Settings** → **Pages**
3. Under **Source**, select:
   - **Branch**: `gh-pages`
   - **Folder**: `/ (root)`
4. Click **Save**

### Step 4: Push to GitHub

```bash
# Add the workflow file
git add .github/workflows/deploy.yml

# Commit
git commit -m "Add GitHub Pages deployment workflow"

# Push to main branch
git push origin main
```

### Step 5: Check Deployment

1. Go to your repository on GitHub
2. Click **Actions** tab
3. You should see the workflow running
4. Wait for it to complete (usually 2-5 minutes)
5. Once done, your app will be live at:
   ```
   https://your-username.github.io/your-repo-name/
   ```

---

## Method 2: Manual Deployment

If you prefer to deploy manually:

### Step 1: Build for GitHub Pages

**Important:** Replace `your-repo-name` with your actual repository name!

```bash
# Build with correct base-href for GitHub Pages
flutter build web --release --base-href "/your-repo-name/"
```

For example, if your repo is `we_plan2`:
```bash
flutter build web --release --base-href "/we_plan2/"
```

### Step 2: Create gh-pages Branch (First Time Only)

```bash
# Create and switch to gh-pages branch
git checkout --orphan gh-pages

# Remove all files from staging
git rm -rf .

# Copy built files
cp -r build/web/* .

# Add all files
git add .

# Commit
git commit -m "Deploy to GitHub Pages"

# Push to GitHub
git push origin gh-pages
```

### Step 3: Update Deployment (For Future Updates)

```bash
# Build the app
flutter build web --release --base-href "/your-repo-name/"

# Switch to gh-pages branch
git checkout gh-pages

# Remove old files (except .git)
rm -rf *

# Copy new build files
cp -r build/web/* .

# Add and commit
git add .
git commit -m "Update deployment"

# Push
git push origin gh-pages
```

### Step 4: Switch Back to Main Branch

```bash
git checkout main
```

---

## Finding Your Repository Name

Your GitHub Pages URL will be:
```
https://your-username.github.io/repository-name/
```

To find your repository name:
1. Go to your GitHub repository
2. Look at the URL: `https://github.com/username/repository-name`
3. The repository name is the last part after the `/`

---

## Troubleshooting

### App Shows Blank Page

**Problem:** The base-href is incorrect.

**Solution:**
1. Check your repository name
2. Rebuild with correct base-href:
   ```bash
   flutter build web --release --base-href "/your-actual-repo-name/"
   ```

### 404 Errors on Routes

**Problem:** GitHub Pages doesn't support client-side routing by default.

**Solution:** Add a `404.html` file that redirects to `index.html`:

Create `web/404.html`:
```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta http-equiv="refresh" content="0; url=/your-repo-name/">
  <script>
    window.location.replace("/your-repo-name/");
  </script>
</head>
<body>
  <p>Redirecting to <a href="/your-repo-name/">home page</a>...</p>
</body>
</html>
```

Then rebuild and redeploy.

### Assets Not Loading

**Problem:** Assets are using absolute paths.

**Solution:** Make sure you're using the correct base-href when building:
```bash
flutter build web --release --base-href "/your-repo-name/"
```

### Firebase Errors

**Problem:** Firebase might block requests from GitHub Pages domain.

**Solution:**
1. Go to Firebase Console
2. Navigate to your project settings
3. Add your GitHub Pages domain to authorized domains:
   - `your-username.github.io`
   - Or your custom domain if using one

### Workflow Fails

**Problem:** GitHub Actions workflow fails to build.

**Solution:**
1. Check the **Actions** tab in your repository
2. Click on the failed workflow
3. Check the error logs
4. Common issues:
   - Flutter version mismatch
   - Missing dependencies
   - Build errors in your code

---

## Custom Domain (Optional)

If you want to use a custom domain:

1. Create a file `CNAME` in your repository root (or in `web/` folder)
2. Add your domain name:
   ```
   example.com
   ```
3. Configure DNS settings for your domain
4. Update Firebase authorized domains
5. Rebuild with root base-href:
   ```bash
   flutter build web --release --base-href "/"
   ```

---

## Updating Your App

### With Automatic Deployment (GitHub Actions)

Just push to main branch:
```bash
git add .
git commit -m "Update app"
git push origin main
```

The workflow will automatically build and deploy!

### With Manual Deployment

Follow Step 3 in the Manual Deployment section above.

---

## Quick Reference

**Your app URL:**
```
https://your-username.github.io/your-repo-name/
```

**Build command:**
```bash
flutter build web --release --base-href "/your-repo-name/"
```

**Workflow file:**
```
.github/workflows/deploy.yml
```

**Deployment branch:**
```
gh-pages
```

---

## Next Steps

1. ✅ Set up GitHub Actions workflow
2. ✅ Enable GitHub Pages in repository settings
3. ✅ Update repository name in workflow file
4. ✅ Push to main branch
5. ✅ Wait for deployment
6. ✅ Share your app URL!


