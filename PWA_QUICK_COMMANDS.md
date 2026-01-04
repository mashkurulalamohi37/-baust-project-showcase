# 🚀 PWA Quick Commands

## 📱 Your Live PWA
**URL:** `https://projectshowcase-56c2b.web.app`

---

## 🔄 Update & Deploy

```powershell
# Full rebuild and deploy
flutter clean
flutter pub get
flutter build web --release
firebase deploy --only hosting
```

```powershell
# Quick update (if no dependency changes)
flutter build web --release
firebase deploy --only hosting
```

---

## 🧪 Test Locally

```powershell
# Build first
flutter build web --release

# Serve locally
cd build\web
python -m http.server 8000
# Open: http://localhost:8000
```

---

## 📱 Installation Instructions

### iPhone/iPad:
1. Open Safari
2. Go to: `https://projectshowcase-56c2b.web.app`
3. Wait 3 seconds for install banner
4. Tap Share → Add to Home Screen

### Android:
1. Open Chrome
2. Go to: `https://projectshowcase-56c2b.web.app`
3. Tap install prompt or Menu → Add to Home Screen

### Desktop:
1. Open Chrome/Edge/Safari
2. Go to: `https://projectshowcase-56c2b.web.app`
3. Click install icon in address bar

---

## 🐛 Quick Fixes

### Clear cache and rebuild:
```powershell
flutter clean
flutter pub get
flutter build web --release
firebase deploy --only hosting
```

### Re-login to Firebase:
```powershell
firebase logout
firebase login
firebase deploy --only hosting
```

### Check deployment status:
```powershell
firebase hosting:channel:list
```

---

## 📊 Check PWA Status

### In Browser DevTools (F12):
1. **Application** tab
2. Check:
   - Manifest ✅
   - Service Worker ✅
   - Cache Storage ✅

### Test Offline:
1. Open DevTools → Network tab
2. Check "Offline" checkbox
3. Refresh page - should still work!

---

## 🎨 Customize

### Update app name:
Edit `web/manifest.json`:
```json
{
  "name": "Your App Name",
  "short_name": "Short Name"
}
```

### Update colors:
Edit `web/manifest.json`:
```json
{
  "theme_color": "#0f3460",
  "background_color": "#1a1a2e"
}
```

### Update meta tags:
Edit `web/index.html` (lines 10-17)

---

## 📈 Monitor

### Firebase Console:
- Hosting → Dashboard
- View traffic, bandwidth, requests

### Analytics:
- Firebase Console → Analytics
- Track user engagement

---

## 🔗 Important Files

- `web/index.html` - Main HTML with PWA setup
- `web/manifest.json` - PWA configuration
- `web/icons/` - App icons
- `firebase.json` - Hosting configuration
- `build/web/` - Built app (deploy this)

---

## ⚡ Pro Tips

1. **Always test locally before deploying**
2. **Clear cache when testing changes**
3. **Use incognito mode for fresh testing**
4. **Check console for errors**
5. **Test on real iOS device for best results**

---

## 📞 Quick Links

- **Live App:** https://projectshowcase-56c2b.web.app
- **Firebase Console:** https://console.firebase.google.com
- **Full Guide:** [PWA_DEPLOYMENT_GUIDE.md](PWA_DEPLOYMENT_GUIDE.md)
- **Completion Summary:** [PWA_CONVERSION_COMPLETE.md](PWA_CONVERSION_COMPLETE.md)

---

**Last Updated:** 2026-01-04
