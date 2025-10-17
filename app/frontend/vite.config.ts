import react from '@vitejs/plugin-react'
import path from 'path'
import { defineConfig } from 'vite'

// https://vitejs.dev/config/
export default defineConfig(({ mode }) => ({
  plugins: [react()],
  define: mode === 'production' ? {
    'import.meta.env.VITE_API_URL': JSON.stringify('https://sy.jsshou.cn/api')
  } : {},
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
}))
