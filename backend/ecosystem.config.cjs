module.exports = {
  apps: [
    {
      name: 'medical-api',
      script: 'server.js',
      cwd: '/var/www/medical-suivi/backend',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_memory_restart: '300M',
      env: {
        NODE_ENV: 'production',
      },
    },
  ],
};
