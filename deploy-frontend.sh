#!/bin/bash

# StreamYield Frontend Deployment Script
# Choose your deployment method

echo "═══════════════════════════════════════"
echo "  STREAMYIELD FRONTEND DEPLOYMENT"
echo "═══════════════════════════════════════"
echo ""
echo "Choose deployment method:"
echo "1) Netlify (Fastest - drag & drop)"
echo "2) GitHub Pages (Free forever)"
echo "3) Vercel (Professional)"
echo "4) IPFS/Fleek (Decentralized)"
echo ""
read -p "Enter choice (1-4): " choice

case $choice in
    1)
        echo ""
        echo "NETLIFY DEPLOYMENT:"
        echo "1. Go to: https://app.netlify.com/drop"
        echo "2. Drag streamyield-frontend.html into the box"
        echo "3. Done! You'll get a URL like: https://xyz.netlify.app"
        ;;
    2)
        echo ""
        echo "GITHUB PAGES DEPLOYMENT:"
        echo ""
        read -p "Enter your GitHub username: " github_user
        read -p "Enter repository name (e.g., streamyield): " repo_name
        
        git init
        git add streamyield-frontend.html
        git commit -m "Add StreamYield frontend"
        git branch -M main
        git remote add origin "https://github.com/$github_user/$repo_name.git"
        
        echo ""
        echo "Next steps:"
        echo "1. Create repository '$repo_name' on GitHub"
        echo "2. Run: git push -u origin main"
        echo "3. Go to repo Settings → Pages → Enable"
        echo "4. Your URL: https://$github_user.github.io/$repo_name/streamyield-frontend.html"
        ;;
    3)
        echo ""
        echo "VERCEL DEPLOYMENT:"
        echo ""
        if ! command -v vercel &> /dev/null; then
            echo "Installing Vercel CLI..."
            npm install -g vercel
        fi
        
        echo "Running vercel deploy..."
        vercel
        ;;
    4)
        echo ""
        echo "IPFS/FLEEK DEPLOYMENT:"
        echo "1. Go to: https://app.fleek.co"
        echo "2. Create account"
        echo "3. Click 'Add New Site'"
        echo "4. Upload streamyield-frontend.html"
        echo "5. Get your IPFS URL and .on.fleek.co domain"
        ;;
    *)
        echo "Invalid choice!"
        ;;
esac

echo ""
echo "═══════════════════════════════════════"
echo "Deployment helper complete!"
echo "═══════════════════════════════════════"

