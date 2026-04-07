export interface ImapConfig {
  host: string;
  port: number;
  tls: boolean;
}

export interface SmtpConfig {
  host: string;
  port: number;
  tls?: boolean;
  starttls?: boolean;
}

export interface AccountConfig {
  label: string;
  imap: ImapConfig;
  smtp: SmtpConfig;
  email: string;
  password: string;
}

export interface Config {
  accounts: Record<string, AccountConfig>;
  defaultAccount: string;
}

export interface EmailHeader {
  uid: number;
  subject: string;
  from: string;
  to: string;
  date: string;
  flags: string[];
  hasAttachments: boolean;
  preview: string;
  messageId: string;
}

export interface EmailFull extends EmailHeader {
  cc: string;
  bcc: string;
  replyTo: string;
  text: string;
  html: string;
  attachments: AttachmentInfo[];
  inReplyTo: string;
  references: string[];
}

export interface AttachmentInfo {
  filename: string;
  contentType: string;
  size: number;
  partId: string;
}

export interface MailboxInfo {
  name: string;
  path: string;
  delimiter: string;
  total: number;
  unread: number;
  flags: string[];
}
