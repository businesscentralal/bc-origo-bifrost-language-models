# AppSource offer: Bifrost Language Models

Everything to enter in Partner Center for this offer, page by page, as Microsoft's offer pages ask
for it (Business Central offer, checked 06.10.2026). Built from the app's main branch and the
documentation. No message type names, as on the public site. Review before publishing.

## Files in this folder

| File | Use | Partner Center page |
|---|---|---|
| `logo-216.png` | Large logo, PNG, in the style of Bifrost Foundation's | Offer listing › Logos |
| `screenshots/*.png` | 3 screenshots, 1280 × 720 PNG (3 to 5 required) | Offer listing › Screenshots |
| `description.html` | Description with the allowed HTML tags | Offer listing › Description |
| `description.txt` | The same as plain text | (for review) |
| `product-sheet.pdf` | One-page marketing sheet (1 to 3 PDFs required) | Offer listing › Supporting documents |

## 1. Offer setup

| Field | Value |
|---|---|
| Offer alias | Bifrost Language Models |
| Customer leads / listing option | Same as Bifrost Foundation |

## 2. Properties

| Field | Value | Subcategories |
|---|---|---|
| Primary category | AI Apps and Agents | Agents, Tools & Connectors |
| Secondary category | Productivity | Workflow Automation |
| Industry | (leave empty: not industry-specific) | |
| App version | The version of the `.app` you upload (the pipeline sets it) | |
| Terms and conditions (URL) | https://docs.bifrost.origo.is/en-us/licensing/eula/ | |

## 3. Offer listing

| Field | Value | Length / limit |
|---|---|---|
| Name | Bifrost Language Models | 23 / 200 |
| Search results summary | Your choice of AI model in Business Central: for routines, and a chat on the card you have open. | 96 / 100 |
| Description | `description.html` | 2055 / 5,000 |
| Search keywords | Language model, Copilot, AI automation | 3 / 3 |
| Products your app works with | Dynamics 365 Business Central, Microsoft Copilot | 2 / 3 |
| Help link | https://docs.bifrost.origo.is/en-us/apps/ | must differ from Support URL |
| Privacy policy link | https://docs.bifrost.origo.is/en-us/licensing/privacy/ | |
| Support contact (name, e-mail, phone, URL) | Same as Bifrost Foundation; Support URL https://www.origo.is/ | not shown to customers |
| Engineering contact | Same as Bifrost Foundation | not shown to customers |
| Supporting documents | `product-sheet.pdf` | 1 to 3 PDFs |
| Logo | `logo-216.png` | PNG |
| Screenshots | see below | 3 to 5, 1280 × 720 PNG |
| Videos | optional; none yet | up to 4 |

Links use the documentation's own domain, docs.bifrost.origo.is. The app has no page of its own on the
site yet, so the help link goes to the app list; change it to the app's page once that is published.
The app's `app.json` still points to the old github.io address, which GitHub forwards to the new domain.

Microsoft's logo guidance says no text on the logo; Bifrost Foundation's logo has text, so this one
follows Foundation for a consistent family.

### Screenshots and captions

| File | Caption |
|---|---|
| `screenshots/01-models.png` | Choose your AI provider: Copilot, OpenAI, Azure OpenAI, Anthropic, Google Gemini, xAI or your own. |
| `screenshots/02-setup.png` | One setup page for models, API keys and the tools a model may use. |
| `screenshots/03-model-card.png` | Each model has its own provider and settings; Copilot needs no API key. |

Taken in the Bifrost sandbox (CRONUS demo company, demo data), 06.10.2026. The company name, user
names, e-mail addresses and IDs were replaced before capture.

## 4. Availability

Markets: the same as Bifrost Foundation.

## 5. Technical configuration

Upload the app's `.app` file from the release build. Dependency: Bifrost Foundation.

## 6. Supplemental content

| Field | Value |
|---|---|
| Supported editions | Essentials and Premium |
| Key usage scenario, test accounts, test app | No longer used in validation (Microsoft); leave empty unless Partner Center requires it |

## Description (as in `description.txt`)

```
Your choice of AI model, inside Business Central's own routines and cards.

Bifrost Language Models lets Business Central itself use a language model: in automated routines, and in a chat panel on the cards where it helps to ask about the record in front of you. It is an add-on to Bifrost Foundation. To work with Business Central from the assistant you already use, such as Copilot, ChatGPT or Claude, Bifrost Foundation is all you need.

Who it is for
Administrators who want to choose which AI provider Business Central uses, teams whose routines need a model to read, classify or summarise, and users who want a quick question answered on the card they are working on.

What it does
- Lets you choose the provider: Microsoft Copilot (no API key needed), OpenAI, Azure OpenAI, Anthropic, Google Gemini, xAI or your own model.
- Puts a model inside a routine: a scheduled task or playbook can ask a model to classify or summarise a document.
- Adds a context-aware chat panel on the cards where it helps: customers, vendors, items, sales and purchase documents, ledger entries and incoming documents. It already knows which record you have open.
- Answers from live figures: the model reads Business Central through Bifrost, with your own permissions, and every call is logged.

Requirements and pricing
- Microsoft Dynamics 365 Business Central 28.0 or later, Essentials or Premium.
- Bifrost Foundation, available separately on AppSource.
- For Microsoft Copilot: Copilot turned on in Business Central. For other providers: an API key from that provider.
- For prices, contact Origo (https://www.origo.is/) or your Business Central partner.
- If you are a partner, contact The App Channel (https://www.theappchannel.com/).

Bifrost Language Models does not replace Business Central or its extensions. It makes their data and business logic available to the people, routines and AI platforms your organisation already uses.
```

---
Drafted with the help of Claude (Anthropic); review before publishing. Origo's AI policy (STE-0002):
the person who publishes is responsible for the content.
