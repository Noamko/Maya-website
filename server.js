const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const bodyParser = require('body-parser');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const session = require('express-session');
const SQLiteStore = require('connect-sqlite3')(session);
const path = require('path');
const multer = require('multer');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;
const NODE_ENV = process.env.NODE_ENV || 'development';
const isProduction = NODE_ENV === 'production';

// Trust proxy - required for secure cookies behind reverse proxy (nginx)
if (isProduction) {
    app.set('trust proxy', 1);
}

// Middleware
// CORS configuration - allows same-origin and configured domains
const corsOptions = {
    origin: function (origin, callback) {
        // Allow requests with no origin (same-origin requests, SSR, curl, etc.)
        if (!origin) {
            return callback(null, true);
        }
        
        // In production, check against allowed origins if configured
        if (isProduction) {
            const allowedOrigins = [
                process.env.FRONTEND_URL,
                process.env.DOMAIN_URL
            ].filter(Boolean);
            
            // If no environment variables set, allow all (for easier initial deployment)
            // You should set these in production for security
            if (allowedOrigins.length === 0) {
                console.warn('⚠️  WARNING: DOMAIN_URL and FRONTEND_URL not set. CORS is open to all origins.');
                return callback(null, true);
            }
            
            // Check if origin matches any allowed origin
            const isAllowed = allowedOrigins.some(allowed => {
                // Remove protocol and trailing slash for comparison
                const normalizedAllowed = allowed.replace(/^https?:\/\//, '').replace(/\/$/, '');
                const normalizedOrigin = origin.replace(/^https?:\/\//, '').replace(/\/$/, '');
                return normalizedOrigin === normalizedAllowed || normalizedOrigin.startsWith(normalizedAllowed);
            });
            
            if (isAllowed) {
                callback(null, true);
            } else {
                console.error(`❌ CORS blocked request from origin: ${origin}`);
                console.error(`   Allowed origins: ${allowedOrigins.join(', ')}`);
                callback(new Error('Not allowed by CORS'));
            }
        } else {
            // In development, allow all origins
            callback(null, true);
        }
    },
    credentials: true
};

app.use(cors(corsOptions));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(express.static('.'));

// Create uploads directory if it doesn't exist
const uploadsDir = './assets/uploads';
if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
}

// Configure multer for image uploads
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, uploadsDir);
    },
    filename: function (req, file, cb) {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, 'blog-' + uniqueSuffix + path.extname(file.originalname));
    }
});

const upload = multer({ 
    storage: storage,
    fileFilter: function (req, file, cb) {
        const allowedTypes = /jpeg|jpg|png|gif|webp/;
        const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
        const mimetype = allowedTypes.test(file.mimetype);
        
        if (mimetype && extname) {
            return cb(null, true);
        } else {
            cb(new Error('Only image files are allowed'));
        }
    },
    limits: {
        fileSize: 5 * 1024 * 1024 // 5MB limit
    }
});

// Session configuration with persistent SQLite store
app.use(session({
    store: new SQLiteStore({
        db: 'sessions.db',
        dir: './',
        table: 'sessions'
    }),
    secret: process.env.SESSION_SECRET || 'mayakoren-secret-key-2025-change-in-production',
    resave: false,
    saveUninitialized: false,
    proxy: isProduction, // Trust the reverse proxy
    cookie: { 
        secure: isProduction, // true in production with HTTPS
        httpOnly: true,
        sameSite: isProduction ? 'none' : 'lax', // Use 'none' in production for cross-origin support
        maxAge: 24 * 60 * 60 * 1000, // 24 hours
        path: '/',
        domain: undefined // Let the browser set this automatically
    }
}));

// Database setup
const db = new sqlite3.Database('./blog.db', (err) => {
    if (err) {
        console.error('Error opening database:', err.message);
    } else {
        console.log('Connected to SQLite database');
        initializeDatabase();
    }
});

