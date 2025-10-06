# Troubleshooting 401 Authentication Errors in Production

## The Problem
You can log into the admin panel, but when clicking on "edit blog posts" or any admin page, you get a 401 error.

## Root Cause
The session cookie is not being sent with subsequent requests, or the session is not being recognized by the server.

## Quick Fix (Most Common Issues)

### 1. **SESSION STORE FIX (CRITICAL)** ⚠️

**If your session ID changes between requests, this is the fix you need!**

The default MemoryStore doesn't persist sessions properly in production. You need a persistent session store.

**✅ FIXED:** The code now uses SQLite session store (`connect-sqlite3`).

**To deploy this fix:**
```bash
# On your server
cd /var/www/maya-website
git pull origin main
npm install
pm2 restart maya-website
```

This will:
- Install the `connect-sqlite3` package
- Create a persistent `sessions.db` file
- Keep sessions alive across server restarts
- Ensure session IDs remain consistent

**How to verify it's working:**
```bash
# After deploying, check the logs
pm2 logs maya-website --lines 30

# You should see:
# ✅ Login successful: { sessionID: 'ABC123...' }
# And subsequent requests should have the SAME sessionID
```

### 2. Check Your Server Logs
The updated server now logs detailed information. On your Digital Ocean server:

```bash
pm2 logs maya-website --lines 50
```

Look for these messages:
- `✅ Login successful:` - Shows cookie settings
- `❌ Auth failed:` - Shows why authentication failed
- `⚠️ WARNING: DOMAIN_URL and FRONTEND_URL not set` - CORS warning

### 3. Most Common Issue: Missing HTTPS in Nginx

**Check if your Nginx is properly forwarding the HTTPS headers:**

Edit your Nginx config:
```bash
sudo nano /etc/nginx/sites-available/maya-website
```

Make sure you have these lines in the `location /` block:

```nginx
location / {
    proxy_pass http://localhost:3000;
    proxy_http_version 1.1;
    
    # CRITICAL: These headers are required for secure cookies
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;  # THIS IS CRUCIAL!
    proxy_set_header Host $host;
    
    # For WebSocket support (optional but good to have)
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_cache_bypass $http_upgrade;
}
```

Test and reload Nginx:
```bash
sudo nginx -t
sudo systemctl reload nginx
```

### 4. Verify Environment Variables

Check your `.env` file on the server:
```bash
cat /var/www/maya-website/.env
```

Should contain:
```env
NODE_ENV=production
PORT=3000
SESSION_SECRET=<your-random-secret>
DOMAIN_URL=https://yourdomain.com
FRONTEND_URL=https://yourdomain.com
```

**Important:** Use `https://` NOT `http://`

### 5. Restart PM2 After Changes

```bash
cd /var/www/maya-website
pm2 restart maya-website
```

## Debugging Steps

### Step 1: Check Browser Console
Open Chrome DevTools (F12) → Console tab

You should see detailed error messages. Look for:
- CORS errors
- Cookie warnings
- Network errors

### Step 2: Check Network Tab
Open Chrome DevTools (F12) → Network tab

1. Click on the failed request (should be red with 401)
2. Look at "Headers" tab
3. Check "Request Headers" section

**What to look for:**
- `Cookie:` header - should contain `connect.sid=...`
- If missing, the cookie is not being sent!

### Step 3: Check Application Cookies
Open Chrome DevTools (F12) → Application tab → Cookies

Look for a cookie named `connect.sid`

**Check these properties:**
- ✅ Domain should match your domain
- ✅ Path should be `/`
- ✅ Secure should be `true` (with checkmark)
- ✅ HttpOnly should be `true` (with checkmark)
- ✅ SameSite should be `Lax`

**If cookie is missing or has wrong properties:**
- Your HTTPS setup might be broken
- Nginx headers might be missing
- NODE_ENV might not be set to `production`

## Common Solutions

### Solution 1: Cookie Not Being Set (Most Common)

**Problem:** Cookie is not appearing at all after login.

**Cause:** Nginx is not forwarding HTTPS status, so the server thinks it's HTTP and sets `secure: false`, but your browser requires `secure: true` for HTTPS sites.

**Fix:**
```nginx
# In your Nginx config, add this line:
proxy_set_header X-Forwarded-Proto $scheme;
```

Then restart:
```bash
sudo systemctl reload nginx
pm2 restart maya-website
```

### Solution 2: Cookie Being Set But Not Sent

**Problem:** Cookie appears in Application tab but not in Request Headers.

**Cause:** Domain or path mismatch, or SameSite policy too strict.

**Fix:** The code has been updated to use `sameSite: 'lax'` instead of `'strict'`. Make sure you have the latest code deployed.

### Solution 3: CORS Errors

**Problem:** Browser console shows CORS errors.

**Cause:** DOMAIN_URL doesn't match your actual domain.

**Fix:**
1. Set DOMAIN_URL in `.env` to your EXACT domain: `https://yourdomain.com`
2. Restart: `pm2 restart maya-website`

### Solution 4: Mixed Content Warnings

**Problem:** Some resources load over HTTP instead of HTTPS.

**Fix:** Add this to your Nginx config:
```nginx
# Force HTTPS
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    return 301 https://$server_name$request_uri;
}
```

## Verification Checklist

After applying fixes, verify:

1. **HTTPS is working:**
   ```bash
   curl -I https://yourdomain.com
   # Should return 200, not redirect to http
   ```

2. **Environment variables are set:**
   ```bash
   pm2 logs maya-website | grep "Login successful"
   # Should show secure: true
   ```

3. **Login works:**
   - Go to `https://yourdomain.com/admin`
   - Login with credentials
   - Check browser console for errors
   - Check Application → Cookies for `connect.sid`

4. **Navigation works:**
   - Click "ניהול בלוג" (Blog Management)
   - Should NOT get 401 error
   - Check PM2 logs if it fails: `pm2 logs maya-website`

## Still Not Working?

### Advanced Debugging

Enable verbose logging by adding this to your server:

In your `.env`:
```env
DEBUG=express-session
```

Restart and watch logs:
```bash
pm2 restart maya-website
pm2 logs maya-website
```

Then try to reproduce the issue. You'll see detailed session information.

### Check if trust proxy is working

SSH into your server and test:
```bash
# This should return your session info
curl -I https://yourdomain.com/api/admin/status
```

### Last Resort: Disable Secure Cookies Temporarily

**⚠️ SECURITY WARNING: Only for debugging!**

In `server.js`, temporarily change:
```javascript
secure: false, // Changed from: secure: isProduction
```

Restart:
```bash
pm2 restart maya-website
```

If this fixes it, your HTTPS/Nginx configuration is the problem. Go back and fix your Nginx headers, then re-enable secure cookies.

## Quick Reference: Complete Working Nginx Config

```nginx
server {
    listen 443 ssl http2;
    server_name yourdomain.com www.yourdomain.com;
    
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;  # CRITICAL!
        proxy_cache_bypass $http_upgrade;
    }
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    return 301 https://$server_name$request_uri;
}
```

## Contact for Help

If you're still stuck:
1. Run: `pm2 logs maya-website --lines 100`
2. Save the output
3. Check browser console (F12) and save any errors
4. Check Network tab for the 401 request details
5. Share these logs for debugging


