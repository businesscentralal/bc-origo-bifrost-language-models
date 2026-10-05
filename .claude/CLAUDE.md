# Extension: Bifrost Language Models

## Prefix
(none - objects use raw names with the mandatory `ori` suffix inside the `Origo.Bifrost.LanguageModels` namespace)

## Namespace
Origo.Bifrost.LanguageModels (tests: Origo.Bifrost.LanguageModels.Test)

Every file that touches a Bifrost Foundation object also declares `using Origo.Bifrost;`.

## Object ID Range
App:   10035335-10035484 (see `origo_cloudevents_object_ranges.xlsx`)
Tests: 96000-96199

## Target BC Version
28.x (application/platform 28.0.0.0, runtime 17.0)

## Source Control
Platform: GitHub
Organization: businesscentralal
Repository: bc-origo-bifrost-language-models
Default branch: main

## Dependencies
- Bifrost Foundation **28.0.1.0** or later in `app/app.json` and `test/app.json` (`7505e808-6e52-4b96-a328-82573391297a`): the first Foundation version with `Setup ori.TryClaimChatProvider` public again (core#881). AL-Go probes the latest core CI build (`.AL-Go/settings.json`: `release_status` `latestBuild`, `version` `latest`).

## Naming Rules
- Every object carries the `ori` suffix (AppSource mandatory affix) and is at most 30 characters.
- Permission set object names are at most 20 characters (`BIFROST LLM ori`, `BIFROST LLM Rd ori`, `BIFROST LLM Chat ori`, `BIFROST ChatSvc ori`). `BIFROST Chat ori` is Foundation's chat gate set, not this app's.
- The brand name "Bifrost" lives in the namespace, the app name and user-facing captions - never as an object-name prefix. Exception: the chat feature is a product name, "Bifrost Chat" (objects `Bifrost Chat ... ori`, folder `app/src/BifrostChat`, Icelandic "Spjalla við Bifröst").
- The chat "role" concept is the **Language Model**: table `Bifrost Language Model ori`, sub-objects `Bifrost LangModel ... ori` (Card, List, Prov., Provider, None, Test Ctx - `LangModel` keeps them within 30 characters), User Setup field `Bifrost Language Model Code`, Icelandic "mállíkan". The JSON request key `roleCode` stays (API contract).
- "MCP Tool Server" keeps its protocol name (Model Context Protocol).
- Icelandic captions use "Bifröst".

## What Bifrost Language Models extends in Bifrost Foundation
Foundation owns the extension points; Bifrost Language Models supplies the values. Never ask for a change in Foundation
that Bifrost Language Models can make itself through an extension object.

| Foundation object | Bifrost Language Models extension |
| --- | --- |
| enum `Message Type ori` | `LangModel Message Type ori` - value `LLM.Prompt.Complete` |
| enum `Request Log Type ori` | `LangModel Req Log Type ori` - values `Copilot` and `LLM` + maskers |
| table `User Setup ori` | `User Setup LangModel ori` - field `Bifrost Language Model Code` |
| page `User Setup Editor ori` | `User Setup Editor LangMdl ori` - field + Bifrost Chat FactBox |
| page `Setup ori` | `Setup LangModel ori` - **one** action `LangModelSetup` (opens `LangModel Setup ori`) + actionref in `Category_Apps` |
| codeunit `Secret Store ori` | `LangModel Secrets ori` - registers and resolves the language model API keys |
| codeunit `App Registry ori` | `LangModel Registration ori` - one `OnRegisterApps` subscriber, no other code |

Foundation's `Help WhoAmI Get Impl ori` is `Access = Internal` and cannot be called from Bifrost Language Models.
Use `Bifrost Chat Utils ori.GetIdentityJson()`, which runs the public `Help.WhoAmI.Get` message type
through `Msg Interface ori` instead.

## Chat Providers
Six external providers (Copilot is native to Bifrost Language Models) live under `app/src/Providers/<Provider>/`, registered
as values on the base enum `Bifrost LangModel Prov. ori` (2-7): `OpenAI LangModel Prov. ori`,
`Azure OAI LangModel Prov. ori`, `Custom LLM LangModel Prov. ori`, `Anthropic LangModel Prov. ori`
(+ `Anthropic LangModel Proxy ori` for its own Messages API), `xAI LangModel Prov. ori`,
`Gemini LangModel Prov. ori`. They were migrated from the standalone *Origo Cloud Events Chat* app
(businesscentralal/origo-bc-cloudevents-chat), which Bifrost Language Models replaces - see CHANGELOG 28.0.0.0 for the
rename table. The install take-over from that app was removed in #27 (no data to take over).
Shared infrastructure lives in `app/src/Providers/Shared/`: `LangModel Prov. Base ori`,
`LangModel API Client ori`, `LangModel Chat Proxy ori`, `LangModel Turn Guard ori` (the rules of one chat turn, #40),
table `Chat Svc Gate ori` (shared-key permission gate, permission set `BIFROST ChatSvc ori`), `LLM Req Log Masker ori`.
Each provider answers `GetDefaultContextTokens` (32,000 Custom LLM, 128,000 OpenAI/Azure OpenAI/xAI/Gemini,
200,000 Anthropic, 0 Copilot/None); `Bifrost Language Model ori.GetContextTokens()` returns `Context Tokens` or that default.

### Object ids (re-derived 05.10.2026 from `main` and open PRs)
- App, in use: 10035335, 10035337-10035340, 10035342-10035382, 10035384-10035396, 10035398-10035407,
  10035409-10035419, 10035421-10035423, **10035425** `LangModel Turn Guard ori` (#40). Enumextension 10035384
  `LangModel Chat Provider Type` shares its number with codeunit 10035384 (object ids are per type).
- App, claimed by PR #50: codeunit **10035408** `LangModel Field Restrict ori` (#49).
- App, free (reusable, codeunits/pages): 10035336, 10035341, 10035383, 10035397, 10035420, 10035424 and 10035426-10035484.
  10035336 (table `Chat Gate ori`, moved to Foundation) and 10035420/10035424 (take-over codeunits, #27) stay free
  for their own object type only; never reuse a freed table id.
- `Bifrost Language Model ori` field numbers in use: 1, 2, 10-12, 20-26 (26 `Context Tokens`, #40). Next free: 27.
- `Bifrost Chat Argument ori` field numbers in use: 1, 2, 10-16 (16 `Context Tokens`), 40, 50-53. Next free below 40: 17.
- Tests, in use: 96000-96003, 96009-96019 (96017 `Copilot Upgrade Tests`, 96018 `Copilot Install Tests`, 96019
  `LLM Prompt Contract Tests`), enumextension 96000 `Mock Bifrost LangModel Prov.`, enumextension **96020**
  `Mock Chat Provider Type`, codeunit **96021** `Mock Chat Provider`, codeunit **96022** `LangModel Turn Guard Tests`.
  Claimed by PR #50: **96004** `LangModel Field Restrict Tests`. Free: 96005-96008, 96023-96199.

## Setup Page and Secrets (Bifrost Foundation platform rules)

- **Setup**: `Setup LangModel ori` (pageextension 10035403) contains **only** `addlast(Apps)` with the
  `LangModelSetup` action and `addlast(Category_Apps)` with its actionref - no fields, no other groups, no
  trigger. Everything else lives on `LangModel Setup ori` (page 10035421, help slug `language-models-setup`), which
  shows the language models, the MCP tool count and the missing API keys and opens **Bifrost App Secrets**
  filtered to Bifrost Language Models.
- **Setup notifications**: this app raises **none**, anywhere. Across the Bifröst family setup
  notifications live only on Bifrost Foundation's `Setup ori` page ("Bifrost Setup") and their only
  action is "Start setup wizard". Bifrost Language Models makes itself known instead: codeunit
  `LangModel Registration ori` (10035423) holds a single `OnRegisterApps` subscriber on Foundation's
  public `App Registry ori` and calls `AddApp` with its own module id, its name and
  `Page::"LangModel Setup ori"`. Foundation reads the HTTP status and the missing-credential counts
  from the registry itself. Never add a `Notification.Send()` for missing setup, a missing API key or
  a blocked HttpClient to this app - extend the registration instead.
- **Secrets**: Bifrost Language Models never touches IsolatedStorage. `LangModel Secrets ori` (codeunit 10035422) wraps
  Foundation's `Secret Store ori`. Codes per language model:

  | Secret code | Scope | Purpose |
  | --- | --- | --- |
  | `LANGMODEL-<Code>-API-KEY` | `Company` | shared key for the whole company |
  | `LANGMODEL-<Code>-USER-API-KEY` | `"Company And User"` | personal key of one user |

  `<Code>` is the uppercased language model code. The longest possible secret code is 43 characters
  (10 + `Code[20]` + 13), so a model code is never truncated.
- Both codes are registered on insert and rename of a language model, and from
  `Copilot Install ori.OnInstallAppPerCompany` / `Copilot Upgrade ori.OnUpgradePerCompany` for every
  existing model. `Register` is idempotent. `OnDelete` clears both values.
- Reads go through `LangModel Secrets ori.TryGetApiKey` (personal key first, then shared, both with
  `MarkUsed`). Values are `SecretText` all the way into the HTTP header - `SecretText.Unwrap()` is
  `OnPrem`-scoped and must never be used here. The chat control add-in's `apiKey` config property is a
  non-secret marker (`Bifrost Chat Argument ori.GetApiKeyIndicator()`); the JavaScript only tests it for
  truthiness and routes every request back through AL.
- Secret **values never migrate** between extensions. Administrators re-enter the shared key once per
  language model and users re-enter their personal key once. Renaming a model leaves the old
  registration rows behind with no value - `Secret Store ori` has no unregister operation.

## Documentation

Documentation lives in businesscentralal/bifrost (site bifrost.origo.is); no Help/ or docs/ folders in
this repo - deviation from the Origo PR gateway check 8 approved by the user 2026-09-06.

- Product documentation: https://businesscentralal.github.io/bifrost/en-us/language-models/ (`docs/language-models/` in the site repository)
- In-product help: https://businesscentralal.github.io/bifrost/en-us/help/language-models/ (`help/language-models/`)
- `app.json` points at those URLs through `help` and `contextSensitiveHelpUrl`; `ContextSensitiveHelpPage`
  on every page and page extension carries the Docusaurus slug (`language-models-setup`,
  `bifrost-chat`, `bifrost-lang-model-card`, `bifrost-lang-model-list`), not an HTML file name. When you add a page,
  add the matching `help/language-models/<slug>.md` in the site repository - and its Icelandic translation under
  `i18n/is-IS/docusaurus-plugin-content-docs-help-language-models/current/`. `tools/Test-HelpLinks.ps1` checks it.
- Until the app is published on the site, its pages wait in `businesscentralal/bifrost-support` under `scratchpad/`
  (same paths); keep them current with every user-visible change.

## Development Standards

This project follows the **Origo BC Development Standards** (https://github.com/OrigoSoftwareSolutions/bc-dev-standards).

Before writing any AL code, load the relevant skills:
- **`origo-bc-al-coding-standards`** - namespaces, XML docs, naming, formatting, performance, enums, Format/Evaluate, events, error handling, JSON, security
- **`origo-bc-test-writer`** - test structure, AAA pattern, coverage checklists, mock patterns
- **`origo-bc-documentation-writer`** - XML doc comments, markdown reference docs, help codeunits, sync rules

Key rules always in effect:
- Namespace on line 1 of every file
- XML documentation on every object and non-local procedure
- Bilingual captions (`Comment = 'is-IS=...'`) on all user-facing text
- `SetLoadFields` on all record reads
- `Format(guid, 0, 4)` for GUIDs, `Format(value, 0, 9)` / `Evaluate(var, text, 9)` for culture-invariant serialization
- Never use `Format()` / `Evaluate()` on enum values - use `.Names()`, `.Ordinals()`, `.AsInteger()`, `.FromInteger()`
- One statement per line, no `WITH`
- Implementation = code + tests + documentation (help codeunit, markdown docs, HTML help)

## Development Environment
- One COSMO Alpaca container (Gunnar, 05.10.2026: only bc28-w1 is needed now): `launch: bc28-w1` (W1 CRONUS
  International Ltd.) in `app/.vscode/launch.json` (git-ignored, the authority for the instance id). Publish and
  run the unit tests there with `-LaunchConfiguration 'launch: bc28-w1'`.
- Compile locally with alc.exe + CodeCop/UICop/AppSourceCop, zero errors and zero warnings. After a caption change
  run `tools/Update-IcelandicXlf.ps1` and compile again; before a PR run every guard in `tools/` (the *Source Guards*
  workflow runs all but `Test-IcelandicXlfInSync`, which needs a build).
  Symbols: `app/.alpackages` (Microsoft symbols + a Foundation 28.0.1.x `.app`),
  `test/.alpackages` (Microsoft test libraries + Foundation + the freshly built Bifrost Language Models app).
- Publish and test without VS Code (pwsh 7, credential from the user-level env vars `BC28IS_USER` /
  `BC28IS_PASSWORD`, never from files) with the Foundation tooling:
  `bc-origo-bifrost-core/tools/Publish-BifrostApp.ps1 -AppFile <.app>` (ForceSync for the app,
  Synchronize for the test app) and `bc-origo-bifrost-core/tools/Run-BifrostTests.ps1
  -TestAppJson test/app.json -ResultsFile TestResults/langmodels_is.xml`.
- The AL test runner drives a web client session on a shared container. When other agents publish to the
  same container at the same time the run can return an empty result file (`Codeunits: 1  Tests:` with no
  numbers). Cause: the Command Line Test Tool returns no tests on the first visit of a suite name that does not
  exist yet. `Run-BifrostTests.ps1` now visits the suite before running; if you pass your own `-TestSuite`, run twice
  or reuse an existing name. Never switch to a fresh name to "retry" - that reproduces the empty run.

## Message Type Conventions
- Bifrost Language Models owns exactly one message type, `LLM.Prompt.Complete`, registered on Foundation's `Message Type ori`
  enum by `LangModel Message Type ori`. `LLM Prompt Compl Impl ori` implements `Msg Interface ori`, `Msg Discovery ori`
  and `Msg Contract ori`; its contract chapters are its help (no help codeunit, no message-type page on the site).
- Errors are returned as `status = Error` through the coded `Argument.RespondWithError(code, message, parameter,
  received, expected, nextStep)`; never an uncoded text and never an unhandled exception. The errors chapter uses the
  same labels as the live answers. Texts a caller reads are translated (not `Locked`).

## Test App Rules
- **The test app uses Bifröst Foundation's public API only.** Bifrost Language Models - Tests is not listed in
  Foundation's `app.json` `internalsVisibleTo` and must never be added back. A test that needs a
  message type executed runs it through the public `Dispatcher ori` (`Execute` for a lightweight
  dispatch, `EnqueueAndProcess` when the persisted queue row is needed); the dispatcher marks the
  call licensed itself, so the internal `SetLicensed` is never needed. An Impl may still be called
  directly on a temporary `Message Argument ori` when that Impl does not call `AssertIsLicensed`.

## Testing Through the MCP Server
- `describe_message_type` and `invoke_message_type` on the `origo-bc-bc28-w1` server hit Bifrost Language Models through
  Foundation's route (`origo/bifrost/v1.0`). Keep calls serial - parallel bursts crash the server.
  Test data uses the `BIFT-<letter>` prefix.
