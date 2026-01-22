# מאיה קורן שכטמן - אתר שינה ורפואה סינית

אתר אישי למאיה קורן שכטמן, מומחית לשינה ורפואה סינית, הכולל בלוג עם מערכת ניהול תוכן.

## תכונות

- **אתר אישי** עם דפים על השירותים והטיפולים
- **בלוג** עם מאמרים על שינה ורפואה סינית
- **מערכת ניהול תוכן** עם פאנל מנהל
- **מסד נתונים PostgreSQL** לאחסון תוכן
- **Caddy reverse proxy** עם HTTPS אוטומטי
- **תעודות SSL אוטומטיות** עם Let's Encrypt (ללא הגדרה ידנית!)
- **עיצוב רספונסיבי** המתאים למובייל ודסקטופ
- **ממשק בעברית** עם תמיכה מלאה ב-RTL
- **Docker Compose** לפריסה פשוטה

## התקנה והפעלה

### דרישות
- Docker & Docker Compose
- דומיין (לתעודת SSL אמיתית)

### הפעלה מהירה (פיתוח מקומי)

1. **צור קובץ `.env`:**
   ```bash
   cp .env.example .env
   ```

2. **ערוך את `.env` עם ערכים מאובטחים:**
   ```env
   POSTGRES_USER=maya_user
   POSTGRES_PASSWORD=your_secure_password
   POSTGRES_DB=maya_website
   SESSION_SECRET=your_session_secret
   DOMAIN=localhost
   DOMAIN_URL=https://localhost
   FRONTEND_URL=https://localhost
   ```

3. **הפעל את האפליקציה:**
   ```bash
   docker compose up -d --build
   ```

4. **פתח בדפדפן:** https://localhost
   > Caddy ישתמש בתעודה עצמית אוטומטית עבור localhost

### פריסה עם SSL אמיתי (Production)

1. **הגדר DNS:** כוון את הדומיין לכתובת ה-IP של השרת

2. **פרוס עם הסקריפט:**
   ```bash
   ./scripts/deploy.sh yourdomain.com your@email.com
   ```

   **זהו!** Caddy יקבל תעודת SSL אוטומטית מ-Let's Encrypt.

### פקודות שימושיות

```bash
# הצגת לוגים
docker compose logs -f

# לוגים של Caddy בלבד
docker compose logs -f caddy

# עצירת האפליקציה
docker compose down

# עצירה ומחיקת נתונים (התחלה מחדש)
docker compose down -v

# הפעלה מחדש
docker compose restart
```

## מבנה הפרויקט

```
maya-website/
├── server.js              # שרת Express.js
├── package.json           # הגדרות הפרויקט
├── docker-compose.yml     # הגדרות Docker (app, db, caddy)
├── Dockerfile             # בניית קונטיינר Node.js
├── Caddyfile              # הגדרות Caddy (reverse proxy + SSL)
├── index.html             # דף הבית
├── about.html             # דף "עליי"
├── treatment.html         # דף "על הטיפול"
├── blog.html              # דף הבלוג
├── blog-post.html         # תבנית פוסט בודד
├── admin.html             # פאנל מנהל
├── blog-management.html   # ניהול בלוג
├── pages-management.html  # ניהול דפים
├── edit-post.html         # עריכת פוסט
├── edit-page.html         # עריכת דף
├── new-post.html          # פוסט חדש
├── assets/
│   ├── css/styles.css     # עיצוב האתר
│   ├── js/script.js       # JavaScript
│   ├── images/            # תמונות קבועות
│   └── uploads/           # תמונות שהועלו
└── scripts/
    ├── deploy.sh          # סקריפט פריסה
    ├── setup-server.sh    # הגדרת שרת חדש
    ├── backup.sh          # גיבוי מסד נתונים
    └── restore.sh         # שחזור מסד נתונים
```

## ארכיטקטורת הקונטיינרים

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                              │
└─────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                   caddy (port 80/443)                        │
│             Automatic HTTPS + Reverse Proxy                  │
│              (SSL certificates handled automatically)        │
└─────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                      app (port 3000)                         │
│                   Node.js + Express.js                       │
└─────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                      db (port 5432)                          │
│                       PostgreSQL                             │
└─────────────────────────────────────────────────────────────┘
```

## מערכת הניהול

### גישה לפאנל המנהל
1. גש לכתובת: https://yourdomain.com/admin
2. התחבר עם:
   - **שם משתמש:** `admin`
   - **סיסמה:** `admin`

> ⚠️ **חשוב:** שנה את הסיסמה בסביבת production!

### ניהול תוכן
- **ניהול בלוג** - הוספה, עריכה ומחיקה של פוסטים
- **ניהול דפים** - עריכת תוכן דפי האתר
- **העלאת תמונות** - תמיכה בתמונות עד 5MB

## API

### פוסטים ציבוריים
- `GET /api/blog/posts` - כל הפוסטים שפורסמו
- `GET /api/blog/posts/:id` - פוסט ספציפי

### דפים ציבוריים
- `GET /api/pages` - כל הדפים
- `GET /api/pages/:key` - דף ספציפי

### ניהול (דורש אימות)
- `POST /api/admin/login` - התחברות
- `POST /api/admin/logout` - התנתקות
- `GET /api/admin/status` - סטטוס אימות
- `GET /api/admin/blog/posts` - כל הפוסטים
- `POST /api/admin/blog/posts` - פוסט חדש
- `PUT /api/admin/blog/posts/:id` - עדכון פוסט
- `DELETE /api/admin/blog/posts/:id` - מחיקת פוסט
- `PUT /api/admin/pages/:key` - עדכון דף
- `POST /api/admin/upload` - העלאת תמונה

## גיבוי ושחזור

### גיבוי ידני
```bash
./scripts/backup.sh
```

### גיבוי אוטומטי (crontab)
```bash
# כל יום בשעה 3 בלילה
0 3 * * * /path/to/maya-website/scripts/backup.sh
```

### שחזור
```bash
./scripts/restore.sh ./backups/maya_website_backup_YYYYMMDD_HHMMSS.sql.gz
```

## פריסה לשרת

### Digital Ocean Droplet

1. **הגדר את השרת:**
   ```bash
   curl -fsSL https://raw.githubusercontent.com/Noamko/Maya-website/main/scripts/setup-server.sh | bash
   newgrp docker
   ```

2. **העתק את הפרויקט:**
   ```bash
   git clone git@github.com:Noamko/Maya-website.git /var/www/maya-website
   cd /var/www/maya-website
   ```

3. **פרוס עם דומיין:**
   ```bash
   ./scripts/deploy.sh yourdomain.com admin@yourdomain.com
   ```

4. **האתר זמין ב:** https://yourdomain.com

## אבטחה

- **HTTPS אוטומטי עם TLS 1.2/1.3** - Caddy מנהל תעודות אוטומטית
- **HSTS** - כפיית HTTPS
- **סיסמאות מוצפנות** עם bcrypt
- **אימות באמצעות sessions** (PostgreSQL store)
- **הגנה מפני SQL injection** (parameterized queries)
- **Security headers** (X-Frame-Options, X-Content-Type-Options, etc.)
- **CORS מוגדר כראוי**
- **Secure cookies** בסביבת production
- **HTTP-only cookies**
- **HTTP/3 support** - פרוטוקול מהיר יותר

## רישיון

MIT License
