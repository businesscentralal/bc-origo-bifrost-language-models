# Listing - Bifrost Language Models (en-US)

## Offer identity

| Field | Value |
| --- | --- |
| Offer name | Bifrost Language Models |
| App name (app.json) | Bifrost Language Models |
| App id | `f1722684-0c24-4022-a2e0-0f63154aca76` |
| Publisher | Origo (same publisher as Bifrost Foundation) |
| Version | The current version in `app/app.json` (set at release) |
| Required app | Bifrost Foundation 28.0.1.0 or later (`7505e808-6e52-4b96-a328-82573391297a`) |
| Product id | _to be filled in by the Origo publisher account owner once the offer exists_ |

## Short summary (max 100 characters)

```
Chat with Business Central using OpenAI, Anthropic, Gemini, xAI, Azure OpenAI or Copilot.
```

## Description (basic HTML; Partner Center does not render Markdown, max 3000 characters including markup)

```html
<p>Bifrost Language Models connects Bifrost to the language model of your choice. Users chat with Business Central from the page they are working on, and the assistant answers from their own data under their own permissions.</p>
<p>This app builds on Bifrost Foundation, which supplies the chat itself and the MCP Tool Server that lets the assistant read and act on Business Central data. Bifrost Language Models supplies the language models behind it.</p>
<p><b>What you get</b></p>
<ul>
<li><b>Language models.</b> Set up one language model per row: chat provider, endpoint, model, limits (timeout, maximum tokens, context size) and a skill text that becomes part of the system instruction.</li>
<li><b>Seven chat providers.</b> Copilot, OpenAI, Azure OpenAI, Custom LLM, Anthropic, xAI and Google (Gemini), behind one provider interface.</li>
<li><b>Chat on 36 standard pages.</b> The Bifrost Chat FactBox is added to the customer, vendor, item, sales, purchase, ledger entry and incoming document pages.</li>
<li><b>A language model per user.</b> Administrators assign a language model to each user in Bifrost User Setup. Bifrost Chat is shown only to users who have one.</li>
<li><b>One-shot completions.</b> The LLM.Prompt.Complete message type sends a prompt to the configured model and returns the text, for playbooks and scheduled tasks.</li>
</ul>
<p><b>Keys and permissions</b></p>
<ul>
<li>The app never stores an API key itself. Keys are kept in Foundation's secret store and passed as secret text all the way into the HTTP request header.</li>
<li>Each user can set a personal API key, which takes precedence over the shared key. Managing the shared company key is a separate permission (BIFROST ChatSvc ori), so it can be delegated without granting chat access.</li>
<li>Tool calls run under the signed-in user's own Business Central permissions.</li>
</ul>
<p><b>Requirements</b></p>
<ul>
<li>Business Central online (SaaS), version 28.</li>
<li>Bifrost Foundation 28.0.1.0 or later.</li>
<li>An account and API key with the chosen provider (not needed for Copilot). Enable <b>Allow HttpClient Requests</b> for the app in Extension Management; every external provider needs it.</li>
</ul>
```

## Search keywords (Partner Center accepts up to 3; extra candidates below)

1. Bifrost
2. chat
3. language model

Other candidates: AI, LLM, OpenAI, Anthropic, Gemini, Copilot, assistant.

## Categories

- Primary: Productivity (confirm the exact name in the Partner Center category list)
- Secondary: pick the AI or chat category the offer form suggests, if it offers one.

## Supported languages and markets

- Languages: English (en-US), Icelandic (is-IS). Matches `supportedLocales` in `app.json`.
- Markets: the same markets as Bifrost Foundation. The app is built for the W1 localization.

## Links

| Field | URL |
| --- | --- |
| Website | https://docs.bifrost.origo.is |
| Help | https://docs.bifrost.origo.is/en-us/language-models/ |
| Privacy policy | https://docs.bifrost.origo.is/en-us/licensing/privacy/ |
| Terms of use / EULA | https://docs.bifrost.origo.is/en-us/licensing/eula/ |
| Support | https://www.origo.is/ |

Note: Foundation's `app.json` points at `docs.bifrost.origo.is` for privacy and EULA. This app's `app.json` still points at `businesscentralal.github.io/bifrost/en-us/foundation/privacy/` and `.../eula/`. The listing uses Foundation's URLs; align `app.json` (including its `help` links) in a follow-up if the publisher account owner agrees.

## Screenshots (descriptions only; images still to be captured)

1. **Language model list** - the Bifrost Language Models list with several providers.
2. **Language model card** - provider, endpoint, model, limits and skill text, with the shared and personal API key actions.
3. **Setup page** - the Bifrost Language Models setup page showing the number of models, the default model and how many still need an API key.
4. **Chat on a customer card** - the Bifrost Chat FactBox answering a question about the current customer.
5. **Chat on a sales order list** - the FactBox on a list page.
6. **User setup** - the Language Model Code field in Bifrost User Setup.
