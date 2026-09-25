# EVENT STUDIO — Licensing, Activation & Code Protection Plan

> Owner: **vzjRR** · Status: approved design for 1.0 packaging · Researched 2026-09-25
> This document answers the requirement: *"Nobody can copy, edit, modify or alter anything. Activation is only by me, per server, from my backend. It must not be hackable or patchable."*

---

## 1. Summary

| Requirement | Achievable? | How |
|---|---|---|
| Only servers you approve can run it | **Yes** | Cfx.re **Asset Escrow** + **Tebex**. The resource refuses to start ("You lack the required entitlement") unless the server's license key belongs to a Cfx account you granted it to. You approve each customer by selling to them or issuing a **Tebex manual payment**. |
| You can switch a customer off later | **Yes, for subscriptions only** | Sell as a Tebex **subscription**: access ends automatically when the subscription ends (PLA §6.3(ii)). One-time sales are **irrevocable** by the Cfx license agreement (PLA §6.3(i)). |
| Nobody can read or edit the core code | **Yes for server code, practically** | Escrow encrypts every Lua file; server code is only decrypted in memory inside the Cfx runtime after the entitlement check. Only the files you choose (config, locales, themes, hooks) stay editable. |
| Nobody can copy the client code or UI | **No** | Client Lua has to be decrypted on players' PCs to run, and Cfx does not protect NUI (HTML/JS/CSS) at all. Mitigation: EVENT STUDIO keeps **no valuable logic on the client** (it's server-authoritative), so a dump only gives the rendering layer, which doesn't work without the server half. |
| Activation checked by **your own backend**, keyed to a server id | **Not allowed** | Cfx.re rules forbid rolling your own licensing / license tokens / remote checking for released resources, and FiveM blocks resources with "prohibited logic". Escrow *is* the per-server, server-side activation, run by Cfx on your behalf. |
| Restrict to exactly one server | **No** | Escrow entitlement follows the buyer's Cfx account; one purchase runs on every server that uses a key from that account, and the license agreement grants use on "one or more Custom Servers" the admin holds keys for. Per-server pricing has to be handled commercially (tiers, subscription per server, terms). |
| "Unhackable / unpatchable" | **No software can promise this** | Anything that runs on someone else's machine can eventually be attacked; escrow itself had an exploit that Cfx fixed in 2025. What we can do is make piracy expensive, pointless (no server code) and risky (Cfx suspends and bans servers that use leaked assets). |

**Bottom line:** the most secure option is also the only one that's allowed: **escrow + Tebex, a server-authoritative design, subscription licensing for anything you want to be able to revoke, and legal enforcement.** A home-made activation server would be *weaker* (it runs as ordinary code on the customer's server, where it could be removed) *and* would break the platform rules.

---

## 2. Research findings (sources)

