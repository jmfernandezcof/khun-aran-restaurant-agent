# Khun Aran — AI reservation agent for a resort restaurant

Khun Aran is a multilingual concierge (Spanish, English, Thai) for **Flames**, a fine-dining
restaurant concept on a Koh Samui resort. Guests chat with it on the web or by voice. It checks
availability, books and modifies tables, suggests dishes, and hands the conversation to staff when
it should.

**Live demo:** https://demo-talay.nomadprompters.es

> This is a portfolio demo built by [Nomad Prompters](https://nomadprompters.es). It is a sanitized
> snapshot of a private repository. Secrets, operational notes and commit history have been removed.

## What it does

- **Reservations end to end:** checks real availability, creates, modifies and cancels bookings,
  and emails a confirmation with a booking code.
- **Menu-aware answers:** looks up dishes, set menus and drinks from the database instead of
  improvising. It handles allergies, vegan diners and special occasions.
- **Human in the loop:** when a guest needs a person, it opens a case. The staff group on Telegram
  gets an alert with a "Lo atiendo" (I'll take it) button, plus reminders if nobody claims it.
- **Voice input:** browser audio is transcribed server-side and answered like a typed message.
- **Local context:** live weather from the Thai Meteorological Department.
- **Privacy by design:** PDPA consent is recorded before a booking, personal data is purged after a
  retention period, and per-session and per-address abuse limits apply.

## Architecture

```
Browser ──► Nginx (static site + reverse proxy, injects a server-side auth header)
              ├─ POST /chat    ──► n8n agent workflow (Claude) ──► tools:
              │                       check availability · create / modify / cancel reservation
              │                       find dishes · send confirmation · request human
              ├─ POST /voice   ──► n8n ──► speech-to-text ──► same agent
              └─ GET  /weather ──► n8n ──► TMD weather API
                                    │
                         PostgreSQL (reservations, menu, consent, cases, chat memory)
                                    │
                         Telegram staff bot (claim cases, reminders)
```

- The browser never sees a credential. Nginx adds the auth header and talks to n8n over the
  internal Docker network.
- Business rules live in SQL (`migrations/`), not in the prompt. Availability, phone
  normalization, booking codes, abuse limits and data retention are database functions the agent
  calls, so it cannot make them up.
- The agent's output is checked before it reaches the guest (`data/output-check/`). A reply that
  claims a booking the database does not back up is blocked.

## Repository layout

| Path | Contents |
|---|---|
| `deploy/` | Production frontend (`web/`) and Nginx config |
| `n8n-workflows/` | Exported tool workflows (credentials are referenced by name, never included) and the scripts that create them |
| `migrations/` | PostgreSQL schema and business logic, applied in order |
| `data/` | SQL and JS used by the workflows: menu, reservations, email, human handoff, output checks, load-test seeds |
| `scripts/regression/` | Regression harness: replays conversations and measures tone and token usage |
| `docs/` | Human handoff design, the prompt test battery, regression cases and design notes for future features |

## Testing

The agent is tested against real conversation scenarios (`docs/prompt-test-battery.md`,
`docs/regression-cases.md`) with a replay harness in `scripts/regression/`. Load tests use
fictitious phone numbers from ranges reserved for fiction, so they never reach a real person.

## Stack

n8n · Claude (Anthropic) · OpenAI speech-to-text · PostgreSQL · Nginx · Docker · Traefik ·
Cloudflare · Telegram Bot API · Gmail

## License

© Nomad Prompters. All rights reserved. Shared for portfolio review only.
