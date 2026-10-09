# Bifrost Language Models

**App name:** Bifrost Language Models (display form *Bifröst mállíkön*)  
**Publisher:** Origo — **Version:** 28.0.0.0 (AL-Go stamps build and revision) — **Target:** Cloud (BC 28, runtime 17.0)  
**App ID:** `f1722684-0c24-4022-a2e0-0f63154aca76` — **Test app ID:** `9c452c6e-df9b-4eb0-9a54-7ea8f32483ec`  
**Object ID range:** 10035335–10035484 (tests 96000–96199) — **Namespace:** `Origo.Bifrost.LanguageModels`  
**Depends on:** Bifrost Foundation 28.0.1.0 or later  
**Environments:** Business Central online (SaaS) and the COSMO Alpaca development container `bc28-w1` (CRONUS International Ltd.)

---

## Overview

Bifrost Language Models connects Bifröst to language models. Bifrost Foundation owns the chat itself: the
Bifrost Chat control add-in, the FactBox and Focus pages, `Bifrost Chat Mgt ori`, the chat permission gate and
the MCP Tool Server that lets the assistant read and act on Business Central data under the signed-in user's
own permissions. This app supplies what Foundation leaves open:

- **Language models**: one `Bifrost Language Model ori` row per model, with its chat provider, endpoint, limits
  (including its context size) and skill text.
- **Seven chat providers**: Copilot, OpenAI, Azure OpenAI, Custom LLM, Anthropic, xAI and Google (Gemini),
  behind one provider interface.
- **The chat provider of Bifröst**: `LangModel Chat Provider ori` implements Foundation's `Chat Provider ori`
  and is registered on Foundation's `Chat Provider Type ori` enum. Install and upgrade claim it through
  Foundation's `Setup ori.TryClaimChatProvider` while no other app holds it.
- **The chat on 36 standard pages**: page extensions put Foundation's Bifrost Chat FactBox on the customer,
  vendor, item, sales, purchase, ledger entry and incoming document pages.
- **`LLM.Prompt.Complete`**: a one-shot completion message type for playbooks and scheduled tasks.

The app never stores an API key itself. Every key lives in Foundation's secret store under this app's id,
addressed by a secret code per language model, and is passed as `SecretText` all the way into the HTTP header.

---

## Functional Flow

1. **Create a language model.** An administrator opens **Bifröst mállíkön Setup** (`LangModel Setup ori`)
   from the *Apps* group on the Bifröst Setup page, goes to the language model list and creates a
   `Bifrost Language Model ori` row: a code, a description, the chat provider, the endpoint (`Base URL`,
   `Model`, `Chat Path`, `Models Path`), the limits (`Timeout Seconds`, `Max Tokens`, `Context Tokens`) and
   the skill text that becomes part of the system instruction.
2. **Store the API key.** On `Bifrost LangModel Card ori` the actions **Set Shared API Key** and
   **Set Personal API Key** write the key through `LangModel Secrets ori` into Foundation's secret store. The
   card only shows the read-only *Shared Key Stored* / *Personal Key Stored* flags. The shared-key actions
   are gated by `BIFROST ChatSvc ori`.
3. **Assign the model to a user.** `User Setup Editor LangMdl ori` adds **Language Model Code** to the
   General group of the Bifröst user setup. Bifrost Chat is shown only to users with a code.
4. **Chat from a record page.** Foundation's FactBox passes the current record to the control add-in and
   calls this app's chat provider, which runs the provider's tool loop against Foundation's MCP Tool Server.
5. **Call it without a UI.** `LLM.Prompt.Complete` sends a prompt (and an optional system prompt) to the
   configured provider and returns the text, with no tools and no conversation state.

### One chat turn

- **History budget.** Each request carries as much earlier conversation as the model's context allows:
  (`Context Tokens` − `Max Tokens` − the tool definitions) × 3.5 characters, less a 10 % margin.
  `Context Tokens` 0 uses the provider default: 32,000 for Custom LLM, 128,000 for OpenAI, Azure OpenAI, xAI
  and Gemini, 200,000 for Anthropic. Foundation's `TrimMessageHistory` keeps the current question; this app then
  removes tool messages whose partner was trimmed away (`LangModel Turn Guard ori`).
- **Figures need a tool.** When a final reply states figures (four or more digits, or a number with a
  separator) and no tool was called in the turn, the model is asked once to verify them with a tool or say it
  cannot. At most one follow-up per turn.
- **The user's own prompt once.** Foundation's `Bootstrap` carries the user's prompt under
  `USER INSTRUCTIONS:`; the providers do not add it again.
