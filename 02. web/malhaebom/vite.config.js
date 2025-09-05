import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react-swc'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': { target: 'http://localhost:3001', changeOrigin: true, secure: false },
      '/gw':  { target: 'http://localhost:4010', changeOrigin: true, secure: false }, // ★ 추가
    },
  },
})
