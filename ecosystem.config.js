module.exports = {
  apps: [{
    name: 'maya-website',
    script: './server.js',
    instances: 1, // CRITICAL: Must be 1 when using SQLite session store
    exec_mode: 'fork', // Force single process mode
    autorestart: true,
    watch: false,
    max_memory_restart: '500M',
    env_production: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    env_development: {
      NODE_ENV: 'development',
      PORT: 3000
    }
  }]
};


