import nodemailer from "nodemailer";
import type { AccountConfig } from "./types.js";

export class SmtpClient {
  private account: AccountConfig;

  constructor(account: AccountConfig) {
    this.account = account;
  }

  private createTransport() {
    const smtp = this.account.smtp;
    return nodemailer.createTransport({
      host: smtp.host,
      port: smtp.port,
      secure: smtp.tls && !smtp.starttls,
      auth: {
        user: this.account.email,
        pass: this.account.password,
      },
      ...(smtp.starttls ? { requireTLS: true } : {}),
    });
  }

  async sendEmail(options: {
    to: string;
    cc?: string;
    bcc?: string;
    subject: string;
    text?: string;
    html?: string;
    inReplyTo?: string;
    references?: string[];
    attachments?: { filename: string; path: string }[];
  }): Promise<{ messageId: string }> {
    const transport = this.createTransport();
    try {
      const info = await transport.sendMail({
        from: this.account.email,
        to: options.to,
        cc: options.cc,
        bcc: options.bcc,
        subject: options.subject,
        text: options.text,
        html: options.html,
        inReplyTo: options.inReplyTo,
        references: options.references?.join(" "),
        attachments: options.attachments,
      });
      return { messageId: info.messageId };
    } finally {
      transport.close();
    }
  }

  async verify(): Promise<boolean> {
    const transport = this.createTransport();
    try {
      await transport.verify();
      return true;
    } catch {
      return false;
    } finally {
      transport.close();
    }
  }
}
