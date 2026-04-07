import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { writeFileSync } from "fs";
import { join } from "path";
import { loadConfig } from "./config.js";
import { ImapClient } from "./imap.js";
import { SmtpClient } from "./smtp.js";
import type { Config } from "./types.js";

// Zod is bundled with @modelcontextprotocol/sdk

let config: Config;
let activeAccount: string;
let imapClients: Map<string, ImapClient> = new Map();
let smtpClients: Map<string, SmtpClient> = new Map();

function getImap(account?: string): ImapClient {
  const name = account || activeAccount;
  if (!imapClients.has(name)) {
    const acc = config.accounts[name];
    if (!acc) throw new Error(`Account "${name}" not found`);
    imapClients.set(name, new ImapClient(acc));
  }
  return imapClients.get(name)!;
}

function getSmtp(account?: string): SmtpClient {
  const name = account || activeAccount;
  if (!smtpClients.has(name)) {
    const acc = config.accounts[name];
    if (!acc) throw new Error(`Account "${name}" not found`);
    smtpClients.set(name, new SmtpClient(acc));
  }
  return smtpClients.get(name)!;
}

function ok(data: unknown): { content: { type: "text"; text: string }[] } {
  return {
    content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
  };
}

function err(message: string): { content: { type: "text"; text: string }[]; isError: true } {
  return {
    content: [{ type: "text", text: `Error: ${message}` }],
    isError: true,
  };
}

const server = new McpServer({
  name: "email-mcp",
  version: "1.0.0",
});

// ── Account Tools ──

server.tool(
  "list_accounts",
  "List all configured email accounts with their labels and active status",
  {},
  async () => {
    const accounts = Object.entries(config.accounts).map(([key, acc]) => ({
      key,
      label: acc.label,
      email: acc.email,
      active: key === activeAccount,
    }));
    return ok({ accounts, activeAccount });
  }
);

server.tool(
  "switch_account",
  "Switch the active email account for subsequent operations",
  { account: z.string().describe("Account key (e.g., 'personal', 'business')") },
  async ({ account }) => {
    if (!config.accounts[account]) {
      return err(`Account "${account}" not found. Available: ${Object.keys(config.accounts).join(", ")}`);
    }
    activeAccount = account;
    return ok({ activeAccount: account, label: config.accounts[account].label });
  }
);

// ── Mailbox Tools ──

server.tool(
  "list_mailboxes",
  "List all mailbox folders with message counts and unread counts",
  {
    account: z.string().optional().describe("Account key (defaults to active account)"),
  },
  async ({ account }) => {
    try {
      const mailboxes = await getImap(account).listMailboxes();
      return ok(mailboxes);
    } catch (e) {
      return err(String(e));
    }
  }
);

server.tool(
  "create_mailbox",
  "Create a new mailbox folder",
  {
    path: z.string().describe("Folder path to create (e.g., 'Projects/ClientA')"),
    account: z.string().optional().describe("Account key"),
  },
  async ({ path, account }) => {
    try {
      await getImap(account).createMailbox(path);
      return ok({ created: path });
    } catch (e) {
      return err(String(e));
    }
  }
);

server.tool(
  "delete_mailbox",
  "Delete a mailbox folder",
  {
    path: z.string().describe("Folder path to delete"),
    account: z.string().optional().describe("Account key"),
  },
  async ({ path, account }) => {
    try {
      await getImap(account).deleteMailbox(path);
      return ok({ deleted: path });
    } catch (e) {
      return err(String(e));
    }
  }
);

server.tool(
  "rename_mailbox",
  "Rename a mailbox folder",
  {
    old_path: z.string().describe("Current folder path"),
    new_path: z.string().describe("New folder path"),
    account: z.string().optional().describe("Account key"),
  },
  async ({ old_path, new_path, account }) => {
    try {
      await getImap(account).renameMailbox(old_path, new_path);
      return ok({ renamed: { from: old_path, to: new_path } });
    } catch (e) {
      return err(String(e));
    }
  }
);

// ── Reading Tools ──

server.tool(
  "list_emails",
  "List emails in a mailbox with subject, sender, date, and flags. Most recent first.",
  {
    mailbox: z.string().default("INBOX").describe("Mailbox folder path"),
    limit: z.number().default(20).describe("Number of emails to return"),
    offset: z.number().default(0).describe("Offset for pagination"),
    account: z.string().optional().describe("Account key"),
  },
  async ({ mailbox, limit, offset, account }) => {
    try {
      const emails = await getImap(account).listEmails(mailbox, limit, offset);
      return ok({ mailbox, count: emails.length, emails });
    } catch (e) {
      return err(String(e));
    }
  }
);

