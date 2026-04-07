import { ImapFlow } from "imapflow";
import { simpleParser, type ParsedMail } from "mailparser";
import type { Readable } from "stream";
import type {
  AccountConfig,
  EmailHeader,
  EmailFull,
  MailboxInfo,
  AttachmentInfo,
} from "./types.js";

export class ImapClient {
  private client: ImapFlow | null = null;
  private account: AccountConfig;

  constructor(account: AccountConfig) {
    this.account = account;
  }

  private createClient(): ImapFlow {
    return new ImapFlow({
      host: this.account.imap.host,
      port: this.account.imap.port,
      secure: this.account.imap.tls,
      auth: {
        user: this.account.email,
        pass: this.account.password,
      },
      logger: false,
    });
  }

  async connect(): Promise<void> {
    if (this.client) {
      try {
        await this.client.noop();
        return;
      } catch {
        this.client = null;
      }
    }
    this.client = this.createClient();
    await this.client.connect();
  }

  async disconnect(): Promise<void> {
    if (this.client) {
      await this.client.logout();
      this.client = null;
    }
  }

  async listMailboxes(): Promise<MailboxInfo[]> {
    await this.connect();
    const mailboxes = await this.client!.list();
    const result: MailboxInfo[] = [];

    for (const mb of mailboxes) {
      let total = 0;
      let unread = 0;
      try {
        const status = await this.client!.status(mb.path, {
          messages: true,
          unseen: true,
        });
        total = status.messages ?? 0;
        unread = status.unseen ?? 0;
      } catch {
        // Some special mailboxes don't support STATUS
      }

      result.push({
        name: mb.name,
        path: mb.path,
        delimiter: mb.delimiter,
        total,
        unread,
        flags: mb.flags ? Array.from(mb.flags) : [],
      });
    }

    return result;
  }

  async createMailbox(path: string): Promise<void> {
    await this.connect();
    await this.client!.mailboxCreate(path);
  }

  async deleteMailbox(path: string): Promise<void> {
    await this.connect();
    await this.client!.mailboxDelete(path);
  }

  async renameMailbox(oldPath: string, newPath: string): Promise<void> {
    await this.connect();
    await this.client!.mailboxRename(oldPath, newPath);
  }

  async listEmails(
    mailbox: string,
    limit: number = 20,
    offset: number = 0
  ): Promise<EmailHeader[]> {
    await this.connect();
    const lock = await this.client!.getMailboxLock(mailbox);
    try {
      const status = await this.client!.status(mailbox, { messages: true });
      const total = status.messages ?? 0;
      if (total === 0) return [];

      const start = Math.max(1, total - offset - limit + 1);
      const end = Math.max(1, total - offset);
      const range = `${start}:${end}`;

      const results: EmailHeader[] = [];
      for await (const msg of this.client!.fetch(range, {
        envelope: true,
        flags: true,
        bodyStructure: true,
        source: { start: 0, maxLength: 500 },
      })) {
        if (!msg) continue;
        const env = msg.envelope;
        if (!env) continue;
        results.push({
          uid: msg.uid,
          subject: env.subject || "(no subject)",
          from: env.from?.[0]
            ? `${env.from[0].name || ""} <${env.from[0].address}>`.trim()
            : "unknown",
          to: (env.to || [])
            .map((a) => `${a.name || ""} <${a.address}>`.trim())
            .join(", "),
          date: env.date?.toISOString() || "",
          flags: Array.from(msg.flags || []),
          hasAttachments: this.checkAttachments(msg.bodyStructure),
          preview: msg.source?.toString("utf-8").substring(0, 200) || "",
          messageId: env.messageId || "",
        });
      }

      return results.reverse();
    } finally {
      lock.release();
    }
  }

  async searchEmails(
    mailbox: string,
    query: {
      from?: string;
      to?: string;
      subject?: string;
      body?: string;
      since?: string;
      before?: string;
      unseen?: boolean;
      flagged?: boolean;
      hasAttachment?: boolean;
    },
    limit: number = 20
  ): Promise<EmailHeader[]> {
    await this.connect();
    const lock = await this.client!.getMailboxLock(mailbox);
    try {
      const searchCriteria: Record<string, unknown> = {};

      if (query.from) searchCriteria.from = query.from;
      if (query.to) searchCriteria.to = query.to;
      if (query.subject) searchCriteria.subject = query.subject;
      if (query.body) searchCriteria.body = query.body;
      if (query.since) searchCriteria.since = new Date(query.since);
      if (query.before) searchCriteria.before = new Date(query.before);
      if (query.unseen) searchCriteria.seen = false;
      if (query.flagged) searchCriteria.flagged = true;

      const searchResult = await this.client!.search(searchCriteria, { uid: true });
      const uids = Array.isArray(searchResult) ? searchResult : [];
      if (uids.length === 0) return [];

      const limitedUids = uids.slice(-limit);
      const results: EmailHeader[] = [];

      for await (const msg of this.client!.fetch(limitedUids, {
        envelope: true,
        flags: true,
        bodyStructure: true,
        uid: true,
      })) {
        if (!msg) continue;
        const env = msg.envelope;
        if (!env) continue;
        results.push({
          uid: msg.uid,
          subject: env.subject || "(no subject)",
          from: env.from?.[0]
            ? `${env.from[0].name || ""} <${env.from[0].address}>`.trim()
            : "unknown",
          to: (env.to || [])
            .map((a) => `${a.name || ""} <${a.address}>`.trim())
            .join(", "),
          date: env.date?.toISOString() || "",
          flags: Array.from(msg.flags || []),
          hasAttachments: this.checkAttachments(msg.bodyStructure),
          preview: "",
          messageId: env.messageId || "",
        });
      }

      return results.reverse();
    } finally {
      lock.release();
    }
  }