// Initialize database tables
function initializeDatabase() {
    // Create blog posts table
    db.run(`CREATE TABLE IF NOT EXISTS blog_posts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        excerpt TEXT,
        author TEXT DEFAULT 'מאיה קורן שכטמן',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        published BOOLEAN DEFAULT 1
    )`, (err) => {
        if (err) {
            console.error('Error creating blog_posts table:', err.message);
        } else {
            console.log('Blog posts table ready');
            // Add image_url column if it doesn't exist
            addImageUrlColumn();
        }
    });

    // Create admin users table
    db.run(`CREATE TABLE IF NOT EXISTS admin_users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`, (err) => {
        if (err) {
            console.error('Error creating admin_users table:', err.message);
        } else {
            console.log('Admin users table ready');
            // Create default admin user
            createDefaultAdmin();
        }
    });

    // Create pages table
    db.run(`CREATE TABLE IF NOT EXISTS pages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        page_key TEXT UNIQUE NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        image_url TEXT,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`, (err) => {
        if (err) {
            console.error('Error creating pages table:', err.message);
        } else {
            console.log('Pages table ready');
            // Add sample pages
            addSamplePages();
        }
    });
}

// Create default admin user
function createDefaultAdmin() {
    const adminPassword = 'admin';
    const hashedPassword = bcrypt.hashSync(adminPassword, 10);
    
    db.get('SELECT id FROM admin_users WHERE username = ?', ['admin'], (err, row) => {
        if (err) {
            console.error('Error checking admin user:', err.message);
        } else if (!row) {
            db.run('INSERT INTO admin_users (username, password_hash) VALUES (?, ?)', 
                ['admin', hashedPassword], (err) => {
                if (err) {
                    console.error('Error creating admin user:', err.message);
                } else {
                    console.log('Default admin user created (username: admin, password: admin)');
                }
            });
        }
    });
}

// Add image_url column if it doesn't exist
function addImageUrlColumn() {
    db.run('ALTER TABLE blog_posts ADD COLUMN image_url TEXT', (err) => {
        if (err && !err.message.includes('duplicate column name')) {
            console.error('Error adding image_url column:', err.message);
        } else {
            console.log('Image URL column ready');
            // Add sample blog posts if table is empty
            addSamplePosts();
        }
    });
}

// Add sample blog posts
function addSamplePosts() {
    db.get('SELECT COUNT(*) as count FROM blog_posts', (err, row) => {
        if (err) {
            console.error('Error checking blog posts:', err.message);
        } else if (row.count === 0) {
            const samplePosts = [
                {
                    title: 'החשיבות של שינה איכותית',
                    content: 'שינה איכותית היא הבסיס לבריאות טובה. במאמר זה נדון בחשיבות השינה ובהשפעתה על הבריאות הכללית שלנו. השינה מאפשרת לגוף להתאושש, לחזק את מערכת החיסון, ולעבד מידע שנצבר במהלך היום.',
                    excerpt: 'שינה איכותית היא הבסיס לבריאות טובה. במאמר זה נדון בחשיבות השינה ובהשפעתה על הבריאות הכללית שלנו.'
                },
                {
                    title: 'רפואה סינית וטיפול בבעיות שינה',
                    content: 'הרפואה הסינית מציעה גישה הוליסטית לטיפול בבעיות שינה. באמצעות דיקור, צמחי מרפא ושינויים באורח החיים, ניתן לשפר משמעותית את איכות השינה. במאמר זה נסקור את השיטות השונות והתועלת שלהן.',
                    excerpt: 'הרפואה הסינית מציעה גישה הוליסטית לטיפול בבעיות שינה. באמצעות דיקור, צמחי מרפא ושינויים באורח החיים.'
                },
                {
                    title: 'טיפים לשיפור איכות השינה',
                    content: 'ישנם מספר טיפים פשוטים שיכולים לשפר משמעותית את איכות השינה. הקפדה על שגרת שינה קבועה, הימנעות ממסכים לפני השינה, וסביבת שינה נוחה הם רק חלק מהדברים שיכולים לעזור. במאמר זה נפרט על כל הטיפים החשובים.',
                    excerpt: 'ישנם מספר טיפים פשוטים שיכולים לשפר משמעותית את איכות השינה. הקפדה על שגרת שינה קבועה והימנעות ממסכים.'
                }
            ];

            samplePosts.forEach((post, index) => {
                db.run('INSERT INTO blog_posts (title, content, excerpt) VALUES (?, ?, ?)', 
                    [post.title, post.content, post.excerpt], (err) => {
                    if (err) {
                        console.error('Error inserting sample post:', err.message);
                    } else {
                        console.log(`Sample post ${index + 1} added`);
                    }
                });
            });
        }
    });
}

