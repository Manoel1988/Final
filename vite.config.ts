import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  optimizeDeps: {
    exclude: ['lucide-react'],
  },
  server: {
    watch: {
      usePolling: true,
    },
  },
  define: {
    'process.env': {
      MYSQL_HOST: JSON.stringify(process.env.MYSQL_HOST || 'localhost'),
      MYSQL_USER: JSON.stringify(process.env.MYSQL_USER || 'root'),
      MYSQL_PASSWORD: JSON.stringify(process.env.MYSQL_PASSWORD || ''),
      MYSQL_DATABASE: JSON.stringify(process.env.MYSQL_DATABASE || 'company_management'),
    }
  }
});