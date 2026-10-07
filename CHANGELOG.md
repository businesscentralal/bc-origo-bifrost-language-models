# Changelog

All notable changes to Bifrost Language Models are documented here.

## [Unreleased]

### Fixed (2026-10-05) - The chat failed whenever an API key had not been used yet that day

- `LangModel Secrets ori.TryGetApiKey` stamped the key as used on Bifrost App Secrets (a write, once a day per key) before the provider call. Foundation's `Bootstrap` then runs message types through `Codeunit.Run`, which the platform refuses in an open write transaction, so the first chat of the day failed with *An error occurred and the transaction is stopped*, and the rolled-back stamp made every later attempt fail the same way. `TryGetApiKey` now only reads; the new `MarkApiKeyUsed` stamps the key after the provider call (chat send and continue, `LLM.Prompt.Complete`). Found by the live chat test through `Test.LanguageModel.Chat` on bc28-is.

### Fixed (2026-10-05) - Reasoning models refused tool calls (Azure OpenAI, OpenAI)

- A reasoning model such as Azure OpenAI `gpt-6-sol` answers 400 *Function tools with reasoning_effort are not supported ... set reasoning_effort to 'none'* when a chat request carries tools. The OpenAI-compatible chat proxy now resends such a request once with `reasoning_effort: "none"`; a model that does not know the parameter never receives it. Verified live on Azure OpenAI (`/openai/v1/chat/completions`, `gpt-6-sol`): two tool rounds and the right answer.
- `LangModel Secrets Tests`: `TryGetApiKey` stamps nothing, `MarkApiKeyUsed` stamps the key that was used.

### Fixed (2026-10-05) - Google Gemini chat refused by Google

- The Gemini provider sent `extra_body.google.generation_config` with every chat request; Google's OpenAI-compatible endpoint refuses it (*Unknown name "generation_config"*), so no Gemini chat worked. The field is no longer sent; a chat model answers in text without it. Verified live with `gemini-3.8-flash`: two tool rounds and the right answer.

### Added (2026-10-05) - Test message types to set up language models and test the chat of every provider

