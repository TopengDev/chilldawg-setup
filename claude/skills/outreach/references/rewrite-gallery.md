# Before/After Rewrite Gallery (anti-slop, shown not told)

Full bad -> good rewrites for the failure modes SKILL.md §11 names. Study the *why* under each; the rules are abstract, these are concrete. Prime rules hold throughout (no long dash §0.1, no emoji §0.2). None of these are templates to reuse: every good version is filled from real research for ITS target.

The four things every good version does: leads with a real proof-point + link, carries >= 3 target-specific facts (passes the swap-test), one low-friction ask, Christopher's register for the channel (§7).

---

## 1. Template-blast -> tailored (email to a recruiter)

**BAD** (would fit any company by swapping the name; specificity index 1; no proof):
```
Subject: Job Application

Dear Hiring Manager,

I am a passionate fullstack developer with a proven track record, looking for
new opportunities. I am confident I would be a valuable asset to your team.
Please find my resume attached. I look forward to hearing from you.
```
Why it fails: generic subject, no name, zero specifics about THEM, empty self-claims ("passionate", "proven track record", "valuable asset"), no shipped proof, three implicit asks (read, reply, hire).

**GOOD** (research-led, one proof, one ask):
```
Subject: Fullstack (Next.js + native mobile), shipped a multi-tenant POS solo

Hi Priya,

Saw Kirana is hiring a fullstack eng for the merchant dashboard, the multi-tenant
billing piece is exactly what I have been building.

I shipped Pulse solo, a multi-tenant offline-first POS live in production with paying
Indo SMBs (coba-pulse.topengdev.com). The tenant-isolation + offline-sync model
overlaps with what your dashboard needs.

Worth a quick chat this week?

Christopher
```
Why it works: named person + named company + the actual role detail (merchant dashboard, multi-tenant billing) = 3+ specifics; a real live proof that maps; one ask. Clean punctuation (formal email, §7). Terminal action: hand-off block, he sends it (Matrix).

---

## 2. Corporate-eager -> direct (LinkedIn connection note, <= 280 chars)

**BAD** (groveling, over-length, no proof):
```
Dear Sir/Madam, I hope this message finds you well. I would be absolutely thrilled
and honored to have the opportunity to connect and humbly explore how I might
leverage my skills to add value to your esteemed organization.
```
Why it fails: "I hope this finds you well", "thrilled and honored", "humbly", "leverage", "esteemed", zero specifics, no ask that is easy to say yes to, and it blows the 280-char budget.

**GOOD** (one hook, one proof, one ask, inside 280):
```
Hi Marcus, saw Deverse is hiring a senior frontend for the trading UI. I build
real-time dashboards in Next.js, shipped a live algotrading UI solo
(topengdev.com). Close to your stack. Open to a quick chat?
```
Why it works: named person + company + the specific role (trading UI) + a mapping proof (real-time, algotrading UI) + one ask, all under budget. He pastes it (no LinkedIn send tool).

---

## 3. Overclaimed -> honest (direct-client DM)

**BAD** (claims a stack he has not touched to land it):
```
Hi, I am a Salesforce + SAP expert with 10 years of enterprise ERP experience and
deep Kubernetes and Terraform mastery. I can do anything you need.
```
Why it fails: fabricated expertise (Salesforce/SAP/10-years-ERP are not his), "expert / mastery / anything" reads as desperate, and it detonates in the first call. `no-yesman` applies to selling (§2c).

**GOOD** (real overlap led, gap stated straight):
```
Hi Denniz, your post about the inventory-sync pain at multiple outlets caught me,
I have built exactly that. Pulse (my POS SaaS, coba-pulse.topengdev.com) does
offline-first multi-outlet sync in production.

I have not worked in your exact vertical (F&B), but the sync + multi-tenant core
is the same problem. Open to a short call to see if it maps?
```
Why it works: leads with the real, mapped proof; names the honest gap (F&B vertical) without undercutting; one soft ask. Credible because it does not overreach.

---

## 4. Dash + emoji + AI-tell -> clean (Threads DM, STRICT symbol set)

**BAD** (long dashes, emoji, normal punctuation on a stylized channel, filler). The `(long dash)` + `(emoji)` tokens below stand in for the real banned glyphs so this file stays §0.1/§0.2 grep-clean:
```
Hey! I really loved your post about hiring (long dash) it resonated a lot. (emoji) I'm a passionate
dev, and I'd love to connect and explore opportunities (long dash) let me know! (emoji)
```
Why it fails: two long dashes (§0.1 violation), two emoji (§0.2), periods/commas on a stylized DM (wrong §7 register), "passionate", "resonated", "explore opportunities" = corporate-eager filler, no proof, needy exclamation.

**GOOD** (strict outreach symbol set §7: only `@ & + ( ) / * " ' : ; ! ?`, line breaks for clauses, tech names intact, proof-led):
```
your point on hiring builders who ship not just talk

that is the whole reason i built Pulse solo
a multi-tenant offline-first POS live in production
coba-pulse.topengdev.com

if you are ever hiring for that kind of work i would be up to talk
```
Why it works: engages the actual post substantively first; the proof + real link in his stylized voice; a light non-needy opener; zero periods/commas/dashes/emoji, tech names + URL kept intact. Terminal action: hand Christopher the verbatim bubbles, he sends from his phone (Threads has no safe automated send, `channel-send-playbooks.md`).

---

## 5. Spammy follow-up -> value-adding (email, touch 2)

**BAD** (content-free bump):
```
Hi, just bumping this to the top of your inbox. Did you see my previous message?
Any update? Would really appreciate a reply.
```
Why it fails: adds nothing, "just bumping", "would really appreciate" is needy, and it pesters. A content-free bump is spam (§8).

**GOOD** (adds a new relevant proof, stays graceful):
```
Hi Priya, quick add-on to last week's note: I just put up a short write-up of the
offline-sync design in Pulse, the part closest to your dashboard work
<case-study link>.

Happy to walk through it if useful. If the timing is not right, no worries, I will
leave it here.
```
Why it works: the follow-up carries new value (a fresh write-up mapped to their need), stays warm, and leaves the door open without guilt. This is touch 2 of the finite §8 cadence; touch 3 would be a graceful close-out, then STOP.