server.tool(
  "search_emails",
  "Search emails by sender, subject, date range, body content, and flags",
  {
    mailbox: z.string().default("INBOX").describe("Mailbox to search in"),
    from: z.string().optional().describe("Filter by sender address or name"),
    to: z.string().optional().describe("Filter by recipient"),
    subject: z.string().optional().describe("Filter by subject (partial match)"),
    body: z.string().optional().describe("Search in email body text"),
    since: z.string().optional().describe("Emails after this date (ISO 8601)"),
    before: z.string().optional().describe("Emails before this date (ISO 8601)"),
    unseen: z.boolean().optional().describe("Only unread emails"),
    flagged: z.boolean().optional().describe("Only starred/flagged emails"),
    limit: z.number().default(20).describe("Max results"),
    account: z.string().optional().describe("Account key"),
  },
  async ({ mailbox, from, to, subject, body, since, before, unseen, flagged, limit, account }) => {
    try {
      const emails = await getImap(account).searchEmails(
        mailbox,
        { from, to, subject, body, since, before, unseen, flagged },
        limit
      );
      return ok({ mailbox, query: { from, to, subject, body, since, before, unseen, flagged }, count: emails.length, emails });
    } catch (e) {
      return err(String(e));
    }
  }
);

server.tool(
  "read_email",
  "Read the full content of a specific email by UID, including body, headers, and attachment list",
  {
    mailbox: z.string().default("INBOX").describe("Mailbox folder path"),
    uid: z.number().describe("Email UID"),
    account: z.string().optional().describe("Account key"),
  },
  async ({ mailbox, uid, account }) => {
    try {
      const email = await getImap(account).readEmail(mailbox, uid);
      return ok(email);
    } catch (e) {
      return err(String(e));
    }
  }
);

server.tool(
  "count_unread",
  "Count unread emails in a mailbox",
  {
    mailbox: z.string().default("INBOX").describe("Mailbox folder path"),
    account: z.string().optional().describe("Account key"),
  },
  async ({ mailbox, account }) => {
    try {
      const count = await getImap(account).countUnread(mailbox);
      return ok({ mailbox, unread: count });
    } catch (e) {
      return err(String(e));
    }
  }
);

// ── Writing Tools ──

server.tool(
  "send_email",
  "Compose and send a new email",
  {
    to: z.string().describe("Recipient email address(es), comma-separated"),
    subject: z.string().describe("Email subject line"),
    body: z.string().describe("Email body (plain text)"),
    html: z.string().optional().describe("HTML body (optional, overrides plain text in rich clients)"),
    cc: z.string().optional().describe("CC recipients, comma-separated"),
    bcc: z.string().optional().describe("BCC recipients, comma-separated"),
    account: z.string().optional().describe("Account key"),
  },
  async ({ to, subject, body, html, cc, bcc, account }) => {
    try {
      const result = await getSmtp(account).sendEmail({
        to, subject, text: body, html, cc, bcc,
      });
      return ok({ sent: true, messageId: result.messageId, to, subject });
    } catch (e) {
      return err(String(e));
    }
  }
);

server.tool(
  "reply_email",
  "Reply to a specific email, preserving the thread",
  {
    mailbox: z.string().default("INBOX").describe("Mailbox where the original email is"),
    uid: z.number().describe("UID of the email to reply to"),
    body: z.string().describe("Reply body (plain text)"),
    html: z.string().optional().describe("HTML body (optional)"),
    reply_all: z.boolean().default(false).describe("Reply to all recipients"),
    account: z.string().optional().describe("Account key"),
  },
  async ({ mailbox, uid, body, html, reply_all, account }) => {
    try {
      const original = await getImap(account).readEmail(mailbox, uid);
      const to = reply_all
        ? [original.from, original.to].filter(Boolean).join(", ")
        : original.replyTo || original.from;
      const cc = reply_all ? original.cc : undefined;
      const subject = original.subject.startsWith("Re:")
        ? original.subject
        : `Re: ${original.subject}`;
      const references = [...original.references, original.messageId].filter(Boolean);

      const result = await getSmtp(account).sendEmail({
        to, subject, text: body, html, cc,
        inReplyTo: original.messageId,
        references,
      });
      return ok({ sent: true, messageId: result.messageId, to, subject, replyTo: original.messageId });
    } catch (e) {
      return err(String(e));
    }
  }
);