1. **Asset Escrow** encrypts Lua (plus YFT/YDD/YDR). Unauthorized servers fail with *"You lack the required entitlement"*. Distribution is only via Tebex, assets cannot be transferred between accounts, and "obfuscating code in escrowed resources is not necessary". NUI is not supported. — [Cfx docs: Asset Escrow](https://docs.fivem.net/docs/server-manual/asset-escrow/)
2. Escrow was introduced as the replacement for obfuscation and IP locking: *"Obfuscating or remotely loading/checking code was already not permitted per our releases rules"*, and creators cannot run their own licensing systems. NUI: *"treat NUI as any web browser; websites that you visit also don't protect their frontend code."* — [Cfx forum: Introducing Asset Escrow](https://forum.cfx.re/t/introducing-asset-escrow-for-your-resources/4777151)
3. **Release rules:** releases "should not use third-party encryption/obfuscation or use remote code loading and execution"; *"Requiring users to join a Discord server, enter license tokens, register accounts, or similar to acquire and/or run a resource is not permitted"*; paid releases must be sold through Tebex. — [Releases Rules and FAQ](https://forum.cfx.re/t/releases-rules-and-faq/240725), [Important update to Release Rules](https://forum.cfx.re/t/important-update-to-our-release-rules-and-faq/5277567)
4. **Prohibited logic:** FiveM scans resources before they start and disables ones it considers malicious; obfuscated and remote-code-loading resources are commonly caught. — [ZAP-Hosting: prohibited logic](https://zap-hosting.com/guides/docs/fivem-prohibited-resources/), [Nodecraft KB](https://nodecraft.com/support/games/fivem/troubleshooting/troubleshooting-fivem-server-error-resource-contains-prohibited-logic), [Cfx Resource FAQ](https://docs.fivem.net/docs/support/resource-faq/)
5. **Creator Platform License Agreement** ([fivem.net/terms](https://fivem.net/terms), 10 Sept 2026):
   - §5.2: Rockstar may *require* the use of Authorized Services (Tebex for monetisation).
   - §6.3: a marketplace license covers *"one or more Custom Servers for which you act as Server Admin and hold a corresponding server key"*; **one-time-fee licenses are irrevocable**; **subscription licenses end when the subscription ends**.
   - §6.4: buyers may not *resell, share, redistribute, decompile, reverse-engineer or modify* marketplace content beyond what's permitted. This is your legal protection.
6. **Multiple servers:** a purchase runs on every server that uses a license key from the owning Cfx account. — [n4.gg escrow docs](https://docs.n4.gg/escrow/), [Keymaster guide (your-script)](https://www.your-script.com/guides/fivem-keymaster-guide)
7. **Tebex manual payments** let the store owner issue any package to a chosen customer without a checkout, and every one is logged. — [Tebex docs: Manual Payments](https://docs.tebex.io/creators/tebex-control-panel/payments-overview/manual-payments). Subscription packages can reissue assets. — [Codesign escrow guide](https://docs.codesign.pro/helpful-guides/fivem-asset-escrow-system)
8. **Escrow's limits and history:** client scripts are decrypted on players' machines and modified clients can dump them; server code is never delivered as plaintext. — [FiveSecured: how escrow works](https://fivesecured.com/guides/fivem-asset-escrow), [FiveSecured: "escrow bypass" tools](https://fivesecured.com/guides/fivem-escrow-bypass). In 2025 Cfx fixed an escrow extraction vulnerability, added more protection, and suspended and then permanently banned servers using leaked assets. — [Cfx: Asset Security Update](https://forum.cfx.re/t/asset-security-update/5344773/1), [@FiveM on X](https://x.com/FiveM/status/1978815888502435936)
9. Third-party licensing layers (e.g. FiveSecured) advertise their own encryption, watermarking and revocation, but that is exactly what the Cfx release rules forbid for released resources. **Not adopted** (see §6).

---

## 3. Threat model

| Attacker | Goal | What they can get | Mitigation |
|---|---|---|---|
| Buyer | copy to friends' servers | nothing; entitlement is tied to their Cfx account | Escrow; PLA §6.4; Tebex/Cfx takedown |
| Buyer | edit the core | only the escrow-ignored files | Keep the editable surface to config/locales/themes/hooks |
| Buyer | keep using it after cancelling | nothing, if sold as a subscription | Subscription packages |
| Player with a modified client | steal client code / UI | the thin client layer and the NUI | Server-authoritative design; the client has no rules, scoring, rewards or admin logic |
| Leak sites | redistribute a "cracked" build | client dumps; server code only through escrow exploits | Keep releases on the latest escrow; Cfx enforcement against servers running leaked assets; frequent updates make old dumps stale |
| Server cheater | fake scores / rewards | nothing | Existing SECURITY.md controls (RPC gateway, validation, ledger) |

---

## 4. Protection architecture (what we build)

### Layer 1 — Asset Escrow (encryption and per-server activation, enforced by Cfx)
- All Lua in `server/`, `client/`, `shared/`, `modes/`, `integrations/framework/` is encrypted. `lua54 'yes'` is set, as escrow requires.
- `escrow_ignore` covers only files the buyer is meant to edit:
  `config/**`, `locales/*.lua`, `integrations/custom/*.lua`, `web/themes/*.css`, `migrations/*.sql`.
- At runtime the server's license key is checked against the entitlement **before** decryption. An unapproved server can't start the resource.

### Layer 2 — Activation controlled by vzjRR (Tebex)
- **Public sales:** Tebex checkout. Every sale is logged and tied to the buyer's Cfx account.
- **Hand-picked activation ("only me"):** keep the package hidden or unlisted and issue access yourself with **Tebex → Payments → Create Payment → Manual Payment** (the customer's Cfx-linked account plus the package). Nobody gets the asset without you.
- **Revocable activation:** sell as a **subscription** (monthly or yearly). Cancel or refund it, or stop renewals, and access ends (PLA §6.3(ii)).
- **Per-server commercial tiers:** since entitlement is per account, sell "Single server" / "Network (up to N servers)" tiers as a commercial term in the EULA, enforced legally and through subscriptions, not technically.

### Layer 3 — Server-authoritative design (makes client dumps worthless) ✅ already in place
- Rules, state machine, scoring, placements, rewards, permissions, scheduler, tournaments and storage all live on the server.
- Client Lua only renders markers and blips, applies loadouts and sends intents.
- The NUI is a view with no business rules. It calls `rpc`, and the server validates every call.
- Hidden hunt locations and trivia answers never leave the server.

### Layer 4 — Minimal shipped surface (`tools/build_release.py`)
- The release build leaves out `tests/`, `tools/`, the dev preview (`web/js/dev.js`) and developer-only docs.
- It checks: versions match, `lua54`, every file passes `luac -p`, `escrow_ignore` exists and doesn't expose core code, no Discord webhook URLs or secrets in shared config, no custom licensing / remote-load patterns (`load(` fed by `PerformHttpRequest`, `loadstring`, IP checks) that could trigger prohibited-logic blocks.
- Output: `dist/event_studio/` + `dist/event_studio-<version>.zip`, ready to upload to the Cfx Portal (Created Assets → Upload).

### Layer 5 — Legal
- The final EULA in `LICENSE.md` (a placeholder until you publish yours) references PLA §6.4: no resale, sharing, decompiling, reverse-engineering or modification beyond the config surface, and states per-server tier terms.
- Enforcement: Tebex/Cfx creator reports; Cfx has suspended and banned servers that use leaked assets.

### Layer 6 — Operations
- Re-upload every release to the Portal so it uses the latest escrow protections (Cfx offers re-encryption of existing assets).
- Ship regular updates; leaked old versions go stale, and new features only reach entitled servers.
- Watch for leaks and report them to Cfx/Tebex with purchase records.

### Layer 7 — Optional future "vendor cloud" (value-add, never a lock)
If you want something that only exists on **your** backend, build **online features**, not licensing: cross-server leaderboards, a cloud library of event packs, a web dashboard. Rules for doing that without breaking the platform rules:
- The core resource works fully without it; it is never required to *run* the resource.
- Only data is exchanged over HTTPS (`PerformHttpRequest` JSON). **No code is ever downloaded or executed.**
- The customer opts in with their own API key from your dashboard. You can switch off *your service* for anyone; you don't switch off *their resource*.
- Confirm with Cfx.re support before launch that the integration is compliant.

---

## 5. Activation workflow (step by step, for vzjRR)

1. `python3 tools/build_release.py` produces `dist/event_studio-<ver>.zip`.
2. Cfx Portal → *Created Assets* → upload the zip → wait for "escrowed".
3. Tebex → Packages → create package → type **FiveM Asset** → select the asset.
   - Choose **One-time** (irrevocable) or **Subscription** (revocable).
   - For approval-only sales, set the package hidden/unlisted.
4. To activate a customer yourself: Tebex → Payments → **Create Payment → Manual Payment** → customer + package. Access is delivered to their Cfx account within minutes.
5. The customer downloads it from their Cfx Portal (*Granted Assets*) and adds `ensure event_studio`. It runs on servers using license keys from **that** account only.
6. To revoke (subscriptions): cancel the subscription in Tebex. The entitlement ends and the resource won't start on their next restart.
7. Updates: rebuild → re-upload → customers download the new version from the Portal.

---

## 6. What we will not do, and why

| Rejected approach | Why |
|---|---|
| Own activation server checking a server id / license key / IP | Against the Cfx release rules ("enter license tokens… not permitted", no remote checking); risks prohibited-logic blocks and platform action against you and your customers; and it runs as ordinary code on the customer's server, so it's weaker than escrow. |
| Obfuscators / custom encryption | Forbidden by the release rules; FiveM blocks obfuscated resources; unnecessary with escrow. |
| Downloading core code from your server at runtime ("backend only") | Remote code loading is forbidden and blocked. FiveM natives have to run on the game server anyway, so the engine can't run remotely. |
| Kill switch in one-time sales | One-time marketplace licenses are irrevocable (PLA §6.3(i)). Use subscriptions instead. |
| Selling outside Tebex with a custom DRM | Paid releases must go through Tebex/escrow; §5.2 lets Rockstar require authorized services. |
| Per-buyer watermarks | Escrow gives every buyer the same build. Uploading one asset per buyer isn't practical. Traceability comes from Tebex/Cfx purchase records instead. |

---

## 7. Residual risks (stated honestly)

1. **The NUI (HTML/CSS/JS) can be copied.** Design and branding can be imitated; there's no logic to steal. Mitigation: legal terms, fast iteration.
2. **Client Lua can be dumped** from players' machines. Mitigation: a thin client; without the server half it does nothing.
3. **Escrow may be exploited again** in the future. Mitigation: Cfx patches, re-encryption, enforcement; nothing in our design depends on client secrets.
4. **One purchase runs on all of a buyer's servers** (same Cfx account). Mitigation: commercial tiers and subscriptions.
5. **Buyers can edit config, locales, themes and hooks** by design. Changing *behaviour* beyond those hooks isn't possible without the encrypted core.
6. **Policy changes:** Cfx/Rockstar can change the rules. Re-check the release rules and PLA before each major release.

---

## 8. Decision record

| # | Decision |
|---|---|
| P1 | Cfx Asset Escrow + Tebex is the only protection and activation mechanism. |
| P2 | Revocable licensing = Tebex subscription packages; hand-picked activation = Tebex manual payments. |
| P3 | No custom licensing, remote checks, remote code or obfuscation, ever. The release build fails if such patterns appear. |
| P4 | Keep the architecture server-authoritative so client/NUI exposure has no business value. |
| P5 | Any future vendor backend is an optional data service, never a condition for the resource to run. |
