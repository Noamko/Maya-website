# Production Deployment Checklist

Before deploying to Digital Ocean, make sure you complete these steps:

## ✅ Server Configuration (Already Done)

- [x] Environment-aware CORS configuration
- [x] Trust proxy for Nginx reverse proxy
- [x] Secure cookies in production (HTTPS)
- [x] Session secret from environment variable
- [x] HTTP-only and SameSite cookie protection
- [x] Production vs Development detection

## 📋 Pre-Deployment Tasks

### 1. Environment Variables
Create a `.env` file on your server with:

```bash
NODE_ENV=production
PORT=3000
SESSION_SECRET=<generate-random-32-byte-string>
DOMAIN_URL=https://your-actual-domain.com
FRONTEND_URL=https://your-actual-domain.com
```

**Generate a secure session secret:**
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

### 2. Update Admin Credentials
⚠️ **IMPORTANT:** Change the default admin password immediately after deployment!

Default credentials:
- Username: `admin`
- Password: `admin`

### 3. Domain Configuration
Replace `your-actual-domain.com` with your real domain in:
- `.env` file (DOMAIN_URL and FRONTEND_URL)
- Nginx configuration

### 4. SSL Certificate
Get a free SSL certificate from Let's Encrypt:
```bash
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

### 5. File Permissions
Ensure proper permissions on your server:
```bash
chmod 755 /var/www/maya-website
chmod 644 /var/www/maya-website/blog.db
chmod 755 /var/www/maya-website/assets/uploads
```

### 6. Database Backup
Set up automatic backups (see DEPLOYMENT.md for backup script)

## 🔒 Security Checklist

- [ ] Changed default admin password
- [ ] Set strong SESSION_SECRET in .env
- [ ] Configured DOMAIN_URL to actual domain
- [ ] SSL certificate installed and working
- [ ] Firewall configured (UFW)
- [ ] Regular database backups scheduled
- [ ] `.env` file NOT committed to git
- [ ] File permissions are correct

## 🚀 Deployment Steps

1. **Upload files to server** (see DEPLOYMENT.md)
2. **Install dependencies**: `npm install --production`
3. **Create `.env` file** with production settings
4. **Start with PM2**: `pm2 start ecosystem.config.js --env production`
5. **Configure Nginx** (see DEPLOYMENT.md for config)
6. **Setup SSL** with Certbot
7. **Test the website**: `https://yourdomain.com`
8. **Test admin login**: `https://yourdomain.com/admin`

## 🔍 Post-Deployment Verification

Test these URLs:
- [ ] `https://yourdomain.com` - Homepage loads
- [ ] `https://yourdomain.com/blog` - Blog page loads
- [ ] `https://yourdomain.com/admin` - Admin login page loads
- [ ] Login to admin panel - Authentication works
- [ ] Create/Edit/Delete blog post - CRUD operations work
- [ ] Upload image - File uploads work
- [ ] Check browser console - No CORS or cookie errors

## 📊 Monitoring

After deployment, monitor:
```bash
# Check application status
pm2 status

# View logs
pm2 logs maya-website --lines 100

# Monitor in real-time
pm2 monit
```

## ⚠️ Common Issues and Solutions

### Issue: Authentication keeps redirecting
**Solution:** 
- Ensure HTTPS is working
- Check `trust proxy` is set (already configured)
- Verify `secure: true` in cookie settings for production
- Check DOMAIN_URL matches actual domain

### Issue: CORS errors in browser console
**Solution:**
- Verify DOMAIN_URL and FRONTEND_URL in `.env`
- Make sure Nginx forwards headers correctly
- Check browser is using HTTPS (not HTTP)

### Issue: 502 Bad Gateway
**Solution:**
- Check if Node app is running: `pm2 status`
- Check logs: `pm2 logs maya-website`
- Restart: `pm2 restart maya-website`

### Issue: Session not persisting
**Solution:**
- Verify cookies are being set (check browser DevTools > Application > Cookies)
- Ensure `trust proxy` is enabled
- Check Nginx is forwarding X-Forwarded-Proto header

## 📚 Documentation

- **Full Deployment Guide:** [DEPLOYMENT.md](./DEPLOYMENT.md)
- **Environment Variables:** [env.example](./env.example)
- **PM2 Configuration:** [ecosystem.config.js](./ecosystem.config.js)

## 🆘 Need Help?

If you encounter issues:
1. Check the logs: `pm2 logs maya-website`
2. Verify environment variables: `cat .env`
3. Test direct connection: `curl http://localhost:3000`
4. Check Nginx config: `sudo nginx -t`
5. Review [DEPLOYMENT.md](./DEPLOYMENT.md) troubleshooting section


