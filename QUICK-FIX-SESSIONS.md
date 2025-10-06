# Quick Fix: Session Authentication Issues

## The Problem
Session IDs were changing between requests because the default MemoryStore doesn't persist sessions properly in production.

## The Solution
Added SQLite session store for persistent session management.

## Deploy This Fix Now

### Step 1: SSH into your server
```bash
ssh your-user@your-server-ip
```

### Step 2: Navigate to your project directory
```bash
cd /var/www/maya-website
```

### Step 3: Pull the latest changes
```bash
git pull origin main
```

### Step 4: Install new dependencies
```bash
npm install
```

This will install `connect-sqlite3` for persistent session storage.

### Step 5: Restart your application
```bash
pm2 restart maya-website
```

### Step 6: Verify it's working
```bash
pm2 logs maya-website --lines 30
```

Look for:
- `✅ Login successful:` with a session ID
- Subsequent requests should have the **SAME** session ID (not different ones)

### Step 7: Test in browser
1. Go to `https://yourdomain.com/admin`
2. Log in with your credentials
3. Click "ניהול בלוג" (Blog Management)
4. **You should NOT get a 401 error anymore!**

## What Changed

### Files Modified:
1. **package.json** - Added `connect-sqlite3` dependency
2. **server.js** - Configured SQLite session store
3. **.gitignore** - Added sessions.db and other files to ignore
4. **TROUBLESHOOTING-401.md** - Updated with this fix

### New Files Created:
- `sessions.db` - Will be created automatically on first run (stores session data persistently)

## How to Monitor

After deploying, you can monitor your logs in real-time:
```bash
pm2 logs maya-website --lines 50 --no-daemon
```

Press `Ctrl+C` to exit.

## If It Still Doesn't Work

Check the full troubleshooting guide: `TROUBLESHOOTING-401.md`

Common additional issues:
1. Missing `X-Forwarded-Proto` header in Nginx
2. Missing environment variables in `.env`
3. HTTPS certificate issues

## Clean Up Old Sessions (Optional)

If you want to clear all old sessions and start fresh:
```bash
cd /var/www/maya-website
rm -f sessions.db
pm2 restart maya-website
```

This will create a new empty session database.