- **Copilot** keeps the whole turn in its history (`SetHistoryLength(100)`), so a turn with several tool
  calls does not lose the question.

---

## Setup & Configuration

| Step | Where | What |
| --- | --- | --- |
| 1 | Extension Management | Enable **Allow HttpClient Requests** for Bifrost Language Models. Every external provider needs it; the **Bifrost Setup** page shows a notification with **Start setup wizard** when it is off for any installed Bifröst app. |
| 2 | **Bifröst Setup** → *Apps* → **Bifröst mállíkön** | Open `LangModel Setup ori` (page 10035421), the single place this module is configured. It reports the number of language models, the default one, the MCP tool count and how many models still need an API key. |
| 3 | `Bifrost LangModel List ori` / `Bifrost LangModel Card ori` | Create one row per language model and fill in the provider and endpoint fields. |
| 4 | `Bifrost LangModel Card ori` actions | **Set / Clear Shared API Key** (needs `BIFROST ChatSvc ori`) and **Set / Clear Personal API Key**. Both use Foundation's masked dialog. **Test Connection** shows the provider's answer. |
| 5 | Bifröst User Setup | Assign a language model to each user in **Language Model Code**. |

`Bifrost Language Model ori` (table 10035335) fields:

| Field | Purpose |
| --- | --- |
| `Code` | The model code. It is also the `roleCode` of `LLM.Prompt.Complete` and the `<Code>` part of the secret codes. |
| `Description` | Free text shown in lists and lookups. |
| `Skill` | Markdown blob added to the system instruction for this model. |
| `Default` | Used by `LLM.Prompt.Complete` when neither a role code nor a user language model is given. Not used by Bifrost Chat. |
| `Chat Provider` | Selects the `Bifrost LangModel Provider ori` implementation. |
| `Base URL`, `Chat Path`, `Models Path` | Endpoint of the external provider. Generic `Data.Records.Set` cannot write them (the API key is sent there); only the card and the setup page can. |
| `Model` | The provider's model identifier. |
| `Timeout Seconds`, `Max Tokens` | Request limits. |
| `Context Tokens` | The model's context size in tokens; sets the history budget of a chat request. 0 uses the provider default. |

Permissions:

| Set | Grants |
| --- | --- |
| `BIFROST LLM ori` | Full access to the module, but not write access to Foundation's `Chat Gate ori`. |
| `BIFROST LLM Rd ori` | Read-only access to language models. |
| `BIFROST LLM Chat ori` | Execute on every provider codeunit other than Copilot, and the language model secrets. Assign it with Foundation's `BIFROST Chat ori` (the chat gate). |
| `BIFROST ChatSvc ori` | View, set and clear the shared (service) API key. Assigned separately, so "manage the company key" can be delegated without granting chat. |

API keys do not migrate between extensions. An administrator enters the shared key once per model, and each
user enters their personal key once.

---

## Objects

Objects retain their existing published names and IDs. New objects require the ` ori` affix. The free IDs are listed in `.claude/CLAUDE.md`.

### Tables

| ID | Name | Purpose |
| --- | --- | --- |
| 10035335 | `Bifrost Language Model ori` | One row per language model: provider, endpoint, limits, context size and the skill markdown. |
| 10035337 | `Bifrost Chat Argument ori` | Temporary DTO of the single-procedure provider interface (inputs, outputs, `Procedure Type`). |
| 10035406 | `Chat Svc Gate ori` | Permission gate for the shared (service) API key. Stores no rows. |

### Table extension

| ID | Name | Extends | Purpose |
| --- | --- | --- | --- |
| 10035401 | `User Setup LangModel ori` | `User Setup ori` (Foundation) | Adds the per-user field **Language Model Code**. |

### Pages

| ID | Name | Purpose |
| --- | --- | --- |
| 10035342 | `Bifrost Chat Model List ori` | Lookup for picking one of the models the provider reports. |
| 10035343 | `Bifrost LangModel Card ori` | Edits one language model, its skill markdown and its API-key actions. |
| 10035344 | `Bifrost LangModel List ori` | Lists language models. Its explicit Copilot initialization action asks for confirmation through `Copilot Install ori` (10035390); declining leaves models unchanged. |
| 10035421 | `LangModel Setup ori` | The module's own setup page, the only place it is configured. |

### Page extensions

