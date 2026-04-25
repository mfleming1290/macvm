import react from "@vitejs/plugin-react";
import { defineConfig, loadEnv } from "vite";

function parsePort(value: string | undefined): number | undefined {
  if (!value) {
    return undefined;
  }

  const port = Number(value);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error(`Invalid WEB_CLIENT_PORT value: ${value}`);
  }

  return port;
}

export default defineConfig(() => {
  const env = loadEnv(process.env.NODE_ENV ?? "development", process.cwd(), "");
  const port = parsePort(process.env.WEB_CLIENT_PORT ?? env.WEB_CLIENT_PORT);

  return {
    plugins: [react()],
    preview: {
      host: "0.0.0.0",
      port,
    },
    server: {
      host: "0.0.0.0",
      port,
    },
  };
});