  async readEmail(mailbox: string, uid: number): Promise<EmailFull> {
    await this.connect();
    const lock = await this.client!.getMailboxLock(mailbox);
    try {
      const result = await this.client!.fetchOne(String(uid), {
        source: true,
        envelope: true,
        flags: true,
        bodyStructure: true,
        uid: true,
      });

      if (!result) throw new Error(`Email with UID ${uid} not found`);
      if (!result.source) throw new Error(`Email source not available for UID ${uid}`);

      const parsed: ParsedMail = await simpleParser(result.source as unknown as Parameters<typeof simpleParser>[0]);
      const env = result.envelope!;

      const attachments: AttachmentInfo[] = (parsed.attachments || []).map(
        (att, i) => ({
          filename: att.filename || `attachment_${i}`,
          contentType: att.contentType,
          size: att.size,
          partId: String(i),
        })
      );

      return {
        uid: result.uid,
        subject: env.subject || "(no subject)",
        from: env.from?.[0]
          ? `${env.from[0].name || ""} <${env.from[0].address}>`.trim()
          : "unknown",
        to: (env.to || [])
          .map((a) => `${a.name || ""} <${a.address}>`.trim())
          .join(", "),
        cc: (env.cc || [])
          .map((a) => `${a.name || ""} <${a.address}>`.trim())
          .join(", "),
        bcc: "",
        replyTo: env.replyTo?.[0]?.address || "",
        date: env.date?.toISOString() || "",
        flags: Array.from(result.flags || []),
        hasAttachments: attachments.length > 0,
        preview: (parsed.text || "").substring(0, 200),
        messageId: env.messageId || "",
        text: parsed.text || "",
        html: parsed.html || "",
        attachments,
        inReplyTo: env.inReplyTo || "",
        references: parsed.references
          ? Array.isArray(parsed.references)
            ? parsed.references
            : [parsed.references]
          : [],
      };
    } finally {
      lock.release();
    }
  }

  async getAttachmentContent(
    mailbox: string,
    uid: number,
    partIndex: number
  ): Promise<{ filename: string; contentType: string; content: Buffer }> {
    await this.connect();
    const lock = await this.client!.getMailboxLock(mailbox);
    try {
      const result = await this.client!.fetchOne(String(uid), {
        source: true,
        uid: true,
      });
      if (!result) throw new Error(`Email with UID ${uid} not found`);
      if (!result.source) throw new Error(`Email source not available for UID ${uid}`);

      const parsed: ParsedMail = await simpleParser(result.source as unknown as Parameters<typeof simpleParser>[0]);
      const att = parsed.attachments[partIndex];
      if (!att) throw new Error(`Attachment at index ${partIndex} not found`);

      return {
        filename: att.filename || `attachment_${partIndex}`,
        contentType: att.contentType,
        content: att.content,
      };
    } finally {
      lock.release();
    }
  }

  async moveEmail(
    mailbox: string,
    uid: number,
    destination: string
  ): Promise<void> {
    await this.connect();
    const lock = await this.client!.getMailboxLock(mailbox);
    try {
      await this.client!.messageMove(String(uid), destination, { uid: true });
    } finally {
      lock.release();
    }
  }

  async copyEmail(
    mailbox: string,
    uid: number,
    destination: string
  ): Promise<void> {
    await this.connect();
    const lock = await this.client!.getMailboxLock(mailbox);
    try {
      await this.client!.messageCopy(String(uid), destination, { uid: true });
    } finally {
      lock.release();
    }
  }

  async deleteEmail(mailbox: string, uid: number): Promise<void> {
    await this.connect();
    const lock = await this.client!.getMailboxLock(mailbox);
    try {
      await this.client!.messageDelete(String(uid), { uid: true });
    } finally {
      lock.release();
    }
  }

  async setFlags(
    mailbox: string,
    uid: number,
    flags: string[],
    action: "add" | "remove" | "set"
  ): Promise<void> {
    await this.connect();
    const lock = await this.client!.getMailboxLock(mailbox);
    try {
      if (action === "add") {
        await this.client!.messageFlagsAdd(String(uid), flags, { uid: true });
      } else if (action === "remove") {
        await this.client!.messageFlagsRemove(String(uid), flags, {
          uid: true,
        });
      } else {
        await this.client!.messageFlagsSet(String(uid), flags, { uid: true });
      }
    } finally {
      lock.release();
    }
  }

  async countUnread(mailbox: string): Promise<number> {
    await this.connect();
    const status = await this.client!.status(mailbox, { unseen: true });
    return status.unseen ?? 0;
  }

  private checkAttachments(bodyStructure: unknown): boolean {
    if (!bodyStructure) return false;
    const bs = bodyStructure as Record<string, unknown>;
    if (bs.disposition === "attachment") return true;
    if (Array.isArray(bs.childNodes)) {
      return bs.childNodes.some((child: unknown) =>
        this.checkAttachments(child)
      );
    }
    return false;
  }
}
