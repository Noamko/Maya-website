// Mobile menu toggle
document.addEventListener('DOMContentLoaded', function() {
    const hamburger = document.querySelector('.hamburger');
    const navMenu = document.querySelector('.nav-menu');

    if (hamburger && navMenu) {
        hamburger.addEventListener('click', function() {
            hamburger.classList.toggle('active');
            navMenu.classList.toggle('active');
        });

        // Close mobile menu when clicking on a link
        document.querySelectorAll('.nav-link').forEach(link => {
            link.addEventListener('click', () => {
                hamburger.classList.remove('active');
                navMenu.classList.remove('active');
            });
        });

        // Close mobile menu when clicking outside
        document.addEventListener('click', function(event) {
            const isClickInsideNav = navMenu.contains(event.target);
            const isClickOnHamburger = hamburger.contains(event.target);

            if (!isClickInsideNav && !isClickOnHamburger && navMenu.classList.contains('active')) {
                hamburger.classList.remove('active');
                navMenu.classList.remove('active');
            }
        });
    }

    // Smooth scrolling for anchor links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        });
    });

    // Add scroll effect to hero image
    const imageWrapper = document.querySelector('.image-wrapper');
    if (imageWrapper) {
        window.addEventListener('scroll', function() {
            const scrolled = window.pageYOffset;
            const rate = scrolled * -0.3;
            if (window.innerWidth > 768) { // Only apply on desktop
                imageWrapper.style.transform = `rotateY(-8deg) rotateX(3deg) translateY(${rate * 0.05}px)`;
            }
        });
    }

    // Animate image on scroll
    const observerOptions = {
        threshold: 0.3,
        rootMargin: '0px 0px -50px 0px'
    };

    const observer = new IntersectionObserver(function(entries) {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const img = entry.target.querySelector('.hero-main-image');
                if (img) {
                    img.style.opacity = '1';
                    img.style.transform = 'scale(1)';
                }
            }
        });
    }, observerOptions);

    const imageContainer = document.querySelector('.image-container');
    if (imageContainer) {
        // Set initial state
        const img = imageContainer.querySelector('.hero-main-image');
        if (img) {
            img.style.opacity = '0';
            img.style.transform = 'scale(0.95)';
            img.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
        }
        observer.observe(imageContainer);
    }
});

// Add active class to current page navigation link
function setActiveNavLink() {
    const currentPath = window.location.pathname;
    const navLinks = document.querySelectorAll('.nav-link');
    
    navLinks.forEach(link => {
        link.classList.remove('active');
        const linkHref = link.getAttribute('href');
        
        // Handle root path
        if (currentPath === '/' && linkHref === '/') {
            link.classList.add('active');
        }
        // Handle other paths
        else if (currentPath === linkHref) {
            link.classList.add('active');
        }
        // Handle blog post pages (they should have /blog as active)
        else if (currentPath.startsWith('/blog/') && linkHref === '/blog') {
            link.classList.add('active');
        }
    });
}

// Call on page load
document.addEventListener('DOMContentLoaded', setActiveNavLink);

// Load page titles and update navigation
async function loadPageTitles() {
    try {
        const response = await fetch('/api/pages');
        const pages = await response.json();
        
        if (pages && pages.length > 0) {
            const pageTitles = {};
            pages.forEach(page => {
                pageTitles[page.page_key] = page.title;
            });
            
            // Update navigation menu titles
            updateNavigationTitles(pageTitles);
        }
    } catch (error) {
        console.error('Error loading page titles:', error);
    }
}

// Update navigation menu with dynamic titles
function updateNavigationTitles(pageTitles) {
    const navLinks = document.querySelectorAll('.nav-link');
    
    navLinks.forEach(link => {
        const href = link.getAttribute('href');
        let pageKey = '';
        
        if (href === '/') {
            pageKey = 'home';
        } else if (href === '/aboutme') {
            pageKey = 'about';
        } else if (href === '/treatment') {
            pageKey = 'treatment';
        }
        
        if (pageKey && pageTitles[pageKey]) {
            link.textContent = pageTitles[pageKey];
        }
    });
}

// Load page titles when DOM is ready
document.addEventListener('DOMContentLoaded', loadPageTitles);

