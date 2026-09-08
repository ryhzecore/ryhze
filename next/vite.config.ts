import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
export default defineConfig({
  plugins: [react()],
  css: { postcss: { plugins: [] } },
  server: {
    proxy: {
      "/api": "http://127.0.0.1:8790",
      "/media": "http://127.0.0.1:8790",
      "/private-art": "http://127.0.0.1:8790",
    },
  },
  build: { target: "es2022", sourcemap: false },
});