// Add sample pages
function addSamplePages() {
    db.get('SELECT COUNT(*) as count FROM pages', (err, row) => {
        if (err) {
            console.error('Error checking pages:', err.message);
        } else if (row.count === 0) {
            const samplePages = [
                {
                    page_key: 'home',
                    title: 'שינה איכותית לחיים טובים יותר',
                    content: 'אם אתם נרדמים בקלות, ישנים שינה איכותית ומספקת, וקמים עם אנרגיה וחיוניות ליום חדש- אתם מוזמנים לגלוש הלאה או סתם לקפוץ לכוס תה.\n\nאם בכל זאת נשארתם, זה בגלל שאתם מבינים, ומבינות, שאנחנו לא סתם מבלים שליש מחיינו בשינה. השינה היא לא פחות מקריטית לבריאות שלנו בכל תחום שאפשר להעלות על הדעת:\n\n• בריאות הגוף\n• בריאות הנפש\n• מערכות יחסים\n• עבודה וקריירה\n• ליבידו\n• מערכת החיסון\n• משקל הגוף\n• זיכרון וריכוז\n• מצב רוח\n• איכות החיים\n\nאם אתם מתמודדים עם קשיי שינה, אתם לא לבד. מחקרים מראים שכ-30% מהאוכלוסייה סובלת מבעיות שינה ברמה כזו או אחרת.\n\nהרפואה הסינית מציעה גישה הוליסטית ויעילה לטיפול בבעיות שינה, תוך התמקדות בשורש הבעיה ולא רק בסימפטומים.',
                    image_url: '/assets/images/homepage-image.png'
                },
                {
                    page_key: 'about',
                    title: 'עליי',
                    content: 'שלום, אני מאיה קורן שכטמן, מטפלת ברפואה סינית עם התמחות בטיפול בבעיות שינה.\n\nאחרי שנים של התמודדות אישית עם בעיות שינה, הבנתי עד כמה השינה משפיעה על כל תחומי החיים. זה מה שהביא אותי ללמוד רפואה סינית ולהתמחות בטיפול בבעיות שינה.\n\nאני מאמינה שכל אדם יכול לישון טוב יותר, וזה לא חייב להיות מסובך או כואב. הטיפול שלי מתבסס על:\n\n• אבחון מעמיק של שורש הבעיה\n• טיפול אישי המותאם לכל מטופל\n• שילוב של דיקור, צמחי מרפא והדרכה\n• ליווי צמוד עד להשגת התוצאות\n\nהמטרה שלי היא לעזור לכם לחזור לישון טוב, להתעורר עם אנרגיה, ולחיות את החיים שאתם רוצים לחיות.',
                    image_url: '/assets/images/aboutme.png'
                },
                {
                    page_key: 'treatment',
                    title: 'על הטיפול',
                    content: 'הטיפול שלי מתבסס על עקרונות הרפואה הסינית, המשלבת בין אבחון מעמיק לטיפול הוליסטי.\n\n**תהליך הטיפול:**\n\n1. **פגישת אבחון ראשונה** - שיחה מעמיקה על בעיות השינה, אורח החיים, וההיסטוריה הרפואית\n2. **אבחון דופק ולשון** - כלי אבחון ייחודיים של הרפואה הסינית\n3. **תוכנית טיפול מותאמת** - דיקור, צמחי מרפא, והדרכה לשינוי אורח חיים\n4. **מעקב וליווי** - פגישות מעקב להערכת התקדמות והתאמת הטיפול\n\n**שיטות הטיפול:**\n\n• **דיקור** - מחטים עדינות בנקודות אסטרטגיות\n• **צמחי מרפא** - פורמולות מותאמות אישית\n• **הדרכה תזונתית** - מזונות התומכים בשינה טובה\n• **טכניקות הרפיה** - נשימה, מדיטציה, וטכניקות הרפיה\n• **שינוי אורח חיים** - שגרת שינה, פעילות גופנית, וניהול מתח\n\nהטיפול מתאים לכל הגילאים ומתבצע בסביבה נעימה ומרגיעה.',
                    image_url: '/assets/images/treatment-image.jpg'
                },
                {
                    page_key: 'sleep-medicine',
                    title: 'שינה ורפואה סינית',
                    content: 'הרפואה הסינית רואה בשינה חלק מהותי מהמחזור הטבעי של הגוף, המחובר ישירות לזרימת האנרגיה (הצ\'י) בגוף.\n\n**איך הרפואה הסינית רואה שינה:**\n\n• השינה היא זמן של התחדשות ותיקון\n• איכות השינה קשורה לאיזון האנרגיה בגוף\n• בעיות שינה מעידות על חוסר איזון פנימי\n• הטיפול מתמקד בשורש הבעיה ולא רק בסימפטומים\n\n**הגורמים לבעיות שינה לפי הרפואה הסינית:**\n\n• חוסר איזון בין יין ויאנג\n• חולשה של הלב והכליות\n• עודף חום פנימי\n• חסימות בזרימת האנרגיה\n• מתח וחרדה\n• תזונה לא מתאימה\n\n**היתרונות של הטיפול הסיני:**\n\n• טיפול טבעי ללא תופעות לוואי\n• התמקדות בשורש הבעיה\n• שיפור כללי של הבריאות\n• טיפול מותאם אישית\n• תוצאות ארוכות טווח\n\nהרפואה הסינית מציעה פתרון הוליסטי לבעיות שינה, המביא לא רק לשיפור באיכות השינה, אלא גם לבריאות כללית טובה יותר.',
                    image_url: '/assets/images/an mian.webp'
                }
            ];

            samplePages.forEach((page) => {
                db.run('INSERT INTO pages (page_key, title, content, image_url) VALUES (?, ?, ?, ?)', 
                    [page.page_key, page.title, page.content, page.image_url], (err) => {
                    if (err) {
                        console.error('Error inserting sample page:', err.message);
                    } else {
                        console.log(`Sample page ${page.page_key} added`);
                    }
                });
            });
        }
    });
}