| ID | Name | Extends | Purpose |
| --- | --- | --- | --- |
| 10035346–10035381 | `Bifrost Chat <Page> ori` (36) | Customer Card/List, Vendor Card/List, Item Card/List; the sales and purchase quotes, orders, invoices, credit memos and return orders with their list pages; Bank Account, Customer, Detailed Customer, Vendor, Item, Value, VAT and G/L entries; Incoming Document and Incoming Documents | Card and entry pages add Foundation's `Bifrost Chat FactBox ori` and feed the current record to it. The 14 list actions open Foundation's chat focus through `LangModel Chat Provider ori` (10035382), forwarding the original table, SystemId and caption in the current session. Both surfaces are shown only when `Bifrost Chat Mgt ori.ShowBifrostChat()` is true. All carry `ContextSensitiveHelpPage = 'bifrost-chat'`. |
| 10035402 | `User Setup Editor LangMdl ori` | `User Setup Editor ori` (Foundation) | Adds the language model field and the chat FactBox to the Bifröst user setup editor. |
| 10035403 | `Setup LangModel ori` | `Setup ori` (Foundation) | Adds exactly one *Apps* action opening `LangModel Setup ori`, plus its actionref in `Category_Apps`. |

### Enums and interface

| ID | Name | Purpose |
| --- | --- | --- |
| 10035338 | `Bifrost Chat Proc. Type ori` | Names the operation to run on the provider interface, so new operations need no new interface method. |
| 10035339 | `Bifrost LangModel Prov. ori` | Selects the provider implementation of a language model. Extensible. |
| — | `Bifrost LangModel Provider ori` (interface) | Single-procedure contract for every chat provider; `Bifrost Chat Proc. Type ori` on the argument record names the operation. |

### Enum extensions

| ID | Name | Extends | Purpose |
| --- | --- | --- | --- |
| 10035340 | `Copilot Capability ori` | `Copilot Capability` (Microsoft) | Registers the Bifrost Chat capability with the Copilot framework. |
| 10035384 | `LangModel Chat Provider Type` | `Chat Provider Type ori` (Foundation) | Adds `LanguageModels`, implemented by `LangModel Chat Provider ori`. |
| 10035399 | `LangModel Message Type ori` | `Message Type ori` (Foundation) | Adds `LLM.Prompt.Complete`. |
| 10035400 | `LangModel Req Log Type ori` | `Request Log Type ori` (Foundation) | Adds the `Copilot` and `LLM` request log types with their maskers. |

### Codeunits

| ID | Name | Purpose |
| --- | --- | --- |
| 10035382 | `LangModel Chat Provider ori` | Foundation's `Chat Provider ori` for this app: resolves the user's language model and builds the argument (including the effective context size). |
| 10035384 | `Bifrost LangModel Test Ctx ori` | SingleInstance side channel that hands the card's record context to a provider's TestConnection. |
| 10035385 | `Copilot LangModel Prov. ori` | Copilot provider: System.AI managed resources, no key and no external endpoint. |
| 10035389 | `Bifrost LangModel None ori` | Default no-op provider. |
| 10035390 | `Copilot Install ori` | Copilot capability per database; per company the secret registration and the chat provider claim. |
| 10035391 | `Copilot Upgrade ori` | Repeats the capability and secret registration and the chat provider claim after an upgrade. |
| 10035392 | `Copilot AOAI Func Impl ori` | Implements `AOAI Function` so MCP tools can be registered with Copilot dynamically. |
| 10035393 | `Copilot Chat Proxy ori` | Copilot tool loop against Azure OpenAI through System.AI. |
| 10035394 | `Copilot Req Log Masker ori` | Masker for Copilot request log entries; logging happens only in debug mode. |
| 10035395 | `Copilot Default Skill ori` | The default skill text of the Copilot language model. |
| 10035396 | `LLM Prompt Compl Impl ori` | `LLM.Prompt.Complete`: one-shot completion, coded errors, contract chapters. |
| 10035409 | `LLM Req Log Masker ori` | Strips API keys from logged LLM requests and redacts bodies outside debug mode. |
| 10035410 | `LangModel Prov. Base ori` | Shared helpers: config resolution, service-key permission check, token-usage parsing, multi-modal messages. |
| 10035411 | `LangModel API Client ori` | HTTP client for the OpenAI-compatible providers with a caller-supplied auth header. |
| 10035412 | `LangModel Chat Proxy ori` | The OpenAI-compatible tool loop (Chat Completions and Responses) against Foundation's MCP Tool Server. |
| 10035413 | `OpenAI LangModel Prov. ori` | OpenAI provider (Bearer token). |
| 10035414 | `Azure OAI LangModel Prov. ori` | Azure OpenAI provider (`api-key` header, deployment-specific chat and models paths). |
| 10035415 | `Custom LLM LangModel Prov. ori` | Self-hosted OpenAI-compatible provider (`x-api-key`): Ollama, vLLM and similar. |
| 10035416 | `Anthropic LangModel Prov. ori` | Anthropic (Claude) provider (`x-api-key` plus `anthropic-version`). |
| 10035417 | `Anthropic LangModel Proxy ori` | Anthropic tool loop over the Messages API. |
| 10035418 | `xAI LangModel Prov. ori` | xAI (Grok): chat completions for text, the Responses API for files. |
| 10035419 | `Gemini LangModel Prov. ori` | Google Gemini: OpenAI-compatible chat, native `generateContent` for files, `x-goog-api-key` header. |
| 10035422 | `LangModel Secrets ori` | This app's facade over Foundation's `Secret Store ori`; owns the `LANGMODEL-*` secret codes. |
| 10035423 | `LangModel Registration ori` | One `OnRegisterApps` subscriber that registers this app and its setup page with Foundation's `App Registry ori`. |
| 10035425 | `LangModel Turn Guard ori` | The rules of one chat turn: history budget, orphaned tool messages, the figures follow-up. |

