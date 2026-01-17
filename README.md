# מאיה קורן שכטמן - אתר שינה ורפואה סינית

אתר אישי למאיה קורן שכטמן, מומחית לשינה ורפואה סינית, הכולל בלוג עם מערכת ניהול תוכן.

## תכונות

- **אתר אישי** עם דפים על השירותים והטיפולים
- **בלוג** עם מאמרים על שינה ורפואה סינית
- **מערכת ניהול תוכן** עם פאנל מנהל
- **מסד נתונים PostgreSQL** לאחסון תוכן
- **Nginx reverse proxy** עם תמיכה ב-HTTPS
- **תעודות SSL אוטומטיות** עם Let's Encrypt
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
   DOMAIN_URL=https://localhost
   FRONTEND_URL=https://localhost
   ```

3. **צור תעודות SSL לפיתוח מקומי:**
   ```bash
   ./scripts/generate-self-signed.sh
   ```

4. **הפעל את האפליקציה:**
   ```bash
   docker compose up -d --build
   ```

5. **פתח בדפדפן:** https://localhost
   > הדפדפן יציג אזהרה על תעודה עצמית - זה צפוי בפיתוח. לחץ "Advanced" והמשך.

### פריסה עם SSL אמיתי (Production)

1. **הגדר DNS:** כוון את הדומיין לכתובת ה-IP של השרת

2. **צור קובץ `.env`:**
   ```bash
   cp .env.example .env
   nano .env
   ```

3. **הגדר את הדומיין:**
   ```env
   DOMAIN_URL=https://yourdomain.com
   FRONTEND_URL=https://yourdomain.com
   ```

4. **הפעל את סקריפט ה-SSL:**
   ```bash
   ./scripts/init-ssl.sh yourdomain.com your@email.com
   ```

5. **הפעל את האפליקציה:**
   ```bash
   docker compose up -d
   ```

### פקודות שימושיות

```bash
# הצגת לוגים
docker compose logs -f

# לוגים של nginx בלבד
docker compose logs -f nginx

# עצירת האפליקציה
docker compose down

# עצירה ומחיקת נתונים (התחלה מחדש)
docker compose down -v

# הפעלה מחדש
docker compose restart

# חידוש תעודות SSL (אוטומטי, אבל אפשר ידנית)
docker compose run --rm certbot renew
```

## מבנה הפרויקט

```
maya-website/
├── server.js              # שרת Express.js
├── package.json           # הגדרות הפרויקט
├── docker-compose.yml     # הגדרות Docker (app, db, nginx, certbot)
├── Dockerfile             # בניית קונטיינר Node.js
├── nginx/
│   ├── nginx.conf         # הגדרות Nginx עם SSL
│   └── nginx-init.conf    # הגדרות ראשוניות (HTTP בלבד)
├── certbot/               # תעודות SSL (לא בגיט)
│   ├── conf/              # תעודות Let's Encrypt
│   └── www/               # אתגר ACME
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
    ├── backup.sh          # גיבוי מסד נתונים
    ├── restore.sh         # שחזור מסד נתונים
    ├── init-ssl.sh        # הגדרת SSL עם Let's Encrypt
    └── generate-self-signed.sh  # תעודות עצמיות לפיתוח
```

## ארכיטקטורת הקונטיינרים

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                              │
└─────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                     nginx (port 80/443)                      │
│                   SSL Termination + Proxy                    │
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

┌─────────────────────────────────────────────────────────────┐
│                        certbot                               │
│               SSL Certificate Renewal                        │
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

1. **התקן Docker:**
   ```bash
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker $USER
   newgrp docker
   ```

2. **העתק את הפרויקט:**
   ```bash
   git clone <repo-url> /var/www/maya-website
   cd /var/www/maya-website
   ```

3. **צור `.env` עם ערכים מאובטחים:**
   ```bash
   cp .env.example .env
   nano .env
   ```

4. **הגדר SSL עם Let's Encrypt:**
   ```bash
   ./scripts/init-ssl.sh yourdomain.com admin@yourdomain.com
   ```

5. **האתר זמין ב:** https://yourdomain.com

## אבטחה

- **HTTPS עם TLS 1.2/1.3** - הצפנת תעבורה
- **HSTS** - כפיית HTTPS
- **סיסמאות מוצפנות** עם bcrypt
- **אימות באמצעות sessions** (PostgreSQL store)
- **הגנה מפני SQL injection** (parameterized queries)
- **Rate limiting** בנקודות הקצה
- **Security headers** (X-Frame-Options, X-Content-Type-Options, etc.)
- **CORS מוגדר כראוי**
- **Secure cookies** בסביבת production
- **HTTP-only cookies**

## רישיון

MIT License