// Authentication middleware
function requireAuth(req, res, next) {
    // Debug logging for production issues
    if (isProduction && (!req.session || !req.session.authenticated)) {
        console.error('❌ Auth failed:', {
            hasSession: !!req.session,
            sessionID: req.session ? req.session.id : 'none',
            authenticated: req.session ? req.session.authenticated : false,
            cookies: req.headers.cookie ? 'present' : 'missing',
            cookieHeader: req.headers.cookie ? req.headers.cookie.substring(0, 100) : 'none',
            path: req.path,
            secure: req.secure,
            protocol: req.protocol,
            host: req.get('host'),
            origin: req.get('origin'),
            referer: req.get('referer')
        });
    }
    
    if (req.session && req.session.authenticated) {
        return next();
    } else {
        return res.status(401).json({ 
            error: 'Authentication required',
            authenticated: false 
        });
    }
}

// Routes

// Serve static files
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});

// Clean URL routes for main pages
app.get('/aboutme', (req, res) => {
    res.sendFile(path.join(__dirname, 'about.html'));
});

app.get('/treatment', (req, res) => {
    res.sendFile(path.join(__dirname, 'treatment.html'));
});

app.get('/sleep-medicine', (req, res) => {
    res.sendFile(path.join(__dirname, 'sleep-medicine.html'));
});

// Blog page
app.get('/blog', (req, res) => {
    res.sendFile(path.join(__dirname, 'blog.html'));
});

// Serve static files for blog post pages (CSS, JS, images)
app.use('/blog', express.static('.'));

// Individual blog post page (must come after static files)
app.get('/blog/:id', (req, res) => {
    res.sendFile(path.join(__dirname, 'blog-post.html'));
});

