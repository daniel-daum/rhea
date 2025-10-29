/// <reference types="vitest/config" />
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    "allowedHosts": ["frontend.rhea.orb.local", "backend.rhea.orb.local"]
  }
});
