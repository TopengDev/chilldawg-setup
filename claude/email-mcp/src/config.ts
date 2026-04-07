import { readFileSync, existsSync } from "fs";
import { join } from "path";
import { homedir } from "os";
import type { Config } from "./types.js";

const CONFIG_PATH = join(homedir(), ".config", "email-mcp", "config.json");

export function loadConfig(): Config {
  if (!existsSync(CONFIG_PATH)) {
    throw new Error(
      `Config not found at ${CONFIG_PATH}. Copy config.example.json to ${CONFIG_PATH} and fill in your credentials.`
    );
  }

  const raw = readFileSync(CONFIG_PATH, "utf-8");
  const config: Config = JSON.parse(raw);

  if (!config.accounts || Object.keys(config.accounts).length === 0) {
    throw new Error("No accounts configured in config.json");
  }

  if (!config.defaultAccount || !config.accounts[config.defaultAccount]) {
    throw new Error(
      `Default account "${config.defaultAccount}" not found in accounts`
    );
  }

  return config;
}