// Admin login page
app.get('/admin', (req, res) => {
    res.sendFile(path.join(__dirname, 'admin.html'));
});

// Admin management pages
app.get('/admin/blog-management', (req, res) => {
    res.sendFile(path.join(__dirname, 'blog-management.html'));
});

app.get('/admin/pages-management', (req, res) => {
    res.sendFile(path.join(__dirname, 'pages-management.html'));
});

// Serve static files for admin edit pages
app.use('/admin', express.static('.'));

// Edit pages
app.get('/admin/edit-post', (req, res) => {
    res.sendFile(path.join(__dirname, 'edit-post.html'));
});

app.get('/admin/edit-page', (req, res) => {
    res.sendFile(path.join(__dirname, 'edit-page.html'));
});

app.get('/admin/new-post', (req, res) => {
    res.sendFile(path.join(__dirname, 'new-post.html'));
});

// API Routes

// Admin authentication
app.post('/api/admin/login', (req, res) => {
    const { username, password } = req.body;
    
    db.get('SELECT * FROM admin_users WHERE username = ?', [username], (err, user) => {
        if (err) {
            return res.status(500).json({ error: 'Database error' });
        }
        
        if (!user || !bcrypt.compareSync(password, user.password_hash)) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }
        
        req.session.authenticated = true;
        req.session.userId = user.id;
        
        // Save session explicitly and log debug info
        req.session.save((err) => {
            if (err) {
                console.error('❌ Session save error:', err);
                return res.status(500).json({ error: 'Session error' });
            }
            
            if (isProduction) {
                console.log('✅ Login successful:', {
                    sessionID: req.session.id,
                    authenticated: req.session.authenticated,
                    secure: req.secure,
                    protocol: req.protocol,
                    host: req.get('host'),
                    origin: req.get('origin'),
                    cookieSettings: {
                        secure: req.session.cookie.secure,
                        httpOnly: req.session.cookie.httpOnly,
                        sameSite: req.session.cookie.sameSite,
                        domain: req.session.cookie.domain,
                        path: req.session.cookie.path
                    }
                });
            }
            
            res.json({ success: true, message: 'Login successful' });
        });
    });
});

app.post('/api/admin/logout', (req, res) => {
    req.session.destroy((err) => {
        if (err) {
            return res.status(500).json({ error: 'Could not log out' });
        }
        res.json({ success: true, message: 'Logged out successfully' });
    });
});

// Blog posts API
app.get('/api/blog/posts', (req, res) => {
    db.all('SELECT * FROM blog_posts WHERE published = 1 ORDER BY created_at DESC', (err, rows) => {
        if (err) {
            return res.status(500).json({ error: 'Database error' });
        }
        res.json(rows);
    });
});

app.get('/api/blog/posts/:id', (req, res) => {
    const { id } = req.params;
    db.get('SELECT * FROM blog_posts WHERE id = ? AND published = 1', [id], (err, row) => {
        if (err) {
            return res.status(500).json({ error: 'Database error' });
        }
        if (!row) {
            return res.status(404).json({ error: 'Post not found' });
        }
        res.json(row);
    });
});

// Admin blog management API
app.get('/api/admin/blog/posts', requireAuth, (req, res) => {
    db.all('SELECT * FROM blog_posts ORDER BY created_at DESC', (err, rows) => {
        if (err) {
            return res.status(500).json({ error: 'Database error' });
        }
        res.json(rows);
    });
});

// Get single blog post by ID (admin)
app.get('/api/admin/blog/posts/:id', requireAuth, (req, res) => {
    const { id } = req.params;
    db.get('SELECT * FROM blog_posts WHERE id = ?', [id], (err, row) => {
        if (err) {
            res.status(500).json({ error: err.message });
            return;
        }
        if (!row) {
            res.status(404).json({ error: 'Post not found' });
            return;
        }
        res.json(row);
    });
});

// Image upload route
app.post('/api/admin/upload', requireAuth, upload.single('image'), (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: 'No image file provided' });
    }
    
    const imageUrl = `/assets/uploads/${req.file.filename}`;
    res.json({ success: true, imageUrl: imageUrl });
});