- Test app only, refused in SaaS production: **Test.LanguageModel.Set** creates or updates language models (provider, endpoint, model, limits, Context Tokens, default, skill) and stores their shared or personal API keys; the request is redacted in the queue before a key is stored and no key is ever answered. **Test.LanguageModel.Delete** deletes them with their keys. **Test.LanguageModel.Chat** runs one Bifrost Chat turn against a chosen model through the same path as the chat add-in (`LangModel Chat Provider ori`, tool calls through Foundation's MCP Tool Server, `ContinueWithToolResults`) and answers the reply, the tool rounds and the tools called.
- `tools/Set-TestLanguageModels.ps1` sets the models up from a JSON file outside every repository (default `%USERPROFILE%\.bifrost\test-language-models.json`) and resolves each API key on the local machine from the PowerShell SecretManagement vault or a user-level environment variable, then posts straight to the container's task API; `-Chat` runs one turn against every model, `-Remove` deletes them.
- Test objects: enumextension 96023 `LangModel Test MsgType` (values 96023-96025), codeunits 96024 `Test LangModel Set Impl`, 96025 `Test LangModel Delete Impl`, 96026 `Test LangModel Chat Impl`, 96027 `LangModel Test Tools`, test codeunit 96028 `LangModel Test Tools Tests`.

### Changed (2026-10-05) - Aligned with Bifrost Foundation 28.0.1

- The Bifrost Foundation dependency floor in `app/app.json` and `test/app.json` is **28.0.1.0**, the first Foundation version with `Setup ori.TryClaimChatProvider` public again (core#881).
- Every table and page declares `Extensible`: `Bifrost Language Model ori`, `Bifrost Chat Argument ori`, `Chat Svc Gate ori`, `Bifrost LangModel Card ori`, `Bifrost LangModel List ori`, `Bifrost Chat Model List ori` and `LangModel Setup ori` are `Extensible = false` (no other app extends them; they can be opened later).
- `tools/` carries Foundation's source guards (`Test-PermissionCoverage`, `Test-MixedLanguageLabels`, `Test-IcelandicXlfInSync`, `Test-IcelandicKeywordCounts`, `Test-ContractParameterKeys`, `Test-NoObsolete`, `Test-NoClientCallstack`, `Test-ValidatedTableView`, `Test-HelpLinks`) and `Update-IcelandicXlf.ps1`. New workflows *Source Guards* and *Help Links* run them on pull requests. The Icelandic xlf is rebuilt with the script.
- Google Gemini: the "invalid response" error detail is translated instead of an English literal inside an Icelandic sentence.
- Removed the unused `LangModel Prov. Base ori.AssertServiceGate` and `HasServiceGate`, the last uncoded error answer in the app.
- README, AGENTS.md and `.claude/CLAUDE.md` describe the app as it is: the chat UI, chat gate and MCP Tool Server are Foundation's, help lives under `help/language-models/`, and the object-id registry is re-derived.

### Changed (2026-10-05) - The chat provider claim goes through Foundation (#34, #35)

- `Copilot Install ori.ClaimChatProvider` calls Foundation's `Setup ori.TryClaimChatProvider(LanguageModels)`, which carries its own inherent permissions (core#122, core#251, core#881). An install or upgrade under restricted permissions now **claims** the chat provider instead of skipping. The claim still happens only while `Chat Provider Type` is None or already Language Models; another app or an administrator's choice is never overridden.
- `Copilot Upgrade ori.OnUpgradePerCompany` also claims, so a tenant whose install skipped the claim is finished by the next upgrade.
- The local `ReadPermission` / `WritePermission` probe and telemetry event **ORI-BIF-0422** are gone; remove any alert on that event.
- Tests: `Copilot Install Tests` (96018) `ClaimChatProvider_WithoutSetupPermission_Claims`, `_WhenAnotherProviderHolds_LeavesItUnchanged`, `_WhenNone_ClaimsLanguageModels`, `_Twice_IsIdempotent`, `_MissingSetupRow_CreatesAndClaims`; new `Copilot Upgrade Tests` (96017). Test-only `Mock Chat Provider Type` (enumextension 96020) and `Mock Chat Provider` (codeunit 96021) stand for another app holding the claim.

### Fixed (2026-10-05) - Bifrost Chat keeps the question and checks figures (#40)

- New field **Context Tokens** on `Bifrost Language Model ori` (field 26, on the card next to Max Tokens): the model's context size. 0 uses the provider default (32,000 Custom LLM; 128,000 OpenAI, Azure OpenAI, xAI and Gemini; 200,000 Anthropic), answered by each provider through `GetDefaultContextTokens` (the never-read `GetContextWindowChars` procedure type is renamed).
- The history budget of each chat request is (context − Max Tokens − tool definitions) × 3.5 characters, less a 10 % margin, instead of the fixed 80,000 (Chat Completions) and 160,000 (Anthropic) characters. The Responses path, which did not trim at all, uses the same budget.
- After the trim, tool messages whose partner was removed are dropped on the Chat Completions and Responses paths, so no request starts with an orphaned tool message.
- When a final reply states figures (four or more digits, or a number with a separator) and no tool was called in the turn, the model is asked once to verify them with a tool or say it cannot. At most one follow-up per turn, on every provider including Copilot.
- The user's own prompt is sent once: Foundation's `Bootstrap` carries it under `USER INSTRUCTIONS:` (core#157), so the providers no longer append it again.
- Copilot keeps the whole turn in its history (`SetHistoryLength(100)` instead of the platform default of 10 messages), so a turn with several tool calls keeps the question.
- New codeunit `LangModel Turn Guard ori` (10035425); tests `LangModel Turn Guard Tests` (96022) and `Bifrost Language Model Tests` (96003) `GetContextTokens_*`.

### Fixed (2026-10-05) - LLM.Prompt.Complete answers coded errors (#32)

- Every error answer carries Foundation's structure (`code`, `parameter`, `received`, `expected`, `nextStep`): PermissionDenied for a caller without `BIFROST Chat ori`, MissingParameter on `prompt`, RecordNotFound on `roleCode` (a code longer than 20 characters is no longer cut and matched), PreconditionFailed when no usable language model is set up and when the provider fails.
- The errors chapter of the contract uses the same labels as the live answers and names both permission sets: Foundation's `BIFROST Chat ori`, and `BIFROST LLM Chat ori` for a language model whose provider is not Copilot.
- Tests: `LLM Prompt Contract Tests` (96019) `Contract_NamesBothPermissionSets`, `Execute_MissingPrompt_IsCodedMissingParameter`, `Execute_UnknownRoleCode_IsCodedRecordNotFound`, `Execute_RoleCodeLongerThanACode_IsRecordNotFoundNotCut`.
### Security (2026-10-05) - generic data API field restrictions (#49, core#344)

- `Data.Records.Set` refuses to set the endpoint fields on `Bifrost Language Model ori` (Base URL 20, Chat Path 24, Models Path 25), also with force. Each row's endpoint is the address the provider API key is sent to, so a generic-write caller could otherwise redirect that key to a server of their choice. New `LangModel Field Restrict ori` (10035408) subscribes to Foundation's `OnAfterIsFieldWriteRestrictedForDataRecords` and `OnGetDedicatedMessageTypeHintForField`; the refusal's nextStep names the Bifrost Language Model card and the Bifrost Language Models setup page. Reading the fields, and the card, list, setup page and install code (which fill them directly), are unchanged.
- Tests: `LangModel Field Restrict Tests` (96004) read the field flags through the public `Help.Fields.Get` message type (#51), since Foundation keeps `IsFieldWriteRestrictedForDataRecords` and `IsFieldReadRestrictedForDataRecords` internal.

### Changed (2026-10-04) - CI/CD builds only main; every pull request gets a Pull Request Build

- Build policy only, no app change. `CI/CD` runs on pushes to `main` only, and `Pull Request Build` runs for pull requests into any branch. `.github/AL-Go-Settings.json` sets `CICDPushBranches` to `main` and `CICDPullRequestBranches` to `**`, so Update AL-Go System Files keeps the triggers.

### Removed (2026-10-01) - markdown help procedure (#46)

- `LLM Prompt Compl Impl ori` drops `GetMessageHelpAsMarkdownDocument`, the empty compatibility shim. Foundation removed the procedure from `Msg Interface ori` (core#198); the help of `LLM.Prompt.Complete` is its contract chapters, unchanged.
- The test that checked the empty shim is removed.
- Bifrost Foundation dependency raised to 28.0.0.186, the first Foundation build without the procedure, in `app/app.json` and `test/app.json`.

### Changed (2026-09-29) - Message contract for LLM.Prompt.Complete (#45)

- `LLM.Prompt.Complete` now exposes Foundation message contract chapters for its envelope, parameters, response, errors, effect, examples, overview and notes.
- Added bilingual discovery keywords and a selection description that distinguishes one-shot completion from interactive Bifrost Chat.
- Removed the per-type Markdown help codeunit; the legacy Foundation help procedure remains as an empty compatibility shim until the removal issue is completed.
- Added contract and discovery tests and released object id 10035397.
- The Bifrost Foundation dependency floor in `app/app.json` and `test/app.json` is raised to `28.0.0.166`, the first Foundation build that contains the message contract APIs.

### Changed (2026-09-29) - Language Model Code moves to the General group on User Setup (#42)

- On the Bifrost User Setup card, Language Model Code is shown in General, after Foundation's Charge Type and Session Source Approval Type, instead of at the end of Linked Records.
- The Bifrost Foundation dependency floor in `app/app.json` and `test/app.json` is raised to `28.0.0.152`, the first Foundation build with the User Setup `group(General)` anchor.

### Changed

- Bifrost Chat is only shown to users with a Language Model Code. Users who relied on the Default language model for chat no longer see Bifrost Chat until a Language Model Code is set on their Bifrost User Setup. To assign a code to many users at once, import a configuration package for User Setup ori that fills in "Bifrost Language Model Code".

### Changed (2026-09-25) - build against the latest Foundation CI build

- `.AL-Go/settings.json` `appDependencyProbingPaths` for bc-origo-bifrost-core sets `version` to `latest`. `release_status` stays `latestBuild`. AL-Go GetArtifacts matches a specific version exactly; only `latest` uses the last successful CICD run.
- The app builds against that latest Foundation CI build. The Foundation dependency floor is `28.0.0.0` in `app/app.json` and `test/app.json`.
- `fullBuildPatterns` lists `.AL-Go/settings.json`, so a settings-only change runs the full Build (Default) and Build (Test) instead of being skipped by incremental builds.
### Security

- Default (release) builds no longer ship the test app's internalsVisibleTo grant; the strip moved to PipelineInitialize.ps1 because Alpaca never ran PreCompileApp.ps1 (core#129).

### Fixed (2026-09-25) - install claim skips when Setup ori is not permitted (core#122)

- **`Copilot Install ori.ClaimChatProvider`**, called from `OnInstallAppPerCompany`, no longer reads Foundation `Setup ori` unless `ReadPermission` and `WritePermission` both succeed. Publishing Foundation re-ran this install in a context with no TableData Read on `Setup ori` (id 10077901), and `GetRecordOnce` failed the deploy (OrigoSoftwareSolutions/bc-origo-bifrost-core#122). The claim is skipped instead; an existing chat provider is left unchanged.
- **Admin signal**: each skip branch logs telemetry event `ORI-BIF-0422` (Warning, `tableId` 10077901 and `deniedPermission` Read or Write). `Chat Provider Type` then stays None, and nothing retries the claim automatically, so an administrator has to set it.
- **Test**: `Copilot Install Tests` (96018) `ClaimChatProvider_WithoutSetupPermission_SkipsWithoutError` — restrictive permissions (`Library - Lower Permissions`, O365 Basic + `BIFROST LLM ori`) skip without error; `ClaimChatProvider_WhenNone_ClaimsLanguageModels` covers the permitted path.

### Fixed (2026-09-25) - main build AL0132 on GetRequestDebugMode

- CI/CD run [36117014819](https://github.com/businesscentralal/bc-origo-bifrost-language-models/actions/runs/36117014819) on `aec4d53` failed both builds with AL0132: `Record "Setup ori"` does not contain `GetRequestDebugMode` (LangModelAPIClient, LangModelChatProvider, CopilotChatProxy, AnthropicLangModelProxy, GeminiLangModelProv).
- Cause: `.AL-Go/settings.json` `appDependencyProbingPaths` for bc-origo-bifrost-core pinned `version: 1.0.0.102`, which predates `GetRequestDebugMode` (added in core build 1.0.0.124).
- Fix: probing version raised to `1.0.0.132`, the core build live on the Bifrost sandbox as Foundation 28.0.0.132 (includes core#107 and core#114). App/test app.json unchanged.

## [28.0.0.0] - 2026-09-07

### Changed (2026-09-20)

- Docs: renamed MCP tool references `get_message_type_help` → `describe_message_type` in `.claude/CLAUDE.md` and `README.md`, matching the Foundation tool rename in core#64.

### Changed (2026-09-15) - permission-tolerant legacy Chat Providers take-over probe (#8)

- **`Chat Providers Install ori`** gains `TryProbeTakeOverPermissions` / `TryRunTakeOverAtInstall`
  mirroring Foundation core#43 / treasury#14: probe `ReadPermission` on legacy
  `CE Chat Service Gate ori` (10035495) when Table Metadata exists; first denial skips the
  whole take-over with one telemetry event (`ORI-BIF-0421`), never `Error`. Probe-then-direct
  copy (no nested `Codeunit.Run` during `OnInstallAppPerCompany`). No Access Control role
  pairs are moved by this take-over.
- **`Chat Takeover State ori`** (10035424) — SingleInstance probe-denial / last-skip seam for
  unit tests. A1: telemetry-only pending (no setup table).
- **`Copilot Install ori`** calls `TryRunTakeOverAtInstall` instead of bare
  `TakeOverChatProviderData`.
- **Tests**: `Chat Takeover Probe Tests` (96017) AC01/AC02/AC03; probe-denial seam +
  `TestPermissions = Disabled` (standing HARD — no `Test No Source Read`).

### Changed (2026-09-15) - OB-2 Chat Host → Chat Provider rename (#16 amend)

- Renamed Foundation contract consumption to match Bifrost Foundation OB-2 tip
  (`e447a3e` / `bc-origo-bifrost-core#58`): interface `Chat Provider ori`, enum
  `Chat Provider Type ori`, field `Setup ori`.`Chat Provider Type`.
- Object renames (IDs unchanged): `LangModel Chat Host ori` → `LangModel Chat Provider ori`
  (10035382); enumextension `LangModel Chat Host Provider` → `LangModel Chat Provider Type`
  (10035384); tests `LangModel Chat Host Tests` → `LangModel Chat Provider Tests` (96002).
- `Copilot Install ori.ClaimChatHost` → `ClaimChatProvider`.
- Fixed undeclared `ChatHost` identifier in LangModel Chat Provider Tests (use declared
  `ChatProvider` consistently).
- Dropped inaccessible Foundation `Internal` objects from LM permission sets (`Chat Gate ori`,
  `MCP Tool Executor ori`) so the app compiles against tip `e447a3e` (gate stays on Foundation's
  `BIFROST Chat ori`).
- Renamed LM permission set 10035398 `BIFROST Chat ori` → **`BIFROST LLM Chat ori`** to avoid
  colliding with Foundation's Chat Gate set of the same name (publish blocker).

### Changed (2026-09-15) - Consume Foundation's chat provider + MCP Tool Server (#7)

- Deleted this app's copies of the control add-in, FactBox/Focus pages, `Bifrost Chat Mgt ori`,
  `Bifrost Chat Transfer ori`, `Chat Gate ori`, `MCP Tool Server ori`, `MCP Tool Executor ori` and
  `Bifrost Chat Utils ori` — all now owned by Bifrost Foundation (companion:
  `OrigoSoftwareSolutions/bc-origo-bifrost-core#21`).
- Added **`LangModel Chat Provider ori`** (object 10035382, reusing the old `Bifrost Chat Mgt ori`
  slot), implementing Foundation's new `Chat Provider ori` interface. It keeps all the
  language-model-specific behaviour: role resolution (`Bifrost Language Model Code` on User Setup,
  the default language model), the `Bifrost LangModel Provider ori` provider dispatch, and secret
  handling — unchanged from before the move.
- Added **`LangModel Chat Provider Type`** (enum extension 10035384), registering `LanguageModels`
  on Foundation's `Chat Provider Type ori` enum.
- **`Copilot Install ori.ClaimChatProvider`** sets Foundation's `Setup ori`.`Chat Provider Type` to
  `LanguageModels` on `OnInstallAppPerCompany`, but only while it is still `None`, so install never
  overrides another app or an administrator that already claimed chat.
- `LLM Prompt Compl Impl ori` now calls Foundation's `Bifrost Chat Mgt ori.HasChatPermission()` for
  the permission gate and this app's own `LangModel Chat Provider ori.GetLangModelProviderWithModel`
  for role resolution.
- The 36 base-page extensions (Customer/Vendor/Item/Sales/Purchase/Entries/Incoming Documents)
  need **no code changes** — they still reference `Bifrost Chat FactBox ori`, `Chat Focus ori` and
  `Bifrost Chat Mgt ori` by name, now resolved against Foundation.
- **Dependency**: this app requires the Foundation release that ships #21 (interface
  `Chat Provider ori`, enum `Chat Provider Type ori`, field `Setup ori`.`Chat Provider Type`). Bump
  `app/app.json` / `test/app.json` Foundation dependency version once that release is cut.

### Fixed (2026-09-15) - Azure OpenAI CompletePrompt uses SetAzureChatPath / configured Chat Path (#11)

- **`Azure OAI LangModel Prov. ori.DoCompletePrompt`** built `ChatUrl` with an inline
  `StrSubstNo(ChatPathTok, Model, ApiVersionTok)`, so CompletePrompt always hit the default
  `deployments/%1/chat/completions` path and ignored a Chat Path configured on the language
  model. It now calls `SetAzureChatPath(Argument)` and appends `Argument."Chat Path"` — the
  same path resolution already used by `DoSendChatMessage` / `DoContinueWithToolResults`.
- **`SetAzureChatPath`** is no longer `local` (still `Access = Internal` on the codeunit) and
  carries a `///` XML doc, so tests can call it via `internalsVisibleTo`. Blank Chat Path
  still fills the default template; a configured template still substitutes Model (`%1`) and
  ApiVersionTok (`%2`).
- **Unit tests** in codeunit 96012 `LangModel Providers Tests`: blank default path, and `%1`/`%2`
  template substitution (no live HTTP).

### Fixed (2026-09-15) - system message must be first in the chat payload (#12)

- **`LangModel Chat Proxy ori`** assembled the payload messages first and then appended the system
  message, so every chat request went out as `[user, assistant, ..., system]`. Strict
  OpenAI-compatible gateways reject that with `System message must be at the beginning.`
  (observed against a LiteLLM proxy); lenient endpoints had been masking it. `AddSystemMessage`
  now prepends.
- **`Bifrost Chat Utils ori`** gains `HoistSystemMessages`, called at the top of `CallModelOnce` -
  the single point both `SendChatMessage` and `ContinueWithToolResults` pass through. Tool-call
  continuation rebuilds its array from saved conversation state rather than calling
  `AddSystemMessage`, so without it a conversation already in flight still failed on its second
  turn. The helper returns early unless a system message actually sits after a non-system one, so
  a correctly ordered payload is left untouched.
- Affected every provider routed through the shared proxy (Custom LLM, OpenAI, Azure OpenAI, xAI).
  The Responses path and the provider-local `DoCompletePrompt` methods already built system-first
  and are unchanged.
- **Unit tests** in codeunit 96005 `Bifrost Chat Utils Tests`: system-last is hoisted to the front;
  an already-ordered payload is unchanged; no-system, multiple-system (relative order preserved)
  and empty-array cases.

### Added (2026-09-07) - setup wizard action

- `LangModel Setup ori` gains a **Setup Wizard** action (promoted, `Category_Process`) that opens
  Bifrost Foundation's `Setup Wizard ori` (page 10077925), which enables HTTP client requests for
  all Bifröst apps and walks through the credentials of every app.

### Changed (2026-09-07) - setup notifications and wizard

Setup notifications now live on the **Bifrost Setup** page only, for every app in the Bifröst family,
and their only action is **Start setup wizard**. Bifrost Language Models no longer raises a setup
notification of its own anywhere - it makes itself known to Bifröst Foundation instead, and Foundation
aggregates the outstanding setup work of all installed Bifröst apps in one place.

- **Added** codeunit 10035423 `LangModel Registration ori` (`Access = Internal`): one subscriber to
  Foundation's public `App Registry ori.OnRegisterApps` that calls `AddApp` with this app's module id,
  its display name and `Page::"LangModel Setup ori"`. Foundation fills in the HTTP status and the
  registered/missing credential counts itself. Granted by `BIFROST LLM ori`.
- **Removed** the HttpClient notification from `LangModel Setup ori`: the `ShowHttpClientNotification`
  procedure, its call in `OnOpenPage`, the `HttpClientDisabledMsg` and `EnableHttpClientLbl` labels and
  the now-unused `System.Apps` / `System.Environment.Configuration` usings. The page still shows the
  language models, the MCP tool count and the missing API keys.
- **Removed** codeunit 10035408 `Chat Http Notif. Action ori` entirely - the notification action it
  carried was its only purpose and nothing else referenced it. Its grant is gone from `BIFROST Chat ori`
  and object id 10035408 is free again.
- **Tests**: new `LangModel Registration Tests` (96016) asserts that `App Registry ori.GetApps` lists
  Bifrost Language Models under the module id returned by `LangModel Secrets ori.GetAppId()` and points
  at `LangModel Setup ori`. `LangModel Setup Page Tests` no longer declares `NotificationHandler` on the
  two page tests - the page sends no notification any more, so a declared handler could never run.

### Changed (2026-09-07) - tests run on Foundation's public API

- The test app no longer depends on Bifröst Foundation's internals: Bifrost Language Models - Tests has been removed
  from Foundation's `internalsVisibleTo`, and the test suite compiles and runs against a Foundation
  package that does not grant it. No test code had to change - the suite never touched a Foundation
  internal.


First release. The chat module was moved out of **Bifrost Foundation** 28.0.0.0 into this separate AppSource app, installed side by side with Foundation and depending on it.

### Fixed (2026-09-07)

- **A failed Google Gemini connection test no longer fails silently.** `Gemini LangModel Prov. ori.DoGetAvailableModels` returned `false` without setting an error message when the model list call failed, so **Test Connection** on the language model card raised an empty error and the administrator saw nothing at all. The procedure now checks `IsSuccessStatusCode` and reports the provider's own error detail for a transport failure, a non-success status (a wrong API key), an unparseable body, a missing `models` key and an empty model list.
- **A failed connection test no longer pins the session to the tested language model.** `Bifrost LangModel Card ori` raised the error before calling `Bifrost LangModel Test Ctx ori.ClearLanguageModel()`, so the single-instance test context survived and every later chat in that session ran on the model whose test had just failed. The context is now cleared before the outcome is reported, and the failure message is wrapped in a new **Connection test failed. %1** label. The model lookup on the same page already cleared on both paths.

### Changed (2026-09-07)

- `BIFROST LLM ori` grants `codeunit "Chat Providers Install ori"`, matching the existing grants for `Copilot Install ori` and `Copilot Upgrade ori`.
- `BIFROST Chat ori` and `BIFROST ChatSvc ori` pair their `tabledata` grants with the object-level `table "Chat Gate ori" = X` and `table "Chat Svc Gate ori" = X`, the way both `BIFROST LLM ori` sets already do.
- `ReadIsolation = ReadUncommitted` on the read-only record probes that had none: `Bifrost Chat Mgt ori.ShowBifrostChat` (the hot path — it runs on every one of the 36 chat page extensions), `LangModel Prov. Base ori.HasServiceGate`, `LangModel Secrets ori.RegisterAll`, `LangModel Setup ori.RefreshStatus`, and the company scans on `Bifrost Chat FactBox ori` and `Chat Focus ori`. `SetLoadFields` added to the language model reads in `Bifrost Chat Mgt ori.GetLangModelProvider` and the `Default` uniqueness check on `Bifrost Language Model ori`.
- XML documentation added to the 25 public procedures that had none: the 16 large-text accessors on `Bifrost Chat Argument ori`, the 5 public procedures on `MCP Tool Server ori`, 3 on `Bifrost Chat Utils ori`, and the `Execute` method on interface `Bifrost LangModel Provider ori` — the last one matters because every provider's implementing `Execute` is deliberately undocumented and inherits the interface contract.
- Tests: new `LLM Req Log Masker Tests` (10 tests) covering debug-mode passthrough, redaction outside debug mode, error text surviving both modes, and `GetBaseUrl` stripping path and query. `LangModel Setup Page Tests.SetupOri_ExposesTheSingleLangModelAppsAction` no longer declares a `NotificationHandler` — the HttpClient notification moved to `LangModel Setup ori`, so opening `Setup ori` sends none and the declared handler could never run. **178 tests, all passing on both bc28-is and bc28-w1.**
- `README.md` rebuilt against the mandatory Origo template (Overview, Functional Flow, Benefits, Logic Flow, Setup &amp; Configuration, Example Scenario, Objects, Dependencies, Documentation), with all 90 objects listed and the context-sensitive help slugs documented.

### Renamed before release

The app was called **Bifrost Bragi** while it was being built. Bifröst apps are named after what they do, not after a Norse figure, so everything below was renamed before the first release. Nothing here has shipped, so there is no upgrade path to keep: no object id changed, and no message type, secret code or JSON key changed.

- App `Bifrost Bragi` -> **`Bifrost Language Models`** (Icelandic "Bifröst mállíkön"); test app `Bifrost Bragi - Tests` -> `Bifrost Language Models - Tests`.
- Namespace `Origo.Bifrost.Bragi` -> **`Origo.Bifrost.LanguageModels`** (tests `Origo.Bifrost.LanguageModels.Test`).
- Repository `businesscentralal/bc-origo-bifrost-bragi` -> `businesscentralal/bc-origo-bifrost-language-models`.
- Objects: `Bragi Setup ori` -> `LangModel Setup ori`, `Bragi Secrets ori` -> `LangModel Secrets ori`, `Bragi Message Type ori` -> `LangModel Message Type ori`, `Bragi Request Log Type ori` -> `LangModel Req Log Type ori`, `Setup Bragi ori` -> `Setup LangModel ori`, `User Setup Bragi ori` -> `User Setup LangModel ori`, `User Setup Editor Bragi ori` -> `User Setup Editor LangMdl ori`. Test objects: `Bragi Mock Get Msg Co` -> `LangModel Mock Get Msg Co`, `Bragi Mock Message Type` -> `LangModel Mock Message Type` (value `Bragi.Mock.Get` -> `LangModel.Mock.Get`), `Bragi Secrets Tests` -> `LangModel Secrets Tests`, `Bragi Setup Page Tests` -> `LangModel Setup Page Tests`.
- Permission sets: `BIFROST Bragi ori` -> **`BIFROST LLM ori`**, `BIFROST Bragi Rd ori` -> **`BIFROST LLM Rd ori`**. `BIFROST LangModel ori` / `BIFROST LangMdl Rd ori` would have been 21 and 22 characters; AL caps a permission set object name at 20, so the set uses the `LLM` stem that the app already uses for `LLM.Prompt.Complete`, `LLM Prompt Compl Impl ori` and `LLM Req Log Masker ori`. `BIFROST Chat ori` and `BIFROST ChatSvc ori` are unchanged.
- Icelandic captions that carried the old app name now read "Bifröst mállíkön" / "Bifröst mállíkana".
- The documentation site slug stays `bragi` for now (`help`, `contextSensitiveHelpUrl` and `ContextSensitiveHelpPage = 'bragi-setup'`); the folders in `businesscentralal/bifrost` are renamed in a separate change, and the app.json URLs follow then.

### Added

- **App identity**: `Bifrost Language Models` (new app id), test app `Bifrost Language Models - Tests`. Object range 10035335-10035484, test range 96000-96199. Namespace `Origo.Bifrost.LanguageModels` (tests `Origo.Bifrost.LanguageModels.Test`). Depends on Bifrost Foundation 28.0.0.0. Help published to <https://businesscentralal.github.io/bifrost>.
- **Bifrost Chat**: control add-in `Bifrost Chat ori` with its scripts and styles, `Bifrost Chat FactBox ori`, `Chat Focus ori`, `Bifrost Chat Model List ori`, `Bifrost Chat Mgt ori`, `Bifrost Chat Transfer ori`, `Bifrost Chat Argument ori`, `Bifrost Chat Proc. Type ori`, `Bifrost Chat Utils ori` and 36 page extensions `Bifrost Chat <Page> ori` that put the FactBox on the customer, vendor, item, sales, purchase, ledger entry and incoming document pages.
- **Language models**: table `Bifrost Language Model ori` with `Bifrost LangModel Card ori` / `Bifrost LangModel List ori`, provider enum `Bifrost LangModel Prov. ori`, provider interface `Bifrost LangModel Provider ori`, default implementation `Bifrost LangModel None ori` and `Bifrost LangModel Test Ctx ori`.
- **Copilot provider**: `Copilot LangModel Prov. ori`, `Copilot Chat Proxy ori`, `Copilot AOAI Func Impl ori`, `Copilot Req Log Masker ori`, `Copilot Default Skill ori`, `Copilot Capability ori` (enum extension on Microsoft's `Copilot Capability`), plus the install codeunit `Copilot Install ori` (Subtype = Install) that registers the capability and `Copilot Upgrade ori`.
- **MCP tool server**: `MCP Tool Server ori` and `MCP Tool Executor ori`, giving the assistant read and write access to Business Central under the signed-in user's own permissions.
- **Chat providers moved from Origo Cloud Events Chat**: the six external providers previously shipped in the standalone *Origo Cloud Events Chat* AppSource app (which Bifrost Language Models replaces) are now registered on `Bifrost LangModel Prov. ori` (values `OpenAI`, `Azure OpenAI`, `Custom LLM`, `Anthropic`, `xAI`, `Google`):
  - `OpenAI LangModel Prov. ori` (Bearer token), `Azure OAI LangModel Prov. ori` (`api-key` header, deployment-specific Chat/Models Path), `Custom LLM LangModel Prov. ori` (`x-api-key`, OpenAI-compatible self-hosted endpoints), `Anthropic LangModel Prov. ori` + `Anthropic LangModel Proxy ori` (own Messages API), `xAI LangModel Prov. ori` (Responses API for files), `Gemini LangModel Prov. ori` (OpenAI-compatible chat, native `generateContent` for files).
  - Shared infrastructure: `LangModel Prov. Base ori` (config resolution, HttpClient gate, multi-modal message building), `LangModel API Client ori` (HTTP + response parsing), `LangModel Chat Proxy ori` (the OpenAI-compatible agentic tool loop against `MCP Tool Server ori`).
  - Shared (service) API key gate: table `Chat Svc Gate ori` and permission set `BIFROST ChatSvc ori`, separate from `BIFROST Chat ori` so an administrator can delegate "manage the shared key" without granting general chat execute permission.
  - Request logging: value `LLM` added to `LangModel Req Log Type ori` (masker `LLM Req Log Masker ori`, redacts request/response bodies outside debug mode).
  - `Chat Http Notif. Action ori` and a new `OnOpenPage` trigger on `Setup LangModel ori` warn the administrator when HttpClient requests are not allowed for the extension - every external provider needs them.
  - Data take-over: `Chat Providers Install ori.TakeOverChatProviderData()`, called from `Copilot Install ori.OnInstallAppPerCompany`, copies rows from the legacy app's `CE Chat Service Gate ori` table (table 10035495, a permission-gate table that never held any rows) into `Chat Svc Gate ori` when the legacy app is still installed and the new table is empty.
  - Not migrated: the legacy Setup Wizard page and its registration codeunit (superseded by the Bifrost Language Model Card/List and User Setup Editor, which configure providers per language model rather than through a single wizard), and the unused `CE Chat Tool Runner ori` codeunit (dead code - no provider called it).
- **Message type** `LLM.Prompt.Complete`: `LLM Prompt Compl Impl ori` and `LLM Prompt Compl Help ori`.
- **Permission sets**: `BIFROST LLM ori` (full), `BIFROST LLM Rd ori` (read-only), the moved `BIFROST Chat ori` gate over table `Chat Gate ori` (now also grants execute on every chat provider codeunit), and `BIFROST ChatSvc ori` over table `Chat Svc Gate ori`. Neither Bifrost Language Models set grants write access to either gate - both stay explicit, separately assignable permissions.
- **Extensions of Bifrost Foundation** (Foundation removed these couplings in 28.0.0.0):
  - `LangModel Message Type ori` - adds `LLM.Prompt.Complete` to enum `Message Type ori`.
  - `LangModel Req Log Type ori` - adds `Copilot` to enum `Request Log Type ori`, with `Copilot Req Log Masker ori` as the masker.
  - `User Setup LangModel ori` - adds field `Bifrost Language Model Code` to table `User Setup ori`.
  - `User Setup Editor LangMdl ori` - adds the language model field and the Bifrost Chat FactBox to page `User Setup Editor ori`.
  - `Setup LangModel ori` - adds the single **Bifrost Language Models Setup** action (and its promoted actionref) to the **Apps** group of page `Setup ori`.
- **Test app**: 5 test codeunits with 116 tests (`Bifrost Chat Mgt Tests`, `Bifrost Language Model Tests`, `Bifrost Chat Transfer Tests`, `Bifrost Chat Utils Tests`, `MCP Tool Server Tests`), the mock provider `Mock Bifrost Chat Provider` with its enum extension, and `LangModel Mock Get Msg Co` + `LangModel Mock Message Type` - a Bifrost Language Models-owned replacement for the Foundation test app's `Bifrost.Mock.Get` type, so the Bifrost Language Models tests do not depend on Foundation's test app. Plus 4 provider test codeunits (`LangModel Prov Base Tests`, `LangModel API Client Tests`, `LangModel Providers Tests`, `Chat Svc Gate Tests`) covering config resolution, token-usage parsing, multi-modal message building, response-text extraction and per-provider metadata dispatch, and 2 setup/secret test codeunits (`LangModel Secrets Tests`, `LangModel Setup Page Tests`) covering the secret code layout, registration with the right scope, the set/is-set/clear round trip of both keys, the personal-before-shared read order, clean-up on delete and rename, and that the Bifrost Language Models setup page opens and `Setup ori` carries the single Apps action. 168 tests in total across 11 test codeunits.
- **Bifrost Language Models setup page and the shared Bifröst secret store** (platform alignment with Bifrost Foundation 28.0.0.0):
  - `LangModel Setup ori` (page 10035421, `ContextSensitiveHelpPage = 'bragi-setup'`) - the app's own setup page, opened from the **Apps** group on `Setup ori`. It reports the number of language models and the default one, the number of MCP tool server tools, and how many language models still need an API key, with actions to the language model list and to **Bifrost App Secrets** filtered to Bifrost Language Models. The HttpClient notification moved here from the `Setup ori` page extension.
  - `LangModel Secrets ori` (codeunit 10035422, `Access = Public`) - this app's facade over Foundation's `Secret Store ori`. It owns the secret codes, registers them, resolves the API key of a request (personal key first, then the shared key, both with `MarkUsed`), and clears them when a language model is deleted or renamed.
  - Secret codes per language model: `LANGMODEL-<Code>-API-KEY` (scope **Company**, the shared key) and `LANGMODEL-<Code>-USER-API-KEY` (scope **Company And User**, the personal key). `<Code>` is the uppercased language model code; the longest possible code is 43 characters, so a `Code[20]` model code never has to be truncated to fit `Code[50]`.
  - Both codes are registered when a language model is inserted or renamed, and from `Copilot Install ori.OnInstallAppPerCompany` and the new `Copilot Upgrade ori.OnUpgradePerCompany` for every existing language model. Registration is idempotent.
- Icelandic translation `app/Translations/Bifrost Language Models.is-IS.xlf` (253 units, all translated), HTML help in `app/Help/en-US` and `app/Help/is-IS` (`BifrostChat.html`, `BifrostLangModelCard.html`, `BifrostLangModelList.html`, `index.html`).

### Changed

- Object ids were renumbered from the Foundation range into 10035335-10035484 and test ids into 96000-96199. Object **names are unchanged**, so no caller or configuration that refers to an object by name is affected.
- `Bifrost Chat Utils ori.GetIdentityJson()` replaces the direct call into Foundation's internal `Help WhoAmI Get Impl ori`: the chat pages now build the connection-validation identity by running the public `Help.WhoAmI.Get` message type through Foundation's `Msg Interface ori`, dropping the response envelope status and the personal system prompt.
- `Chat Gate ori` moved out of Foundation's posting-gate folder and is now a Bifrost Language Models table.
- Help and documentation moved to <https://businesscentralal.github.io/bifrost> (source repository `businesscentralal/bifrost`), where the English and Icelandic content for every Bifröst app is published together. The `app/docs` and `app/Help` folders were removed from this repository; `help` in `app.json` now points at `https://businesscentralal.github.io/bifrost/en-us/bragi/` and `contextSensitiveHelpUrl` at `https://businesscentralal.github.io/bifrost/{0}/help/bragi/`.
- Context-sensitive help pages are now addressed by slug instead of by HTML file name: `ContextSensitiveHelpPage` is `bifrost-chat` (36 page extensions), `bifrost-lang-model-card` and `bifrost-lang-model-list`.
- **API keys moved out of this app's own IsolatedStorage into the Bifröst secret store.** The six inline storage sites that used the keys `Bifrost_Chat_Usr_<SystemId>_<UserSecurityId>` and `Bifrost_Chat_Svc_<SystemId>` (all `DataScope::Company`) now go through `LangModel Secrets ori`:
  - `Bifrost LangModel Card ori` - the two masked **Personal API Key** / **Service API Key** fields are gone. The Authentication group now shows read-only **Personal Key Stored** / **Shared Key Stored** flags plus a hint when neither key is set, and four actions - **Set / Clear Personal API Key** and **Set / Clear Shared API Key** - use Foundation's shared masked dialog (`Secret Store ori.SetFromDialog`). The shared-key actions stay gated by `BIFROST ChatSvc ori`.
  - `Bifrost Chat Mgt ori` - `SaveApiKey`, `SaveServiceApiKey`, `ClearCredentials`, `BuildArgument` and the `hasServiceKey` property in `BuildConfigJson`.
  - `Bifrost Language Model ori.OnDelete` - clears both secrets; new `OnInsert` and `OnRename` triggers register them (a rename carries over the values this user can read; personal keys of other users are re-entered).
  - `LLM Prompt Compl Impl ori.BuildChatArgument`.
  - The Bifrost Chat FactBox and Chat Focus `SaveApiKey` / `SaveServiceApiKey` triggers, through `Bifrost Chat Mgt ori`.
- **API keys are `SecretText` end to end.** `Bifrost Chat Argument ori.SetApiKey` takes and `GetApiKey` returns `SecretText`; `HasApiKey()` replaces the old `GetApiKey() = ''` checks. `LangModel API Client ori`, `LangModel Chat Proxy ori` and `Anthropic LangModel Proxy ori` pass the key as `SecretText` into the HTTP header (`SecretStrSubstNo` for the `Bearer` scheme). The key is never converted to `Text`: `SecretText.Unwrap()` is `OnPrem`-scoped and cannot be used in a Cloud app.
- **`apiKey` in the chat control add-in configuration is no longer the key.** The JavaScript only tests the property for truthiness - it routes every request back through AL - so `ConfigJson.Add('apiKey', ...)` now receives the non-secret marker from `Bifrost Chat Argument ori.GetApiKeyIndicator()`. The API key itself no longer leaves the server.
- **Google Gemini authenticates with the `x-goog-api-key` header** instead of the `?key=` query string, on both the native `generateContent` call and the model list. The key no longer appears in a request URL, which also removes the URL masking the request log needed.
- `Setup LangModel ori` (page extension 10035403) was reduced to what Foundation's platform rules allow a dependent app to add: one action in `addlast(Apps)` opening `LangModel Setup ori`, plus its actionref in `addlast(Category_Apps)`. The **Bifrost Language Models** action, its promoted actionref and the `OnOpenPage` HttpClient notification moved to `LangModel Setup ori`.
- `BIFROST LLM ori`, `BIFROST LLM Rd ori` and `BIFROST Chat ori` grant the new `LangModel Setup ori` page and `LangModel Secrets ori` codeunit, plus Foundation's `Secret Store ori` codeunit and `App Secrets ori` page.

### Migration

- **API keys do not migrate.** Values written by an earlier build (or by the legacy *Origo Cloud Events Chat* app) live in that extension's own IsolatedStorage and are unreachable from the Bifröst secret store. After deployment every language model shows **no key stored**; an administrator re-enters the shared key once per language model, and each user re-enters their personal key once. The Bifrost Language Models setup page and the language model card both show this hint while a key is missing, and **Bifrost App Secrets** lists every registered key with its state.
- Renaming a language model changes its secret codes. The values this user can read are carried over automatically; personal keys belonging to other users must be entered again. The registry rows of the old codes stay behind in **Bifrost App Secrets** with no value - Foundation's `Secret Store ori` has no unregister operation.
