# CRITICAL FIX: Multiple Instance Session Problem

## Problem Identified ✅

Your logs show the **EXACT** problem:

```
Login creates: sessionID: 'YtswOfD8nJvjkue-5P4SVdP7kNflPL_S'
Cookie is sent: 'connect.sid=s%3AYtswOfD8nJvjkue-5P4SVdP7kNflPL_S...'
Server reads:  sessionID: 'XJPEtHGS0do5XjYsjmtBXilcpEuNMPh7' (DIFFERENT!)
```

**The cookie is being sent correctly**, but Digital Ocean is running **multiple app instances**, and each instance has its own SQLite `sessions.db` file that isn't shared.

## Solution 1: Scale to Single Instance (QUICK FIX)

### On Digital Ocean App Platform Dashboard:

1. Go to your app: https://cloud.digitalocean.com/apps
2. Click on your `maya-koren-website` app
3. Click **"Settings"** tab
4. Under **"Resources"**, click on your component (probably "web")
5. Look for **"Instance Size"** or **"Container Size"** 
6. Find the **"Instance Count"** or **"Container Count"** setting
7. Set it to **1** (if it's not already)
8. Click **"Save"**
9. Redeploy your app

### Or check your app spec:

In your Digital Ocean dashboard:
1. Go to your app
2. Click **"Settings"** → **"App Spec"**
3. Look for something like:
```yaml
services:
  - name: maya-website
    instance_count: 2  # ← Change this to 1
```
4. Edit and save

## Solution 2: Use Redis (PROPER FIX for scaling)

If you need multiple instances for high availability, use Redis for sessions.

### Step 1: Add Redis to Digital Ocean

In Digital Ocean dashboard:
1. Go to your app
2. Click **"Create"** → **"Create Resource"** → **"Dev Database"** (free tier)
3. Select **Redis**
4. It will add `REDIS_URL` to your environment variables

### Step 2: Install Redis session store

Update `package.json`:
```json
{
  "dependencies": {
    "connect-redis": "^7.1.0",
    "redis": "^4.6.0"
  }
}
```

### Step 3: Update server.js

Replace the SQLite session store with Redis:

```javascript
const redis = require('redis');
const RedisStore = require('connect-redis').default;

// Create Redis client
let redisClient = null;
let sessionStore = null;

if (isProduction && process.env.REDIS_URL) {
    // Use Redis in production if available
    redisClient = redis.createClient({
        url: process.env.REDIS_URL,
        socket: {
            tls: true,
            rejectUnauthorized: false
        }
    });
    
    redisClient.connect().catch(console.error);
    
    redisClient.on('error', (err) => {
        console.error('Redis Client Error', err);
    });
    
    sessionStore = new RedisStore({
        client: redisClient,
        prefix: 'maya-session:'
    });
    
    console.log('✅ Using Redis for session storage');
} else {
    // Fallback to SQLite for development or if Redis not available
    const SQLiteStore = require('connect-sqlite3')(session);
    sessionStore = new SQLiteStore({
        db: 'sessions.db',
        dir: './',
        table: 'sessions'
    });
    
    console.log('⚠️  Using SQLite for session storage (single instance only)');
}

// Session configuration
app.use(session({
    store: sessionStore,
    secret: process.env.SESSION_SECRET || 'mayakoren-secret-key-2025-change-in-production',
    resave: false,
    saveUninitialized: false,
    proxy: isProduction,
    cookie: { 
        secure: isProduction,
        httpOnly: true,
        sameSite: isProduction ? 'none' : 'lax',
        maxAge: 24 * 60 * 60 * 1000,
        path: '/',
        domain: undefined
    }
}));
```

## Verification

After applying the fix, you should see:

```
Login:  sessionID: 'ABC123...'
API:    sessionID: 'ABC123...'  (SAME!)
```

All requests should use the **SAME** session ID from the cookie.

## Recommended Approach

1. **For now**: Scale to 1 instance (Solution 1) - **QUICK FIX**
2. **Later**: Add Redis (Solution 2) if you need multiple instances for high availability

---

**Current Status**: You need to scale down to 1 instance in Digital Ocean dashboard OR add Redis.