app.post('/api/admin/blog/posts', requireAuth, (req, res) => {
    const { title, content, excerpt, image_url, published = true } = req.body;
    
    if (!title || !content) {
        return res.status(400).json({ error: 'Title and content are required' });
    }
    
    db.run('INSERT INTO blog_posts (title, content, excerpt, image_url, published) VALUES (?, ?, ?, ?, ?)', 
        [title, content, excerpt, image_url, published], function(err) {
        if (err) {
            return res.status(500).json({ error: 'Database error' });
        }
        res.json({ id: this.lastID, success: true });
    });
});

app.put('/api/admin/blog/posts/:id', requireAuth, (req, res) => {
    const { id } = req.params;
    const { title, content, excerpt, image_url, published } = req.body;
    
    if (!title || !content) {
        return res.status(400).json({ error: 'Title and content are required' });
    }
    
    db.run('UPDATE blog_posts SET title = ?, content = ?, excerpt = ?, image_url = ?, published = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', 
        [title, content, excerpt, image_url, published, id], function(err) {
        if (err) {
            return res.status(500).json({ error: 'Database error' });
        }
        if (this.changes === 0) {
            return res.status(404).json({ error: 'Post not found' });
        }
        res.json({ success: true });
    });
});

app.delete('/api/admin/blog/posts/:id', requireAuth, (req, res) => {
    const { id } = req.params;
    
    db.run('DELETE FROM blog_posts WHERE id = ?', [id], function(err) {
        if (err) {
            return res.status(500).json({ error: 'Database error' });
        }
        if (this.changes === 0) {
            return res.status(404).json({ error: 'Post not found' });
        }
        res.json({ success: true });
    });
});

// Pages API
app.get('/api/pages', (req, res) => {
    db.all('SELECT * FROM pages ORDER BY page_key', (err, rows) => {
        if (err) {
            res.status(500).json({ error: err.message });
            return;
        }
        res.json(rows);
    });
});

app.get('/api/pages/:key', (req, res) => {
    const pageKey = req.params.key;
    db.get('SELECT * FROM pages WHERE page_key = ?', [pageKey], (err, row) => {
        if (err) {
            res.status(500).json({ error: err.message });
            return;
        }
        if (!row) {
            res.status(404).json({ error: 'Page not found' });
            return;
        }
        res.json(row);
    });
});

// Admin pages management API
app.get('/api/admin/pages', requireAuth, (req, res) => {
    db.all('SELECT * FROM pages ORDER BY page_key', (err, rows) => {
        if (err) {
            res.status(500).json({ error: err.message });
            return;
        }
        res.json(rows);
    });
});

// Get single page by key (admin)
app.get('/api/admin/pages/:key', requireAuth, (req, res) => {
    const pageKey = req.params.key;
    db.get('SELECT * FROM pages WHERE page_key = ?', [pageKey], (err, row) => {
        if (err) {
            res.status(500).json({ error: err.message });
            return;
        }
        if (!row) {
            res.status(404).json({ error: 'Page not found' });
            return;
        }
        res.json(row);
    });
});

app.put('/api/admin/pages/:key', requireAuth, (req, res) => {
    const pageKey = req.params.key;
    const { title, content, image_url } = req.body;
    
    if (!title || !content) {
        return res.status(400).json({ error: 'Title and content are required' });
    }
    
    db.run('UPDATE pages SET title = ?, content = ?, image_url = ?, updated_at = CURRENT_TIMESTAMP WHERE page_key = ?', 
        [title, content, image_url, pageKey], function(err) {
        if (err) {
            res.status(500).json({ error: err.message });
            return;
        }
        if (this.changes === 0) {
            res.status(404).json({ error: 'Page not found' });
            return;
        }
        res.json({ success: true });
    });
});

// Check authentication status
app.get('/api/admin/status', (req, res) => {
    res.json({ authenticated: !!(req.session && req.session.authenticated) });
});

// Start server
app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('\nShutting down server...');
    db.close((err) => {
        if (err) {
            console.error('Error closing database:', err.message);
        } else {
            console.log('Database connection closed');
        }
        process.exit(0);
    });
});