server.tool(
  "forward_email",
  "Forward an email to another recipient with an optional message",
  {
    mailbox: z.string().default("INBOX").describe("Mailbox folder path"),
    uid: z.number().describe("UID of the email to forward"),
    to: z.string().describe("Recipient to forward to"),
    message: z.string().optional().describe("Optional message to prepend"),
    account: z.string().optional().describe("Account key"),
  },
  async ({ mailbox, uid, to, message, account }) => {
    try {
      const original = await getImap(account).readEmail(mailbox, uid);
      const subject = original.subject.startsWith("Fwd:")
        ? original.subject
        : `Fwd: ${original.subject}`;

      const forwardBody = [
        message || "",
        "",
        "---------- Forwarded message ----------",
        `From: ${original.from}`,
        `Date: ${original.date}`,
        `Subject: ${original.subject}`,
        `To: ${original.to}`,
        "",
        original.text,
      ].join("\n");

      const result = await getSmtp(account).sendEmail({
        to, subject, text: forwardBody,
      });
      return ok({ sent: true, messageId: result.messageId, to, subject });
    } catch (e) {
      return err(String(e));
    }
  }
);

// ── Organization Tools ──

server.tool(
  "move_email",
  "Move an email to a different mailbox folder",
  {
    mailbox: z.string().describe("Source mailbox"),
    uid: z.number().describe("Email UID"),
    destination: z.string().describe("Destination mailbox path"),
    account: z.string().optional().describe("Account key"),
  },
  async ({ mailbox, uid, destination, account }) => {
    try {
      await getImap(account).moveEmail(mailbox, uid, destination);
      return ok({ moved: true, uid, from: mailbox, to: destination });
    } catch (e) {
      return err(String(e));
    }
  }
);

server.tool(
  "copy_email",
  "Copy an email to another mailbox folder",
  {
    mailbox: z.string().describe("Source mailbox"),
    uid: z.number().describe("Email UID"),
    destination: z.string().describe("Destination mailbox path"),
    account: z.string().optional().describe("Account key"),
  },
  async ({ mailbox, uid, destination, account }) => {
    try {
      await getImap(account).copyEmail(mailbox, uid, destination);
      return ok({ copied: true, uid, from: mailbox, to: destination });
    } catch (e) {
      return err(String(e));
    }
  }
);

server.tool(
  "archive_email",
  "Archive an email (move to Archive folder)",
  {
    mailbox: z.string().default("INBOX").describe("Source mailbox"),
    uid: z.number().describe("Email UID"),
    account: z.string().optional().describe("Account key"),
  },
  async ({ mailbox, uid, account }) => {
    try {
      await getImap(account).moveEmail(mailbox, uid, "Archive");
      return ok({ archived: true, uid });
    } catch (e) {
      return err(String(e));
    }
  }
);

server.tool(
  "delete_email",
  "Delete an email (move to Trash)",
  {
    mailbox: z.string().default("INBOX").describe("Source mailbox"),
    uid: z.number().describe("Email UID"),
    account: z.string().optional().describe("Account key"),
  },
  async ({ mailbox, uid, account }) => {
    try {
      await getImap(account).deleteEmail(mailbox, uid);
      return ok({ deleted: true, uid });
    } catch (e) {
      return err(String(e));
    }
  }
);

server.tool(
  "mark_read",
  "Mark an email as read",
  {
    mailbox: z.string().default("INBOX").describe("Mailbox folder path"),
    uid: z.number().describe("Email UID"),
    account: z.string().optional().describe("Account key"),
  },
  async ({ mailbox, uid, account }) => {
    try {
      await getImap(account).setFlags(mailbox, uid, ["\\Seen"], "add");
      return ok({ marked_read: true, uid });
    } catch (e) {
      return err(String(e));
    }
  }
);

server.tool(
  "mark_unread",
  "Mark an email as unread",
  {
    mailbox: z.string().default("INBOX").describe("Mailbox folder path"),
    uid: z.number().describe("Email UID"),
    account: z.string().optional().describe("Account key"),
  },
  async ({ mailbox, uid, account }) => {
    try {
      await getImap(account).setFlags(mailbox, uid, ["\\Seen"], "remove");
      return ok({ marked_unread: true, uid });
    } catch (e) {
      return err(String(e));
    }
  }
);

