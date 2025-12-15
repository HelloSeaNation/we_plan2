#!/bin/bash

# GitHub Pages Deployment Script
# Usage: ./deploy-to-gh-pages.sh [repository-name]

# Get repository name from argument or prompt
if [ -z "$1" ]; then
    echo "Enter your GitHub repository name (e.g., we_plan2):"
    read REPO_NAME
else
    REPO_NAME=$1
fi

echo "🚀 Deploying to GitHub Pages..."
echo "Repository name: $REPO_NAME"
echo ""

# Build the app
echo "📦 Building web app..."
flutter build web --release --base-href "/$REPO_NAME/"

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

# Check if gh-pages branch exists
if git show-ref --verify --quiet refs/heads/gh-pages; then
    echo "📝 Updating gh-pages branch..."
    git checkout gh-pages
    
    # Remove old files (keep .git)
    find . -maxdepth 1 ! -name '.' ! -name '.git' ! -name '.gitignore' -exec rm -rf {} +
    
    # Copy new build files
    cp -r build/web/* .
    
    # Add and commit
    git add .
    git commit -m "Deploy to GitHub Pages - $(date +%Y-%m-%d\ %H:%M:%S)"
    
    # Push
    git push origin gh-pages
    
    # Switch back to main
    git checkout main
    
    echo "✅ Deployment complete!"
    echo "🌐 Your app should be live at: https://your-username.github.io/$REPO_NAME/"
else
    echo "📝 Creating gh-pages branch..."
    git checkout --orphan gh-pages
    
    # Remove all files
    git rm -rf .
    
    # Copy build files
    cp -r build/web/* .
    
    # Add and commit
    git add .
    git commit -m "Initial GitHub Pages deployment"
    
    # Push
    git push origin gh-pages
    
    # Switch back to main
    git checkout main
    
    echo "✅ Initial deployment complete!"
    echo "🌐 Your app should be live at: https://your-username.github.io/$REPO_NAME/"
fi