### Permission sets

| ID | Name | Purpose |
| --- | --- | --- |
| 10035398 | `BIFROST LLM Chat ori` | Provider execute and secrets. Assign with Foundation's `BIFROST Chat ori`. |
| 10035404 | `BIFROST LLM ori` | Full access to the module. |
| 10035405 | `BIFROST LLM Rd ori` | Read-only access to language models. |
| 10035407 | `BIFROST ChatSvc ori` | The shared (service) API key gate. |

---

## Dependencies

| App | ID | Purpose |
| --- | --- | --- |
| Bifrost Foundation | `7505e808-6e52-4b96-a328-82573391297a` | 28.0.1.0 or later: the message-type kernel, the chat (control add-in, FactBox, `Bifrost Chat Mgt ori`, MCP Tool Server, chat gate), the secret store, the request log, `User Setup ori`, `Setup ori` and its public `TryClaimChatProvider`. |

`app.json` declares no other dependency and `internalsVisibleTo` only the test app *Bifrost Language Models -
Tests* (stripped from Default builds by `.AL-Go/PipelineInitialize.ps1`). It suppresses **AA0215** and **AS0081**
only.

---

## Documentation

All public documentation lives in [businesscentralal/bifrost](https://github.com/businesscentralal/bifrost) and is
published at <https://businesscentralal.github.io/bifrost>, in English and Icelandic. There are no `docs/` or
`Help/` folders in this repository (an approved deviation from Origo PR gateway check 8).

| What | Where |
| --- | --- |
| Product documentation | <https://businesscentralal.github.io/bifrost/en-us/language-models/> |
| In-product help (en-US and is-IS) | <https://businesscentralal.github.io/bifrost/en-us/help/language-models/> |
| Release notes | [CHANGELOG.md](CHANGELOG.md) |

The contract of `LLM.Prompt.Complete` is served by the app at runtime through `Help.Implementation.Get`.

### Context-Sensitive Help

`app.json` declares `contextSensitiveHelpUrl` = `https://businesscentralal.github.io/bifrost/{0}/help/language-models/`
and `supportedLocales` `["en-US", "is-IS"]`, so every help page must exist in both locales on the site. Pages carry
the Docusaurus **slug**. `tools/Test-HelpLinks.ps1` (workflow *Help Links*) checks them against the site.

| Slug | Pages that use it |
| --- | --- |
| `bifrost-chat` | The 36 `Bifrost Chat <Page> ori` page extensions |
| `bifrost-lang-model-card` | `Bifrost LangModel Card ori` |
| `bifrost-lang-model-list` | `Bifrost LangModel List ori` |
| `language-models-setup` | `LangModel Setup ori` |

When you add a page, add `help/language-models/<slug>.md` in the site repository together with its Icelandic
translation under `i18n/is-IS/docusaurus-plugin-content-docs-help-language-models/current/`.

---

## Repository layout

| Folder | Content |
| --- | --- |
| `app/` | The AppSource app (`Bifrost Language Models`) |
| `app/src/BifrostChat/` | The chat provider, page extensions and the `LanguageModel/`, `Copilot/` and `Message Types/` folders |
| `app/src/Extensions/` | Extensions of Bifrost Foundation objects (enums, table, pages) |
| `app/src/Providers/Shared/` | `LangModel Prov. Base ori`, `LangModel API Client ori`, `LangModel Chat Proxy ori`, `LangModel Turn Guard ori`, `Chat Svc Gate ori`, `LLM Req Log Masker ori` |
| `app/src/Providers/OpenAI/`, `AzureOpenAI/`, `CustomLLM/`, `Anthropic/`, `xAI/`, `Gemini/` | The six external chat providers |
| `app/src/Setup/` | `LangModel Setup ori`, `LangModel Secrets ori`, `LangModel Registration ori` |
| `app/src/Permission Set/` | `BIFROST LLM ori`, `BIFROST LLM Rd ori`, `BIFROST LLM Chat ori`, `BIFROST ChatSvc ori` |
| `app/Translations/` | Icelandic translation (`Bifrost Language Models.is-IS.xlf`, built by `tools/Update-IcelandicXlf.ps1`) |
| `test/` | Test app (`Bifrost Language Models - Tests`, object range 96000–96199) |
| `test/reports/` | Internal test reports, not published |
| `tools/` | Source guards and the Icelandic xlf builder (the same scripts Bifrost Foundation uses), and `Set-TestLanguageModels.ps1`, which sets up one language model per provider with its key from a local secret store and runs a chat turn against each |
| `.AL-Go/`, `.github/` | AL-Go for GitHub / COSMO Alpaca pipeline configuration and the *Source Guards* and *Help Links* workflows |

---

## Development

- Open `al.code-workspace` in VS Code.
- Development container: COSMO Alpaca `bc28-w1` (CRONUS International Ltd.), defined in
  `app/.vscode/launch.json`, which is git-ignored and the authority for the instance id. Publish and run the unit
  tests there with `-LaunchConfiguration 'launch: bc28-w1'`.
- Compile locally with `alc.exe` plus CodeCop, UICop and AppSourceCop. Zero errors and zero warnings beyond the
  suppressions in `app.json` is the bar. Symbols live in `app/.alpackages` (Microsoft symbols plus the current
  Bifrost Foundation `.app`); test symbols in `test/.alpackages`.

  ```
  alc.exe /project:app /packagecachepath:app/.alpackages /out:app/output/languagemodels.app ^
          /analyzer:<CodeCop.dll> /analyzer:<UICop.dll> /analyzer:<AppSourceCop.dll>
  ```

- After changing captions: compile, run `tools/Update-IcelandicXlf.ps1`, compile again. Before a PR run the
  guards in `tools/` (CI runs all but the xlf check): `Test-IcelandicXlfInSync`, `Test-MixedLanguageLabels`,
  `Test-PermissionCoverage`, `Test-ContractParameterKeys`, `Test-NoObsolete`, `Test-NoClientCallstack`,
  `Test-ValidatedTableView`, `Test-IcelandicKeywordCounts`, and `Test-HelpLinks -DocsPath <bifrost checkout>`.
- Publish and run the tests without VS Code (pwsh 7, credential from the user-level env vars `BC28IS_USER` /
  `BC28IS_PASSWORD`, never from files): `bc-origo-bifrost-core/tools/Publish-BifrostApp.ps1 -AppFile <.app>`
  and `bc-origo-bifrost-core/tools/Run-BifrostTests.ps1 -TestAppJson test/app.json`.
- Command-line `alc` does not raise AS0011 (mandatory affix); AL-Go CI is the gate, so check the ` ori` suffix
  yourself before pushing.
- Standards: [Origo BC Development Standards](https://github.com/OrigoSoftwareSolutions/bc-dev-standards).
  Project rules are in `.claude/CLAUDE.md`.

---

© 2026 Origo ehf.

<!-- AUTO-UPDATE-START -->
# COSMO Alpaca AL-Go AppSource App Template

[![Use this template](https://github.com/microsoft/AL-Go/assets/10775043/ca1ecc85-2fd3-4ab5-a866-bd2e7e80259d)](https://github.com/new?template_name=Alpaca-AppSource-Template&template_owner=cosmoconsult)

This template repository can be used for managing AppSource Apps for Business Central.

It is a customized version of the [AL-Go-AppSource](https://github.com/microsoft/AL-Go-AppSource) template and is designed to be used with [COSMO Alpaca](https://cosmoconsult.com/cosmo-alpaca).

> [!NOTE]
> If you created this repository using the GitHub web UI (for example by clicking **Use this template** on GitHub.com) instead of creating it from the COSMO Alpaca VS Code extension, you must initialize it using the [COSMO Alpaca VS Code extension](https://marketplace.visualstudio.com/items?itemName=cosmoconsult.cosmo-alpaca).  To do this, simply right-click on the repository in VS Code and select _Initialize_.

Please go to https://aka.ms/AL-Go and [COSMO Docs](https://docs.cosmoconsult.com/en-us/cloud-service/alpaca) to learn more.
<!-- AUTO-UPDATE-END -->