server.tool(
  "flag_email",
  "Star/flag an email",
  {
    mailbox: z.string().default("INBOX").describe("Mailbox folder path"),
    uid: z.number().describe("Email UID"),
    account: z.string().optional().describe("Account key"),
  },
  async ({ mailbox, uid, account }) => {
    try {
      await getImap(account).setFlags(mailbox, uid, ["\\Flagged"], "add");
      return ok({ flagged: true, uid });
    } catch (e) {
      return err(String(e));
    }
  }
);

server.tool(
  "unflag_email",
  "Remove star/flag from an email",
  {
    mailbox: z.string().default("INBOX").describe("Mailbox folder path"),
    uid: z.number().describe("Email UID"),
    account: z.string().optional().describe("Account key"),
  },
  async ({ mailbox, uid, account }) => {
    try {
      await getImap(account).setFlags(mailbox, uid, ["\\Flagged"], "remove");
      return ok({ unflagged: true, uid });
    } catch (e) {
      return err(String(e));
    }
  }
);

server.tool(
  "bulk_action",
  "Apply an action to multiple emails at once",
  {
    mailbox: z.string().describe("Mailbox folder path"),
    uids: z.array(z.number()).describe("Array of email UIDs"),
    action: z.enum(["mark_read", "mark_unread", "flag", "unflag", "delete", "move", "archive"]).describe("Action to perform"),
    destination: z.string().optional().describe("Destination mailbox (required for 'move')"),
    account: z.string().optional().describe("Account key"),
  },
  async ({ mailbox, uids, action, destination, account }) => {
    try {
      const imap = getImap(account);
      let completed = 0;

      for (const uid of uids) {
        switch (action) {
          case "mark_read":
            await imap.setFlags(mailbox, uid, ["\\Seen"], "add");
            break;
          case "mark_unread":
            await imap.setFlags(mailbox, uid, ["\\Seen"], "remove");
            break;
          case "flag":
            await imap.setFlags(mailbox, uid, ["\\Flagged"], "add");
            break;
          case "unflag":
            await imap.setFlags(mailbox, uid, ["\\Flagged"], "remove");
            break;
          case "delete":
            await imap.deleteEmail(mailbox, uid);
            break;
          case "move":
            if (!destination) throw new Error("Destination required for move action");
            await imap.moveEmail(mailbox, uid, destination);
            break;
          case "archive":
            await imap.moveEmail(mailbox, uid, "Archive");
            break;
        }
        completed++;
      }

      return ok({ action, completed, total: uids.length });
    } catch (e) {
      return err(String(e));
    }
  }
);

// ── Attachment Tools ──

server.tool(
  "list_attachments",
  "List all attachments on a specific email",
  {
    mailbox: z.string().default("INBOX").describe("Mailbox folder path"),
    uid: z.number().describe("Email UID"),
    account: z.string().optional().describe("Account key"),
  },
  async ({ mailbox, uid, account }) => {
    try {
      const email = await getImap(account).readEmail(mailbox, uid);
      return ok({ uid, attachments: email.attachments });
    } catch (e) {
      return err(String(e));
    }
  }
);

server.tool(
  "download_attachment",
  "Download an email attachment to a local file path",
  {
    mailbox: z.string().default("INBOX").describe("Mailbox folder path"),
    uid: z.number().describe("Email UID"),
    part_index: z.number().describe("Attachment index (from list_attachments)"),
    save_path: z.string().describe("Local file path to save the attachment"),
    account: z.string().optional().describe("Account key"),
  },
  async ({ mailbox, uid, part_index, save_path, account }) => {
    try {
      const att = await getImap(account).getAttachmentContent(mailbox, uid, part_index);
      const fullPath = save_path.endsWith(att.filename)
        ? save_path
        : join(save_path, att.filename);
      writeFileSync(fullPath, att.content);
      return ok({ downloaded: true, filename: att.filename, path: fullPath, size: att.content.length });
    } catch (e) {
      return err(String(e));
    }
  }
);

// ── Start Server ──

async function main() {
  try {
    config = loadConfig();
    activeAccount = config.defaultAccount;
  } catch (e) {
    console.error(String(e));
    process.exit(1);
  }

  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main();
