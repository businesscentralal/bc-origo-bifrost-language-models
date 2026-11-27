# Changelog

All notable changes to Bifrost Language Models are documented here.

## [Unreleased]

### Added (2026-11-27) - Setup from the Bifrost Related menu (#175)

- Open **Bifrost Language Models Setup** directly from **Bifröst → Related**, immediately after **Bifrost Setup**. The action uses the existing setup page and its permissions, with English and Icelandic captions and tooltips.
- Requires Bifrost Foundation **28.0.17.0**, which supplies the extensible Bifröst page and its setup action.
- New page extension **10035448** `LangModel Bifrost ori`; new navigation test codeunit **96088** `LangModel 175 Navigation Tests` invokes the action in English and Icelandic and verifies that the setup page opens.


### Fixed (2026-11-27) - Icelandic catalogue search (#173)

- `LLM.Prompt.Ask` and `LLM.Prompt.Complete` include every localized search phrase in their Icelandic catalogue description, within 250 characters. Examples: `spyrja mállíkan`, `búa til texta`, `draga saman texta` and `lesa skjal`. English descriptions and keywords are unchanged.
- Extended catalogue parity tests in codeunit **96036** to reject missing/untranslated Icelandic keywords, phrases absent from the description and descriptions over the catalogue limit; regression cases cover empty entries, whole phrases and the 250-character boundary. Updated implementation codeunits **10035396** and **10035432**; no new objects.

### Fixed (2026-11-26) - LLM.Prompt.Ask: no uncoded runtime errors from the tool loop (#171)

- Root cause 1 (`Arithmetic operation resulted in an overflow.`): the runner summed the provider `usage` values as Integer. xAI reports `cost_in_usd_ticks` near 10^9 per round, so a few tool rounds passed 2^31 and the sum overflowed outside any error handling. Usage values are now read and summed as Decimal; a single value above 2^31 is kept instead of being dropped. Non-number usage entries (objects, text, null) are still left out.
- Root cause 2 (`Unable to convert from NavJsonToken to NavJsonObject.`): a runtime error inside a tool call (for example Foundation's table/csv formatting casting a non-object array item) ended the whole run with `{"status":"Error","error":"<runtime text>"}`. Each tool call now runs through the new codeunit **10035447** `LLM Ask Tool Call ori` with `if not Codeunit.Run`: the model gets `{"error":"the tool <name> failed: <text>"}` as a tool error, counted in `toolErrors`, and the run goes on. Tool arguments and results of any JSON type (array, string, number, null) are handled without a cast.
- A provider failure during the loop still answers with its stable code (`Retryable` or `PreconditionFailed`, or `InvalidParameter` for a refused file) and now also carries `stopReason` `providerError`, `rounds`, `toolCalls`, `toolErrors`, `deniedToolCalls`, `warnings` and the `usage` so far.
- Help (notes) for `LLM.Prompt.Ask` lists the error codes the tool loop can return.
- Tests: new codeunit **96086** `LLM 171 Ask Loop Error Tests` (non-object arguments, results and toolCalls entries, a JSON cast error inside a tool in 1033/1039, usage above 2^31 over three rounds, non-number usage, provider failure after a tool round in 1033/1039, non-JSON provider answer, help). New objects: codeunit 10035447 (in permission set `BIFROST LLM Chat ori`), test codeunit 96086, and test-app codeunit **96087** `LLM 171 MCP Fixture` (answers only the reserved `https://example.invalid/x171-fixture/` endpoint: two tool rounds with xAI-sized usage, then a reply, or HTTP 503 on `/fail/`; no outbound request). No new labels to translate (the tool error text is Locked; it is read by the model).

### Added (2026-11-25) - Language model usage and historical cost (#168)

- Each provider request records token counts, cached/reasoning tokens when reported, duration, model, source, user, outcome and a metadata-only Request Log reference. Prompt, response, file and credential content is excluded. Missing usage is marked explicitly. One `ORI-LM-USAGE` telemetry event contains only model, source, token counts and outcome.
- Set **Input Price per 1M**, **Output Price per 1M**, and **Usage Currency Code** on a Language Model card. Cost is input tokens × input price / 1,000,000 + output tokens × output price / 1,000,000. Each call stores its prices and cost; later changes never recalculate history. Prices are administrator-maintained estimates, not provider invoices.
- The bilingual **Usage guide** action explains prices, usage flags, company-wide compression, job-queue scheduling and retention directly in the product. The contextual model-card help links remain valid in both languages.
- Open **Usage log** from the model card to filter recorded calls. **Daily totals** opens compressed history. Card totals combine detail and daily rows for the current month in the selected usage currency; different currencies are never added together.
- **Compression setup** defaults to 30 days and does not retain user identity. **Compress usage** moves strictly older days into daily totals and deletes only those detail rows in the same transaction. Repeating the action is safe. An optional Job Queue Entry can run codeunit 10035445. Compression applies company-wide regardless of the current list filter.
- Standard **Retention Policies** recognizes detail (call timestamp) and daily totals (call date). Installation/upgrade creates disabled policies for 90 days of detail and two years of daily history. Administrators choose when to enable them. Schedule compression before retention if daily history must be preserved.
- Assign **BIFROST LLM UseR ori** for read-only usage access, or **BIFROST LLM Use ori** for compression administration. The Foundation Full role includes administration. Direct log writes are not granted.
- New objects: tables/pages 10035440 `LLM Usage Log ori`, 10035441 `LLM Usage Daily ori`, 10035442 `LLM Usage Setup ori`; codeunits 10035440 `LLM Usage Recorder ori`, 10035443 `LLM Usage Copilot ori`, 10035444 `LLM Usage Retention ori`, 10035445 `LLM Usage Compression ori`, 10035446 `LLM Usage Help ori`; permission sets 10035440/10035441. Tests: 96083, mock 96084, reserved-endpoint MCP fixture 96085. EN/is-IS captions and tooltips included.

### Fixed (2026-11-18) - Custom LLM: staged attachments on Ask (#156)

- Root cause: the Custom LLM Ask path sent every non-image file as an OpenAI `file` part (`data:text/plain;base64,...`) and returned any failure as a thrown text, so an OpenAI-compatible text model refused the request and the caller saw only "The language model provider could not complete the prompt." with no status or reason.
- Staged and inline `text/*` and `application/json` files are now text content parts (`Attached file <name>:` plus the decoded text), the same as `LLM.Prompt.Complete` (#133); PNG and JPEG stay image parts. This also holds for the continuation rounds after tool calls.
- A file type the endpoint cannot take (for example a PDF) is refused before the call with `InvalidParameter` that names the provider (Custom LLM) and the file, parameter `file`/`files[n]`, received = the MIME type. New contract error text on `LLM.Prompt.Ask` and `LLM.Prompt.Complete` (is-IS translated, 4 new labels in the is-IS file). The PDF refusal applies to Ask only; `LLM.Prompt.Complete` on Custom LLM is unchanged.
- A failed Custom LLM chat call returns the safe prompt error: HTTP status in `received` and a redacted provider reason (4xx other than 401/403), never the provider body, like Gemini (#134).
- Tests (mock only): new codeunit **96082** `LLM 156 Custom Ask Tests` (staged text 1033/1039, staged text with html, PNG, PDF refusal 1033/1039, 400 with redacted reason 1033/1039, 401, staged/inline normalized JSON, and inline text with safe failure after a tool continuation). The shared staging suite also verifies JSON on Complete. The existing MCP probe provides bounded mock-only Custom LLM scenarios with owned-data cleanup. No new product objects.

### Fixed (2026-11-18) - Icelandic full-suite test expectations (#151–#155)

- The 1039 full-suite run exposed 11 failures in test codeunits 96018, 96034, 96037, 96067 and 96079: one outdated Icelandic success label and English-only expected error/contract text. Updated the test resources to the existing product translations. All assertions, boundary checks, error cases and the 686 test methods remain; tests execute in the selected language. No product behavior, contract or translation changed.

### Tests (2026-11-18) - Full release verification in Icelandic (#149)

- Added test runner codeunit **96081** `LM Icelandic Test Runner ori`. It starts every test method in LCID 1039 and restores the previous language afterwards, while preserving Microsoft's codeunit isolation, permission mocking and result reporting. The standard runner remains the English full-suite entry point. No product objects or product translations changed.

### Fixed (2026-11-16) - Google and provider endpoint defaults (#142)

- New Google model cards and runtime requests without a configured model use `gemini-flash-latest` instead of `gemini-2.5-flash`, which returned 404 with the current key.
- Changing Chat Provider replaces the previous provider's default Base URL with the selected provider's default. Custom, Azure and proxy endpoints remain configured, preserving #60; selecting the same provider is idempotent. Trailing slash variants count as the same default. A provider without a default URL leaves the inherited URL empty for configuration. Explicit models, paths and limits are preserved.
- No new product objects or translated labels. New test codeunit **96080** `LangModel 142 Defaults Tests` covers card and table validation, provider pairs, empty/default Google model, custom URLs, trailing slashes and repeated selection.

### Changed (2026-11-16) - Icelandic review of the texts changed since 28.0.2 (#144)

- Reviewed the 148 is-IS units added or changed since 28.0.2 against their English source and the Foundation terms (mállíkan, veitandi, kvaðning, viðhengi). Corrected wrong plural (`verkfærakköll` to `verkfæraköll`), the mistranslated "redacted" (`ritskoðaðri` to a plain description), a wrong participle (`lokið keyrsla` to `lokin keyrsla`), and awkward phrasing in the Ask limit captions and tooltips, the Copilot and file errors, the staging texts and the Ask help. Wording only: no new objects, no change to keys, placeholders, JSON names or Locked labels, no en-US file.
- The `is-IS=` comments in AL and `Bifrost Language Models.is-IS.xlf` are in sync (`Test-IcelandicXlfInSync`).

### Fixed (2026-11-16) - sessionTime missing on staged-attachment calls (#136)

- Root cause: `LLM.Prompt.Complete` and `LLM.Prompt.Ask` read Foundation's SESSION TIME block after the staged uploads had been taken. Taking a staged upload writes in the call transaction, and Foundation cannot supply the block while a write transaction is open, so every staged call answered `sessionTimeUnavailable` instead of `sessionTime`. Inline files and calls without attachments were not affected.
- Both message types now read the block first, before `LLM Staging Files ori` takes the uploads. No new objects, no change to the one-shot consumption or to the fail-open rule.
- Tests (mock only): 96071 `LLM Staging Files Tests` gains Ask and Complete scenarios with a clock that fails once the staged upload is gone; the seam `LLM Session Time Seam` (96062) gains `FailAfterStagingTaken`.
### Fixed (2026-11-15) - text attachments on LLM.Prompt.Complete chat completions (#133)

- OpenAI chat completions accept only `application/pdf` as a `file` part. `LLM.Prompt.Complete` on OpenAI, Azure OpenAI and Custom LLM sent `text/plain` (and any other non-image) as `type: file` / `file_data`, so GPT-6.1 and an OpenAI-compatible Custom model (KAPPI) answered 400. Those types are now a `text` content part: `Attached file <name>:` and the decoded text. PDF stays a `file` part. PNG and JPEG stay `image_url`. No new objects.
- `LLM.Prompt.Ask` is unchanged. A reasoning model still sends text on the Responses API as `input_file`, which accepts `text/plain`. Ask on chat completions still uses the previous file part.
- Tests: codeunit **96078** `LLM 133 Text File Tests` (inline and staged text on OpenAI, Azure OpenAI and Custom LLM, 1033 and 1039; non-PDF types never a file part; PDF still a file part; text beside a PDF; invalid Base64 refused before HTTP; Ask Responses and Ask chat completions unchanged). Mock HTTP only in the suite. Live OpenAI and KAPPI calls are recorded on the PR.

### Fixed (2026-11-15) - LLM.Prompt.Complete with a Copilot language model: coded failures instead of the generic provider error (#132)

- Root cause of the Origo Demo UAT failure (COPILOT card over MCP, capability Active, UI chat working): Business Central's System Application refuses Microsoft-managed Azure OpenAI (the resource the Copilot provider uses) in API, OData, SOAP and Management sessions and in any session without a UI (`AzureOpenAIImpl.GuiCheck`: "Microsoft Copilot Capabilities are not allowed in API and OData Web Services sessions" / "... in the background"). An MCP call runs in such a session, so it can never reach Copilot. The error was thrown inside the provider, caught by `TryCompletePrompt` and cleared, so the caller got the generic `PreconditionFailed` with the Base URL/API key next step. The UI chat works because it runs in the interactive web client. This is a platform limit, not a setup error.
- `Copilot LangModel Prov. ori` (codeunit 10035385) now checks the capability and the session before it calls Copilot and answers a coded failure; a thrown System.AI error and a failed managed call keep their HTTP status and a redacted reason. New procedure `GetBlockerResponse`; the unused `GetErrorOrFallback` is removed (local).
- `LangModel Prov. Base ori` (codeunit 10035410) gains `BuildCopilotFailure`, `GetCopilotBlockerKind`, `GetCopilotSessionToken` and `AddCopilotErrors`; `RespondPromptError` maps them to distinct coded errors: capability not registered / not active (`PreconditionFailed`, `parameter` `roleCode`, `received` `copilot`, next step names the Copilot & agent capabilities page); session refused (`PreconditionFailed`, `parameter` `provider`, `received` `copilot api|odata|odatav4|soap|management|background`, next step: another provider, or Bifrost Chat in the client; no request is sent); managed call failed (`received` `copilot <status>`, redacted reason, 408/429/5xx `Retryable`; no reason for 401/403). The redaction vocabulary gains platform words (capability, session, background, api, odata, web, service, billing, authorized, quota, ...). `LLM.Prompt.Complete` answers the capability refusal also when the Copilot model is not configured, instead of "No language model with a chat provider".
- Help: the `LLM.Prompt.Complete` notes, errors chapter and selection description, and the `LLM.Prompt.Ask` notes and selection description, state that Complete is the only LLM.Prompt.* type that accepts Copilot and only in an interactive Business Central client session; Ask refuses Copilot. is-IS in sync. No new app objects.
- Tests: new codeunit **96079** `LLM 132 Copilot Tests` (14 tests, 1033 and 1039, no provider call): each coded failure, capability-before-session order, the client-type mirror of the platform check, an unknown session token, 400 with redacted reason, a thrown platform error, 429 retryable, 401 without reason, Complete with a Copilot card never answering the generic failure, and the contract text. The test codeunit was renumbered to 96079 when merging main: #134 uses 96076, #135 uses 96077, and #133 uses 96078.

### Fixed (2026-11-15) - Gemini Ask answers about text and PDF documents (#134)

- `LLM.Prompt.Ask` with a Google (Gemini) model card sent text and PDF documents as OpenAI `file` parts to the OpenAI-compatible chat endpoint. That endpoint rejects them, and the failure came back as a generic `PreconditionFailed` with no HTTP status and no provider reason. PNG and JPEG already used `image_url` and worked. `LLM.Prompt.Complete` already used native `generateContent`.
- Ask now sends a text or PDF document, inline or staged, through `generateContent` as `inline_data`, the same shape Complete uses. PNG and JPEG stay on the OpenAI-compatible chat endpoint. A later tool round stays on `generateContent` when the conversation holds a document. The shared file gate runs before that request, so a PDF whose bytes are not a PDF is refused with no provider call.
- A Google provider error on Ask, with or without a document, keeps the HTTP status and, for a non-authentication 4xx, a redacted reason. `SanitizeProviderErrorCode` on codeunit 10035410 reads a Google `error.status` such as `INVALID_ARGUMENT` as `invalid_argument`. Authentication bodies stay private.
- No new production objects. Test codeunit **96076** `LLM 134 Gemini Ask Tests` covers text and PDF inline, staged text, PNG staying on chat completions, a bad PDF signature, a 400 with a redacted reason, a 401 that keeps the body private, and a document tool round. Locales 1033 and 1039 are covered where the acceptance criterion names both. The tests use the HTTP mock only.
### Fixed (2026-11-16) - LLM.Prompt.*: an image sent to a model that cannot read images gets a coded refusal (#135)

- `LLM.Prompt.Complete` and `LLM.Prompt.Ask`: when the request carries an image and the provider answers HTTP 4xx because the
  model cannot read images (for example KAPPI qwen3:8b: "Multimodal data provided, but model does not support multimodal
  requests."), the answer is now `InvalidParameter` on `roleCode`: "The language model <code> (<model>) cannot read images."
  with a nextStep that suggests up to three other language model codes whose provider takes images (OpenAI, Azure OpenAI,
  Anthropic, Google, xAI), or names those providers when there is none. Before, the generic PreconditionFailed provider
  error with a mostly redacted reason was returned.
- Image support is not a field on the language model card (Known Ambiguity 1, resolved: map the provider error). Detection
  reads only the HTTP status (4xx except 401, 403, 408, 429) and the redacted reason: a negation plus multimodal, vision or
  "only supported by", or an image word together with "model". A refusal of the image itself ("valid", "format", for example
  "The image is not valid." or "Unsupported image format.") is never mapped (review AMEND 1). The errors chapter of both message types documents this in en-US and is-IS.
- The provider-reason vocabulary keeps `multimodal`, `vision`, `images`, `support`, `supports` and `requests`.
- `LangModel Prov. Base ori` (10035410): new `RespondImageNotSupported`, `HasImageFile`, `IsImageNotSupportedFailure`,
  `GetImageCapableRoleCodes`. `LangModel API Client ori` (10035411) remembers the status and redacted reason of a failed
  chat request (`GetLastChatFailure`) and has a test hook `OnBeforeChatPostWithStatus`; `LangModel Chat Proxy ori` adds
  them to its failure answer as `chatProviderStatus`/`chatProviderReason`, read only by the image check, so the Ask path
  (tool loop over chat completions) maps the same refusal. Other Ask and Bifrost Chat failure answers are unchanged.
  Tests: codeunit **96077** `LLM 135 Image Refusal Tests` (Complete and Ask, 1033 and 1039, non-image and non-matching
  refusals stay provider errors, 401 is never mapped, help in both languages).

### Fixed (2026-11-15) - xAI Responses success read as a failure: staged attachments on GROK (#125 AC05 b/c fix-forward)

- Root cause of the Origo Demo UAT failure on 28.0.3.91 (staged `text/plain` attachment, alone and with html, on GROK): the xAI Responses API returns `"error": null` in every successful response body, as OpenAI does. `LangModel API Client ori` (codeunit 10035411) treated the presence of the `error` key as a failure and returned a prompt error with status -1, so every Ask or Complete that went through Responses (any file) came back as the generic `PreconditionFailed` "could not complete the prompt" with no status or reason. Html-only passed because it uses Chat Completions, which has no `error` key; SONNET passed because Anthropic has its own path. The mocks did not reproduce it because their success fixture had no `error` key.
- Now only a non-null `error` is a failure (`HasProviderError`), and a null `error` is removed from a successful prompt or file-upload body (`RemoveNullError`), both on `LangModel Prov. Base ori` (codeunit 10035410). Used by the API client, the xAI Responses paths in `LangModel Chat Proxy ori`, `xAI LangModel Prov. ori` and `LangModel File Handling ori`. A 2xx body with a real error object still fails, and now keeps its HTTP status in `received`.
- AC03: an xAI Responses-hop failure is marked `providerStage` `responses`, and the MCP error `received` names the hop: `responses request 400 <code>` (is-IS `svarbeiðni 400 <code>`), next to the existing `file upload ...` for the upload hop. The redacted reason stays in `error` for a non-authentication 4xx. New label `ResponsesStageReceivedTxt`; is-IS in sync. No new objects.
- Tests (mock only, no live calls): 96072 `LLM 125 xAI Tests` gains staged text with null error on Ask (text and html, 1033 and 1039) and Complete, the responses-hop refusal (1033 and 1039), a 2xx in-body error, and the shared null-error rules including a file upload with `"error": null`. 96034 expects the hop prefix on the xAI PDF prompt failure. The MCP probe `Test.LLM116.Probe` (scenario `xai125`) accepts `nullError` to send the real wire shape. Live GROK is not run from a worker; Tester re-runs AC05 (b)(c) after deploy.

### Fixed (2026-11-14) - xAI text attachments and upload failure visibility (#125, folded into #129)

- xAI `LLM.Prompt.Ask` and `LLM.Prompt.Complete` now send a `text/*` or `application/json` attachment inline as an `input_text` block on Responses ("Attached file NAME:" followed by the decoded UTF-8 text) instead of uploading it to `/v1/files`. The Origo Demo UAT failed exactly there (text/plain attachment, with and without html output). PDF documents still use the upload and are deleted after the call; PNG/JPEG stay inline images. Not verified against live GROK from this branch (no GROK model on the worker tenant); Tester re-runs AC05 (a)(b)(c) after deploy.
- AC03: a refused document upload is marked as the upload hop: the error `received` reads `file upload 400 <code>` (or `file upload` when the provider answered 2xx without a readable file id). The redacted-reason vocabulary now also covers upload words (purpose, upload, multipart, form, bytes, size, empty, name, extension, mime, encoding, attachment). Tests: 96072 gains the inline-text and upload-stage scenarios; 96034 expectations updated for the inline text path.

### Fixed (2026-11-14) - validate inline files before the provider call (#128)

- **Fixed:** the shared pre-HTTP file gate (`LangModel File Handling ori`, codeunit 10035429, used by OpenAI, Azure OpenAI, Custom LLM, Anthropic, Google and xAI) now also refuses file data that is not standard Base64 and a PDF, PNG or JPEG whose content does not start with its signature (`%PDF-`, the PNG signature, `FF D8 FF`). The refusal is `InvalidParameter` with `parameter` `file` (or `files[n]`, counted from 0, when several files are sent), `received` `not base64` or `content is not <type>`, and a next step about the file ("... No request was sent."); no provider call is made, so the misleading model-setup hint no longer appears. Applies to `LLM.Prompt.Complete` file, files and stored/staged attachments, and reaches `LLM.Prompt.Ask` once #127 sends files through the same gate. Other document types (for example `text/plain`) are not content-checked. New refusal builders and contract error entries in codeunit 10035410; is-IS translations in sync.
- Tests: new codeunit 96074 `LM 128 File Validation Tests` (not Base64, bad padding, empty data, text labelled PDF, PDF labelled PNG, PNG labelled JPEG, `files[1]`, valid PDF/PNG/JPEG unchanged, all six providers; 1033 and 1039; mock provider only). Existing fixtures that sent non-PDF bytes labelled as PDF or a truncated JPEG now use valid signatures (96034, 96041).

### Added (2026-11-14) - inline file and files on LLM.Prompt.Ask (#127)

- `LLM.Prompt.Ask` accepts optional inline `file` (one object) or `files` (array) of `{data, mimeType, fileName}`, the same shape as `LLM.Prompt.Complete`, so a playbook can send a PDF or picture produced by an earlier step. They can be combined with `attachments`; staged files come first, then inline files. `file` wins over `files`. Additive: existing callers are unaffected.
- Refusals before any provider call: `InvalidParameterFormat` (`file` / `files` / an entry has the wrong shape), `MissingParameter` (`file.data`), `InvalidParameter` (`file.mimeType`, `files[n].mimeType`: only text/*, PDF, PNG, JPEG), `LimitExceeded` on `files` (more than 10 files in all, or staged and inline bytes together over the model Attachment Limit Bytes; 0 uses 100 MB). Each has a `nextStep`.
- Provider handling is unchanged and shared: Anthropic sends PDF/PNG/JPEG as document/image blocks; xAI uploads documents to Responses for each round and deletes them after the request, including on failure, and re-uploads on continuation from the local input.
- Codeunit 10035435 `LLM Staging Files ori` gains `ResolveInline`, `MaxFilesPerCall`, `AddInlineParameters`, `AddInlineErrors`; no new object. Contract parameters, errors and notes of `LLM.Prompt.Ask` updated; is-IS in sync.
- Tests: new codeunit **96075** `LLM Ask Inline Files Tests` (16 mock-only tests, 1033 and 1039): request shapes, order, precedence, combined staged and inline, count and size caps, refusals, xAI upload/delete, Anthropic document block, contract.

### Fixed (2026-11-14) - Anthropic Ask provider failures keep their status (#125 AC03)

- The Anthropic tool loop (`LLM.Prompt.Ask`) now returns the HTTP status, a sanitised provider error type and, for a non-authentication 4xx, the redacted reason, as `LLM.Prompt.Complete` already did. Before, a provider 4xx reached the caller without `received`. Authentication bodies and other provider text stay private. Adds the internal test hook `OnBeforeMessagesPostWithStatus` on codeunit 10035417 and test codeunit **96073** `LLM 126 Anthropic Err Tests` (mock-only, no credentials). Live Anthropic checks in 1033 and 1039 are recorded on #125 and #126.

### Fixed (2026-11-13) - xAI prompt attachments and provider diagnostics (#125)

- Ask persists consumed staging uploads before its provider/tool loop, so a fresh MCP bootstrap can run without an open staging write transaction.
- xAI Ask sends documents through Responses using uploaded file IDs. Each round uploads from the caller-owned input and deletes those files after the request, including failures; continuation state keeps local bytes instead of deleted IDs. PNG/JPEG remain inline and shared MIME/size validation runs before transport. HTML remains a prompt instruction, with existing complete-document validation.
- xAI Ask retains structured HTTP failure metadata. Ask and Complete can show a redacted non-authentication 4xx reason: only a fixed diagnostic vocabulary and protocol field names are retained; unknown tokens are replaced, authentication bodies remain private, and raw error text is never logged by the prompt transport. Complete joins a base URL ending in `/v1` without duplicating that segment.
- `LLM.Prompt.Ask` with `outputFormat` html ends the user message with an ANSWER FORMAT reminder (Oinn, worker-36, `b90f19c`; confirmed live by Hanarr, worker-38). A question that asked for a short or plain answer made the model follow the user text over the system text and fail with "holds no complete HTML document" in both languages. Tests in `LLM Ask Html Tests`. No object IDs added.
- The #40 figure-verification follow-up no longer runs in a headless `LLM.Prompt.Ask` round (all providers; the request carries `allowedTools`). It replaced the requested answer with the model's "nothing to verify" text whenever the answer held a number of four digits or a decimal, so `outputFormat` html failed with "holds no complete HTML document" for any styled page. Found by the live Anthropic check (AC01 repro: html-only). Test `Ask_ReplyWithFigures_IsNotFollowedByVerifyPrompt` in `LLM Ask Request Builder Tests`.
- Anthropic Ask and Complete send a `text/*` attachment as a `text` document source (`media_type` `text/plain`, decoded UTF-8) instead of base64, which Anthropic rejects with 400 `invalid_request_error`. Found by the live Anthropic check (Hanarr, worker-38, 14.11.2026); PDF, PNG and JPEG were already correct. Test `Scenario_Anthropic_PlainText_SendsTextSourceNotBase64` in codeunit 96041 `LM 96 MIME Tests`. No object IDs added.
- Adds test codeunit **96072** `LLM 125 xAI Tests`: real-provider request shapes through both message types, both locales, HTML/file combinations, text regression, continuation upload cleanup, transport failures, image validation, and redacted errors. The existing test-only staging probe can run these owned synthetic xAI fixtures over MCP. No production object IDs or message types added. Live reproduction and post-deploy UAT remain separate acceptance work.

### Fixed (2026-11-13) - installed storage path in prompt help (#116)

- Codeunit 10035435 now advertises the registered `Storage.File.CopyToStaging` path in Ask and Complete related help. Test codeunit 96071 verifies the shipped name and excludes the unshipped `Storage.File.ReadToStaging` name. The registry stand-in is injected through `AddRelatedFromTypes`, so the test extension no longer duplicates the Attachments enum registration and can coexist with it.

### Added (2026-11-12) - staged prompt attachments (#116)

- #116: `LLM.Prompt.Ask` and `LLM.Prompt.Complete` accept ordered caller-owned Foundation staging attachments, with MIME validation, coded errors and a per-model total byte limit. Related help names installed storage-to-staging types only. Adds codeunit 10035435 and field 27 on table 10035335; updates pages/permissions, Ask runner 10035433 and prompt implementations 10035432/10035396. Requires Foundation 28.0.13. Existing Complete file inputs remain compatible. Test codeunit 96071 covers staged attachments. Test-only table 96170, permission set 96172 and installer 96171 seed a synthetic foreign creator for both prompt types without creating users or credentials; the live two-user check remains NOT_RUN per Architect 1794519937.523119.

### Added (2026-11-11) - telemetry events for LLM.Prompt.Ask without content (#102)

- **Added:** codeunit 10035434 `LLM Ask Telemetry ori` (Internal, X in `BIFROST LLM Chat ori`), the place that emits the Ask events with `Session.LogMessage` (`SystemMetadata`, scope `ExtensionPublisher`) and the only place that chooses dimension values (`BuildDimensions`). Events: `ORI-LM-ASK-0001` started (Normal), `-0002` completed (Normal; stopReason completed or schemaInvalid), `-0003` limitHit (Warning; maxToolCalls or maxRounds), `-0004` denied (Warning; once per run, a count), `-0005` providerError (Error), `-0006` providerNotSupported (Warning; Copilot or no split tool execution). A run that started ends in exactly one of 0002, 0003 or 0005; there is no per-tool-call event.
- **Dimension allow-list (nothing else is ever added):** `Category` (`Bifrost.LanguageModels.Ask`), `provider` (enum name), `modelCode`, `rounds`, `toolCalls`, `toolErrors`, `deniedToolCalls`, `stopReason` (completed, schemaInvalid, maxToolCalls, maxRounds, providerError), `durationMs`, `schemaValid` (true, false, notRequested), `callerSource`. Numbers are written with `Format(value, 0, 9)`. No prompt, context, answer, tool name or argument, trace or record data reaches telemetry. Event 0006 carries `Category` and `provider` only.
- **Changed:** `callerSource` is Foundation's trusted public `GetInvocationSource()` (Direct, Queue, Task, Dispatcher), not the story's Orchestrator / McpToolServer / Other: `Message Argument ori.Source` is `Access = Internal` in Foundation and cannot be read from this app.
- Tests: 96069 `LLM Ask Telemetry Tests` (events, ids, verbosity, terminal-event rule, allow-list, sentinel strings in question, context, instructions, tool argument, denied tool and source, 1033 / 1039 numbers) with spy 96068 `LLM Ask Telemetry Spy` on the new internal seam `OnAfterEmit`. No new Request Log row, table or field.

### Fixed (2026-11-11) - refuse provider-truncated HTML output (#113)

- **Fixed:** shared chat proxy 10035412 and Anthropic proxy 10035417 preserve provider completion metadata (`finish_reason`, Responses `status`, and `stop_reason`). HTML-mode runner 10035433 refuses a token-limited, filtered or incomplete provider response before processing its tools or returning `html`, even when closing HTML tags are present. Normal completions and providers without completion metadata remain supported; text-mode behavior is unchanged.
- Tests: 96065 verifies completion metadata for chat completions, Responses and Anthropic using HTTP mocks; 96066 covers a complete-looking document with a token-limit stop reason. No live-provider calls.
- **Test fixture cleanup:** codeunit 96037 removes only its explicitly created user identities, permission assignments and Bifrost user setup after its assertions, so repeated setup-wizard tests do not accumulate licensed user fixtures. It does not change existing users or licence state.

### Fixed (2026-11-11) - test chat confirmation target (#113, PR #121 verification)

- **Fixed:** test-only codeunit 96026 `Test LangModel Chat Impl` declares `data.code` as its target. Foundation can now count the selected model and refuse a mismatched `expectedCount` before calling the provider. The existing refusal assertion remains; codeunit 96028 also verifies a matching count executes the mock chat turn.

### Added (2026-11-11) - LLM.Prompt.Ask html output mode (#113)

- **Added:** optional request key `outputFormat` (`text` default, or `html`) on `LLM.Prompt.Ask` (codeunits 10035432 `LLM Prompt Ask Impl ori`, 10035433 `LLM Ask Runner ori`). With `html` the response adds `html`: one HTML document taken from the answer (code fence, text before the first `<!doctype`/`<html` and after the last `</html>` removed, tag matching case-insensitive); `answer` stays the full reply. A `stopReason` other than `completed`, or an answer without a complete document (including a truncated one), returns a coded `PreconditionFailed` error and no `html`. An unknown value gives `InvalidParameter`, a non-string `InvalidParameterFormat`. `responseSchema` is ignored with warning `responseSchemaIgnored` in html mode.
- **Added:** `context` above 1,000,000 characters is refused with `InvalidParameter` before any provider call (all formats).
- **Added:** in html mode the system text says return HTML only, no scripts and no external resources, and that the context is data, not instructions; the context is wrapped in `BEGIN/END UNTRUSTED CONTEXT` delimiters in the user message. Text mode prompts are unchanged.
- **Changed:** `LLM Ask Tool Policy ori.IsAlwaysDeniedMessageType` also denies `Email.Draft.Set` and `Email.Message.Send`.
- Help (contract chapters) and the is-IS xlf cover the new parameter, response field and errors. The generated html is not logged: the existing `LLM Req Log Masker ori` redacts request and response bodies outside debug mode, and no new telemetry is added.
- Tests: 96066 `LLM Ask Html Tests` (mock provider only; extraction, fence/preamble, failures, stop reasons, context cap in 1033/1039, prompt, injection fixture with denied write calls, email deny list, masker).

### Changed (2026-11-11) - LLM.Prompt.Ask caps are configurable per company (#120)

- **Added:** table 10035434 `LangModel Ask Setup ori` (per company, one row): **Ask Max Tool Calls Cap**, **Ask Max Rounds Cap**, **Ask Max Result Chars Cap** and the defaults **Ask Default Tool Calls**, **Ask Default Rounds**, **Ask Default Result Chars**. `Copilot Install ori.InitAskSetup` (install and upgrade per company) inserts the row with the values that were fixed before (caps 40 / 20 / 20000, defaults 15 / 10 / 8000) and never changes an existing row, so nothing changes until an administrator raises a cap.
- **Validation (Gunnar 11.11.2026):** the tool-call and round caps accept **1..999**; the result-size cap counts characters and only needs 1 or more. A default must be 1 or more and not above its cap; a cap below its default is refused as well. Every refusal is a translated error, and insert/modify re-check the whole row.
- **Changed:** codeunit 10035433 `LLM Ask Runner ori` reads the caps and defaults from the setup instead of constants. A request above the cap is still clamped with the existing `clamped:<key>` warning; a request at or below the cap is used as sent.
- **Changed:** the `limits` contract text of `LLM.Prompt.Ask` says the defaults and caps come from the Language Model setup and names the install values; the notes (`Help.Implementation.Get`) show the company's current defaults and caps.
- **Changed:** page 10035421 `LangModel Setup ori` adds the group **LLM.Prompt.Ask Limits** with the six fields and tooltips (en-US/is-IS). The page itself is now editable; the existing status fields are read-only. The fields are editable only with write permission on the table.
- **Permissions:** `LangModel Ask Setup ori` tabledata RIMD in `BIFROST LLM ori` and the `BIFROST LLM Full ori` extension (the language-model admin sets); R in `BIFROST LLM Rd ori`, `BIFROST LLM Read ori` and `BIFROST LLM Chat ori`. The runner also reads it with an inherent read permission. Cost and the read-only tool policy are unchanged: every tool call is still a metered Bifrost message, and write tools are still denied.
- Tests: 96067 `LLM Ask Setup Tests` (install/upgrade values, 0/1/999/1000 on both count caps, result-size cap, defaults against caps, runner below/at/above a cap, raised cap with 100 tool calls and 25 rounds, setup default, result-size cut, help text, setup page in 1033/1039, permission split, restricted Ask caller with a raised cap and a denied write tool).

### Added (2026-11-11) - LLM.Prompt.Ask message type and headless runner (#101)

- **Added:** message type `LLM.Prompt.Ask` (enum value 10035432 on `LangModel Message Type ori`), implemented by codeunit 10035432 `LLM Prompt Ask Impl ori` (`Msg Interface ori`, `Msg Discovery ori`, `Msg Contract ori`; static effect `read`). The model answers a question with optional `context`, `instructions`, `roleCode` and `subject` (passed as RECORD CONTEXT) using read-only Bifrost tools as the calling user, with no human in the loop. Read-only by policy (#100 `LLM Ask Tool Policy ori`); a denied call is returned to the model as a tool error and counted in `deniedToolCalls`.
- **Added:** codeunit 10035433 `LLM Ask Runner ori`: the split-execution loop over SendChatMessage / ContinueWithToolResults with mandatory caps `maxToolCalls` 15 (cap 40), `maxRounds` 10 (cap 20) and `maxResultChars` 8000 (cap 20000); a value above a cap is clamped with a `clamped:<key>` warning. At a cap the remaining calls of the round get a "limit reached" result and one final round without tools forces the answer (`stopReason` `maxToolCalls` / `maxRounds`). `responseSchema` (type, properties, required, enum, items) is validated with one retry (`schemaInvalid`). The trace is returned only with `includeTrace` and is never stored. The API key Last Used stamp is written once after the loop, also on a provider error, and the blobs the run created are deleted by explicit id. There is **no wall-clock timeout** (D3) and no write parameter (D2). Copilot is refused with `PreconditionFailed`.
- **Changed:** the shared chat proxy (chat completions and Responses) and the Anthropic proxy append a new payload property `systemSuffix` after the skills in the system prompt (HEADLESS MODE, caller instructions, OUTPUT FORMAT). Chat and Complete do not send it; their prompts are unchanged.
- **Changed:** `LangModel Prov. Base ori.BuildModelChatArgument` is the one builder of the provider argument for Complete and Ask; Complete's private copy is removed and its behaviour is unchanged.
- **Permissions:** `LLM Prompt Ask Impl ori` as X in `BIFROST LLM ori`, `BIFROST LLM Rd ori` and the `BIFROST LLM Full ori` / `BIFROST LLM Read ori` extensions; `LLM Ask Runner ori` as X in `BIFROST LLM Chat ori`. No new permission set.
- Tests: 96063 `LLM Prompt Ask Tests` (scripted mock provider: reply, tool rounds, caps, clamping, denied call, schema valid / retry / invalid, payload blocks, trace, request validation, Copilot and not-configured gates in 1033/1039, provider error). `Mock Bifrost Chat Provider` 96001 replays a scripted answer queue, records every payload, state and tool-result text, and has a stamp probe that reads the API key "Last Used On" at every provider request (AC14: unchanged during the loop, written after it, also on a provider error). 96064 `LLM Prompt Ask Perm Tests` adds AC21: exact permission sets without read on G/L Account get the tool error and the answer `unknown`. New test codeunit 96065 `LLM Ask Request Builder Tests` (AC13): chat completions, Responses and Anthropic each send Bootstrap once with one fresh SESSION TIME block, HEADLESS MODE, the caller instructions, OUTPUT FORMAT only with a schema and RECORD CONTEXT only with a subject; QUESTION and CONTEXT stay in the user message.

### Added (2026-11-06) - fresh session-time block in every language model prompt (#99)

- **Added:** codeunit 10035431 `LLM Session Time ori` (Internal, in permission set `BIFROST LLM Chat ori`). It reads no clock and formats no date: the block comes only from Foundation's public `MCP Tool Server ori.GetSessionTimeBlock()` (core#1204). It holds `GetBlock`, the replace-or-append helper `ReplaceOrAppend` (also used by LM-3 `LLM.Prompt.Ask`), `ForSystemPrompt` and `GetSummary`. A test event `OnBeforeGetSessionTimeBlock` lets tests advance or fail the block.
- **Fixed:** codeunits 10035431 and 10035396 normalize caller-supplied time blocks before Complete: the fresh block comes first even when an old block was in the middle or at the end, duplicate old blocks are removed, and fail-open sends no stale clock. Regression tests in codeunit 96060 cover ordering, duplicates and failure.
- **Added:** `LLM.Prompt.Complete` always sends exactly one fresh `SESSION TIME (` block first in `systemPrompt`, in front of the caller's `system` or alone; a block already inside `system` is replaced, not doubled. The response adds `sessionTime` {`nowUtc`, `workDate`, `timeZone`}, read from the block that was sent (`timeZone` is left out when Foundation does not know the zone). If Foundation cannot supply the block the call still succeeds, without `sessionTime`, and `warnings` holds `sessionTimeUnavailable`. The Complete contract (parameter `system`, response fields, overview, notes and an example) is updated in English; translated labels are unchanged. There is no opt-out.
- **Changed:** the shared chat proxy (chat completions and Responses), the Anthropic proxy and the Copilot proxy take the block from Foundation on every request and swap it for the session-start block in Bootstrap's text, so the model sees the time of the request, not of the session start. `Copilot Chat Proxy ori.BuildSystemPrompt` is now callable from the test app.
- **Removed:** the #85/#86 session-time builder in `Copilot Chat Proxy ori` (`AddSessionTimeBlock`, `BuildSessionTimeBlock`, the zone, ISO and weekday helpers and their eleven labels) and its eleven `SessionTime_*` tests in 96029. Both were Internal; no public API is lost.
- **Dependency:** the Foundation minimum in `app/app.json`, `test/app.json`, `.claude/CLAUDE.md`, `AGENTS.md` and `README.md` rises from 28.0.4.0 to **28.0.11.0**, the first release with `GetSessionTimeBlock()`.
- Tests: 96060 `LLM Session Time Tests` (helper, Complete, proxies, locale) and 96061 `LLM Session Time Perm Tests` (three role combinations in 1033 and 1039); the mock provider records the CompletePrompt payload.

### Fixed (2026-11-02) - Ask loop reads user setup without a new tabledata grant (#110)

- Codeunit 10035382 `LangModel Chat Provider ori` promotes the caller's existing indirect read on Foundation `User Setup ori` while the codeunit runs, so the API, Read and Full roles combined with Chat and LLM Chat can resolve the assigned language model and system prompt. This relies on those roles retaining their existing indirect read. No permission set or permission-set extension gains tabledata on `Setup ori` or `User Setup ori`. Request Debug Mode is still read through `Setup ori`.GetRequestDebugMode. No production message contract changes.
- The test app adds enum extension 96050 and `Test.LanguageModel.AskProbe`, implementation codeunit 96050, diagnostic codeunit 96051, regression test codeunit 96052 and restricted-role runner codeunit 96058. The regression asserts a successful mock headless tool loop under each of the three exact role combinations, captures native failure stacks and cleans up its own fixture. The test-only message provides nonlive transaction, session-time, blob and tool-metadata diagnostics; it is not a production endpoint.
- Optional OnPrem tooling under `tools/lm98-live` (table 96050 and codeunits 96053–96057) remains outside the product and test app folders. Its isolated live-provider trial is separate from this fix's mock regression coverage and is not included in the shipping app.

### Fixed (2026-10-31) - Confirm irreversible test chat turns (#103)

- Test codeunit 96028 `LangModel Test Tools Tests` uses main's preview-and-confirm helper for irreversible `Test.LanguageModel.Chat` turns before asserting tool replies, provider errors and missing models. The helper retries only `ConfirmationRequired`, using the returned `expected` count, and leaves requests with an explicit `expectedCount` single-shot. This follows Foundation 28.0.11.643's default counted-confirmation gate without disabling it or changing the tool's irreversible contract. A mismatched-count regression proves the provider is not called.

### Added (2026-11-03) - read-only tool policy for LLM.Prompt.Ask (#100)

- Codeunit 10035430 `LLM Ask Tool Policy ori` (Internal, in permission set `BIFROST LLM Chat ori`) classifies every tool of the MCP tool server as read, session or write and denies unknown tools. `invoke_message_type` is allowed only for a message type that resolves (Evaluate, then the canonical name) and declares effect `read`; `LLM.Prompt.Ask`, `LLM.Prompt.Complete`, `Orchestrator.Playbook.*` and `Data.RequestLog.Get` are always denied, `download_blob` is always denied, memory reads are allowed and `set_*` is denied. Only `get_blob` of a blob created in the same run is allowed. Caller lists `allow`, `deny`, `allowMessageTypes` and `denyMessageTypes` can narrow and never widen.
- The shared (chat completions and Responses) and Anthropic request builders accept a payload property `allowedTools` (array of tool names), keep it in the conversation state for the later rounds and send only those tool definitions. Without it the tool list is unchanged. The interactive chat is unchanged. Copilot is not changed.
- Integration events `OnBeforeChatPost` (`LangModel API Client ori`) and `OnBeforeMessagesPost` (`Anthropic LangModel Proxy ori`) let tests answer a request without a provider call.
- Test codeunits 96042 `LLM Ask Tool Policy Tests`, 96043 `LLM Ask Tool Policy Perm Tests`, 96045 `LLM Ask Tool Defs Tests` and mock 96044 `LLM 100 HTTP Mock`.

### Fixed (2026-11-02) - normalise file MIME types (#96)

- Codeunit 10035429 `LangModel File Handling ori` trims the file MIME type, ignores letter case, and drops parameters after `;` before the shared image check and the size checks. ` image/PNG ` and `image/jpeg; charset=binary` stay inline. ` image/GIF ` and `IMAGE/WEBP` stay refused on OpenAI, Azure OpenAI, Custom LLM, Anthropic, Google and xAI. The normalized type is written back onto the file and is what those providers send. `image/jpg` stays refused. GIF and WebP are not newly accepted. `AcceptFiles` keeps the by-value payload signature.
- Codeunit 10035396 `LLM Prompt Compl Impl ori` describes that normalisation in the prompt notes and on the `mimeType` parameter, and keeps the 100 MB total from main. No new image type is accepted.
- Test codeunit 96041 `LM 96 MIME Tests` covers padded, upper-case and parameterised accepted and refused types, and the type sent on each file-accepting provider. Main already uses 96040 for `LangModel Wizard Reg Tests`.

### Fixed (2026-11-02) - Assisted Setup metadata permissions (#105)

- Codeunit 10035426 `LangModel Wizard Reg. ori` grants inherent Execute permissions and entitlements only to its metadata registration callback. Assisted Setup can enumerate the Language Models wizard without granting wizard execution or business administration. Both event skip flags remain false.
- Test codeunit 96040 `LangModel Wizard Reg Tests` exercises the real Assisted Setup page and publisher with a restricted platform-only caller, checks English/Icelandic metadata and repeated registration, and verifies configuration preservation and business/admin refusals.

### Added (2026-11-02) - total size cap for attached prompt files (#95)

- Codeunit 10035429 `LangModel File Handling ori` refuses a prompt before any upload or provider call when the decoded size of all attached files together exceeds 104857600 bytes (100 MB). That total is five times the unchanged 20 MB single-file limit. A single file over 20 MB still uses the existing per-file refusal. The measured total and the cap are both named on the error.
- Codeunit 10035410 `LangModel Prov. Base ori` returns that refusal as `InvalidParameter` on `files`. Codeunit 10035396 `LLM Prompt Compl Impl ori` accepts an optional `files` array when `file` is absent, and the prompt notes, file help and errors chapter describe the 100 MB total. English and Icelandic labels are kept together.
- Test codeunits 96033 `LLM 65 HTTP Mock` and 96034 `LLM 65 Prompt Tests` cover a total under the cap, exactly at the cap and over the cap for OpenAI, Azure OpenAI, Custom LLM, Anthropic, Google and xAI. Over the cap makes no provider call and no upload. The tests resolve a small cap through the existing file-policy event so they do not allocate 100 MB; they also assert the published 100 MB default.

### Fixed (2026-10-31) - confirm irreversible test chat (#93)

- Test codeunit 96028 `LangModel Test Tools Tests` resends `Test.LanguageModel.Chat` with `expectedCount` 1 when Foundation returns `ConfirmationRequired`. The default counter for an empty subject is 1. An unknown parameter is still refused on the first call and is not confirmed. Product objects are unchanged.

### Fixed (2026-10-29) - provider-agnostic prompt files (#93)

- Codeunit 10035429 `LangModel File Handling ori` is the shared file policy. PNG and JPEG stay inline. Any other `image/*` type is refused before HTTP. A decoded file larger than the resolved size cap (20 MB unless a test override raises it) is refused before HTTP. The length check uses that resolved cap, not a fixed 20 MB sentinel. A PDF or other document that the provider cannot accept inline is uploaded to that provider's file store, referenced by `file_id`, and deleted after the call, including when the prompt fails (STE-0002: the prompt and file leave Business Central only for the named provider, and an uploaded document exists there only for the duration of the call). A 2xx upload without a readable file id is logged as `ORI-LM-0093` with HTTP outcome `id unread`. That file can remain at the provider until the provider expires it, because there is no id to delete. A failed cleanup is the same telemetry event with provider, HTTP outcome (`blocked`, `not sent`, status, or `id unread`), sanitised error code and file id. No file name, MIME type, prompt or provider message is logged.
- OpenAI, Azure OpenAI, Custom LLM, Anthropic and Google call `AcceptFiles` before any provider HTTP call, so a GIF and an oversize file are refused on those providers the same way as on xAI. Files the policy accepts keep each provider's existing inline wire format. Codeunit 10035418 `xAI LangModel Prov. ori` uses the same gate and, for a document, the upload and delete path on the Responses API (`store` false). Text-only calls still use `/v1/chat/completions`. Copilot still refuses every file.
- Codeunit 10035411 `LangModel API Client ori` uploads and deletes provider files. `KeepOnlySafeProviderCode` keeps a sanitised error code for every non-2xx status, matching the live HTTP readers. `WriteProviderFileUpload` is non-debuggable. A 2xx upload without a readable file id is returned as `storedWithoutId` so the shared handler can log it.
- Codeunit 10035410 `LangModel Prov. Base ori` and codeunit 10035396 `LLM Prompt Compl Impl ori`: a provider HTTP 4xx answer carries the HTTP status and that short code. An unsupported image is `InvalidParameter` and names PNG and JPEG. An oversize file is `InvalidParameter` on `file`. The prompt notes and the `mimeType` parameter describe the shared path, including temporary provider storage. The new user-facing labels have Icelandic text.
- Test codeunits 96033 `LLM 65 HTTP Mock`, 96034 `LLM 65 Prompt Tests` and 96011 `LangModel API Client Tests` cover the shared MIME policy, inline PNG and JPEG, PDF upload and delete, delete after a failed prompt, unread upload id, oversize refusal, stored attachments, GIF and `image/jpg` refusal, safe 4xx and 5xx codes, unchanged text-only xAI and the other providers, and the multipart upload body. The tests use the HTTP double and do not call a live provider.
- Codeunit 10035427 `LangModel Wizard Mgt ori` and test codeunit 96038 `LangModel Wizard Users Tests` declare the in-memory security-group buffers with the `temporary` keyword. The public procedure and its behavior are unchanged.
- The shared-container publish retry treats HTTP 422 for the same package ID and version as already published. A Test republish whose first request lands and then times out no longer fails the later attempts. A different version still fails.
- Codeunit 10035411 `LangModel API Client ori` procedures `KeepOnlySafeProviderCode` and `ReadProviderResponse`, and codeunit 10035410 `LangModel Prov. Base ori` procedure `SanitizeProviderErrorCode`, are non-debuggable. They read a failed provider body only to keep the sanitised code.

### Fixed (2026-10-28) - Test tool request contracts (#89)

- Test-only message types `Test.LanguageModel.Set`, `.Delete` and `.Chat` (#89; enum extension 96023 and codeunits 96024–96026) now declare their request parameters and real effects through Foundation's `Msg Contract ori`. This restores dispatch on Foundation 28.0.10+; Set covers both top-level models and batch entries, Delete declares its writes, and Chat declares committed tool/provider effects with the matching inbound direction. Codeunit 96028 covers contract mappings and rejection of undeclared request keys. Shipped app code is unchanged.

### Fixed (2026-10-28) - RegisterApps subscriber InherentPermissions X (#91)

- Codeunit 10035423 `LangModel Registration ori` now declares `InherentPermissions = X` and `InherentEntitlements = X`, matching Foundation's App Registry subscriber pattern, so a restricted licence administrator can open Bifrost Setup when Language Models is installed.
- Test codeunit 96016 `LangModel Registration Tests` opens Bifrost Setup as `BIFROST LicAdm ori` with test permission set 96039 `LM Setup Base ori` and asserts the page opens non-editable with Language Models still in the registry.

### Added (2026-10-27) - Request time in the Copilot system prompt (#85)

- Codeunit 10035393 `Copilot Chat Proxy ori` appends a `SESSION TIME` block immediately after Foundation's `Bootstrap`, only if Foundation did not already add that marker. It refreshes on every request and includes UTC, resolved user time and offset, local date and English weekday, a differing work date and explicit relative-period/filter rules. Unknown time zones are explicitly reported as UTC. No extra tool or HTTP call is made. English locked labels are model instructions, with no new captions or XLF changes.
- Existing test codeunit 96029 `LangModel Chat Proxy Tests` exercises the production builder with fixed inputs, including midnight/month/leap-day boundaries, locale independence, unknown zones, work-date conditions, marker idempotence and data minimization. No new objects or public signature changes to released procedures.
- Line separators use `TextBuilder.AppendLine`, avoiding the AL0620 error caused by unsupported `#10` literals.

### Fixed (2026-10-23) - Setup wizard user grid and Icelandic captions (#82)

- Page 10035428 `LangModel Wizard Users ori` uses translated permission-column captions and keeps the permission set identifiers in the tooltips. Codeunit 10035427 `LangModel Wizard Mgt ori` loads the two sets' company/global Access Control rows and company user-model choices once, then preserves inherited grants through the platform Security Group membership API. Incomplete directory retrieval falls back to the existing effective-permission helper. Row rendering uses in-memory lookups and explicit commands refresh the snapshot.
- Page 10035345 `LangModel Setup Wizard ori` consistently uses "Copilot og eiginleikar fulltrúa" in Icelandic actions, help, status and tooltips; the Icelandic XLF is regenerated.
- Test codeunit 96038 `LangModel Wizard Users Tests` and test permission set 96038 `LM Wizard Read ori` cover independent permission flags, company/global scope, app identity, model display, snapshot refresh, inherited membership and revocation, inherited company/app boundaries, and indirect read access without security-administration authority. Permission set 10035404 `BIFROST LLM ori` permits execution of the platform Security Group reader without granting security-administration writes. Existing public procedures and fields and existing test assertions are retained.

### Added

- Language Models assisted setup (#80): page 10035345 `LangModel Setup Wizard ori`, codeunits 10035426–10035427 `LangModel Wizard Reg. ori` / `LangModel Wizard Mgt ori`, and user-selection ListPart page 10035428 `LangModel Wizard Users ori`. The wizard reads this app's HTTP status and opens Foundation's setup wizard to enable HTTP for all registered Bifrost apps, shows Copilot capability status and initialization, preserves existing chat provider ownership, and assigns company-scoped chat permissions and per-user language models. Explicit Finish completes Assisted Setup; an entirely unconfigured setup cannot be completed.
- Page 10035421 `LangModel Setup ori` opens the app-specific wizard and retains a separate Foundation setup wizard action. Permission set 10035404 grants the new objects without granting security-administration or extension-setting write permission. English/Icelandic texts and XLF are maintained. Test codeunit 96037 `LangModel Setup Wizard Tests` covers registration, commands, invalid input, idempotency, and completion.

### Changed (2026-10-21) - Message type contract and discovery at Foundation parity

- Codeunit 10035396 `LLM Prompt Compl Impl ori` (`LLM.Prompt.Complete`): the contract now follows Bifrost Foundation's standard. Envelope adds the root `strict` option and drops the empty subject forms; `file` and `attachment` declare their children (`data`, `mimeType`, `fileName`; `table` with its two allowed names, `systemId`); the response declares `type` and `usage`, which the Anthropic provider returns; the errors chapter adds the uncaught `BusinessCentralError` (for example an unsupported message version); the effect states what is really written (the API key's Last Used On stamp, at most once a day), that the data sent to the provider cannot be recalled and that the type does not commit, and its preconditions are a list; the examples are complete requests with `type` and `data` and add an inline file and a stored attachment; overview and notes state the file and provider behaviour (images as images, Copilot refuses files, the answer is free text to validate). Behaviour of the call is unchanged.
- The description now starts with a third-person verb ("Sends one prompt ...", 20 to 200 characters, as Foundation's conformance rules require). The selection description says "Read-only." and names `Data.Records.Get` for prompts that need Business Central data. Five search terms are added in English and Icelandic (mállíkan, LLM, spyrja gervigreind, lesa skjal með gervigreind, lesa mynd með gervigreind). The three labels and `Bifrost Language Models.is-IS.xlf` are updated; the label ids are unchanged.
- New test codeunit 96036 `LangModel Contract Compl Tests` walks every message type of this app (ordinals 10035335 to 10035484) and fails when a required chapter is missing, an errors entry has no code, condition or next step, an example has no request `type` or response, the effect is not read, write or irreversible or the direction does not match it, the description breaks Foundation's wording rules, the discovery texts are missing, equal to each other or untranslated, or a number of this app's object range appears in public text. Existing tests are unchanged.

### Changed (2026-10-20) - AppSource delivery (#67)

- `.AL-Go/settings.json`: `deliverToAppSource` names the Partner Center offer (productId 30b2edcf-bfaf-48ef-94d9-4732fb9eabd1, main app folder `app`, branch main, no continuous delivery), so the Publish To AppSource workflow can deliver updates.

## [28.0.0.0] - 2026-10-19

### Changed (2026-10-19) - Icelandic translation review for AppSource

- Icelandic texts corrected in 12 objects: hyphenated compounds with foreign names (`Copilot-líkanið`, `HttpClient-köll`, `MCP-verkfæraþjónn`, `API-endapunktsslóð`), the Business Central field name "Leyfa HttpClient-beiðnir", "Auðkenning" instead of "Sannvottun" on the language model card, "móttekið skjal" for incoming documents (as in Foundation) and readable permission guidance in `LLM.Prompt.Complete` errors. English texts are unchanged. Every one of the 316 translatable texts has an Icelandic translation; the XLF is regenerated. Test codeunit 96034 asserts the new blocked-HTTP wording.

### Fixed (2026-10-14) - Safe one-shot provider failures (#65)

- `LLM.Prompt.Complete` (codeunit 10035396) rejects non-string prompts with `InvalidParameterFormat`. All six external providers return coded authentication, blocked HTTP and retryable transport errors with next steps; provider error bodies and API-key fragments are never returned or logged by this path. Success `reply`/`text` behavior is preserved, including inline and stored files.
- The shared safe transport and error contract are in codeunits 10035411/10035410. Completion paths in codeunits 10035413–10035415 and 10035417–10035419 use them; chat and model-list operations retain their existing behavior. English/Icelandic error help and XLF are updated. Both manifests require Foundation 28.0.4.0 for `Retryable`; product/test top-level versions are unchanged.
- Test codeunits 96034/96033 cover prompt dispatch for six providers, authentication/rate/server/timeout/blocked errors, secret-fragment rejection, debug logging, prompt types, success/files and restricted chat permissions.
- Issue #65 prompt tests use codeunit 96034 to avoid the independent permission-test codeunit 96032 in PR #66; all existing assertions remain unchanged.
- After integrating #66, codeunit 96032 verifies coded `Error`/`PermissionDenied` instead of a thrown platform error in both LCIDs 1033/1039. The dispatcher receives each LCID explicitly. The negative cases assert the Foundation chat grant, absent model-read permission, localized refusal, actionable permission-set guidance and no provider call.
- AC7 tests in codeunit 96034 explicitly name the Foundation API transport baseline and assert that it grants neither the Chat Gate nor language-model read. The positive test adds both chat permission sets; Foundation transport permissions remain unchanged.

- AC8: codeunit 10035396 now gives every errors-chapter string an Icelandic translator comment. Foundation #777 intentionally renders Help chapter prose in English at both LCIDs 1033/1039; runtime error labels remain localized. Codeunit 96034 covers English/Icelandic authentication, retry, blocked HTTP, provider failure and prompt-validation labels and next steps.

### Fixed (2026-10-15) - Missing API key instruction (#70)

- Page 10035343 `Bifrost LangModel Card ori` places the missing-key instruction in a conditional group so the Web Client renders the localized instruction on saved keyless models. The hint remains hidden when either a personal or shared key is stored, or the provider needs no key. Existing captions and translations are preserved. Test codeunit 96035 `LangModel Hint Tests` covers English/Icelandic, read/edit modes and both key scopes; rendered browser checks cover the client layout.

### Changed (2026-10-14) - AppSource readiness metadata (#66)

- The app links to the documentation, privacy statement and licence terms on docs.bifrost.origo.is. The Copilot capability's Learn more link in codeunit 10035390 `Copilot Install ori` points to the Language Models documentation.
- Permission set 10035398 `BIFROST LLM Chat ori` now also grants read on the language model table, so a user with that set and Foundation's `BIFROST Chat ori` can run `LLM.Prompt.Complete` without a permission error.
- The enum extension that registers Language Models as a chat provider is renamed `LangModel Chat Prov Type ori` (id 10035384 unchanged) so every object carries the `ori` affix. It is part of the first release, so nothing that was published is affected.
- Foundation's `BIFROST Full ori` and `BIFROST Read ori` roles now include the Language Models objects through permission set extensions 10035426 `BIFROST LLM Full ori` and 10035427 `BIFROST LLM Read ori`, so administrators and readers need no second assignment.
- New test codeunit 96032 `LLM Prompt Compl Perm Tests` covers restricted chat permissions. Changed test codeunit 96001 `Mock Bifrost Chat Provider` supports the permission regression tests.

### Fixed (2026-10-16) - Locale-independent test assertions (#73)

- Test codeunits 96002, 96004, 96009 and 96018 compare chat errors, endpoint hints, missing-model errors and Copilot confirmation/success messages against translated expected labels in the active session language. The test app includes Icelandic translations for those labels. Codeunit 96019 reads English discovery text under LCID1033 and restores the caller's language before assertions, including when discovery raises an error. Product source and test coverage remain unchanged.

- Keep the expected Icelandic labels in test codeunits 96002 and 96018 synchronized with the reviewed product wording from #64 after merging main.

### Fixed (2026-10-15) - Preserve the Bifrost pipeline (PR #57)

- Added `.github/workflows/BifrostPipeline.yaml` and `tools/Test-BifrostPipeline.ps1` to verify sequential Default/Test builds, shared physical container identity, Test production-app republishing, Default internals stripping, signing requests, deferred cleanup, merged settings before secrets, and Test-only upgrade skipping. `AGENTS.md` records these preservation requirements for system updates.
- `.AL-Go/settings.json` selects a full paired Default/Test build for `.github/workflows/**`, `tools/Test-BifrostPipeline.ps1` and `app/Translations/*.xlf` changes.
- `LangModel Chat Provider Tests` (codeunit 96002) closes the real customer page, deletes its fixture and restores routing before expected assertion errors can roll back the customer. The wrong-table, wrong-SystemId and wrong-caption checks still reject incorrect context and recheck the original captured values.

### Added (2026-10-15) - AppSource offer texts

- Added English and Icelandic Partner Center listing texts in `appsource/offer/`, including summaries, descriptions, search keywords, links and screenshot descriptions. Refs #67.

### Changed (2026-10-14) - Icelandic translations reviewed for AppSource (#64)

- The Icelandic (is-IS) texts were reviewed for AppSource: the texts in 33 objects now follow the Business Central glossary (core#702), for example heimildasamstæða, viðskiptamaður, kreditreikningur, Sannvottun, skilaboðategund and tákn. The API key actions on the language model card now read "Setja inn persónulegan API-lykil" and "Setja inn sameiginlegan API-lykil", and the missing-key hints use the same wording. English texts, logic and object IDs are unchanged. Changed objects:
  - Pages: 10035342 `Bifrost Chat Model List ori`; 10035343 `Bifrost LangModel Card ori`; 10035344 `Bifrost LangModel List ori`; 10035421 `LangModel Setup ori`.
  - Page extensions: 10035347 `Bifrost Chat CustomerList ori`; 10035356 `Bifrost Chat IncomingDocs ori`; 10035359 `Bifrost Chat ItemList ori`; 10035361 `Bifrost Chat PurchCrMemos ori`; 10035364 `Bifrost Chat PurchOrders ori`; 10035366 `Bifrost Chat PurchQuotes ori`; 10035367 `Bifrost Chat PurchInvoices ori`; 10035369 `Bifrost Chat PurchRetOrds ori`; 10035371 `Bifrost Chat SalesCrMemos ori`; 10035374 `Bifrost Chat SalesOrders ori`; 10035376 `Bifrost Chat SalesQuotes ori`; 10035377 `Bifrost Chat SalesInvoices ori`; 10035379 `Bifrost Chat SalesRetOrds ori`; 10035381 `Bifrost Chat VendorList ori`; 10035402 `User Setup Editor LangMdl ori`.
  - Codeunits: 10035382 `LangModel Chat Provider ori`; 10035385 `Copilot LangModel Prov. ori`; 10035389 `Bifrost LangModel None ori`; 10035390 `Copilot Install ori`; 10035396 `LLM Prompt Compl Impl ori`; 10035412 `LangModel Chat Proxy ori`; 10035414 `Azure OAI LangModel Prov. ori`; 10035422 `LangModel Secrets ori`.
  - Tables: 10035335 `Bifrost Language Model ori`; 10035337 `Bifrost Chat Argument ori`; 10035406 `Chat Svc Gate ori`.
  - Enums: 10035338 `Bifrost Chat Proc. Type ori`.
  - Permission sets: 10035405 `BIFROST LLM Rd ori`; 10035407 `BIFROST ChatSvc ori`.

### Fixed (2026-10-13) - OpenAI endpoint defaults (#60)

- Selecting OpenAI on the language model card fills an empty `Base URL` with `https://api.openai.com/`. `Chat Path` and `Models Path` remain unchanged, including when empty: the provider already appends its endpoint paths. Existing Azure OpenAI and proxy values are preserved; other providers are unchanged. Table 10035335 `Bifrost Language Model ori`; page 10035343 `Bifrost LangModel Card ori` saves the validated provider/defaults before refreshing its fields and waits for the skill editor’s `ControlReady` before refreshing it, so the same card validation can run before the add-in is instantiated. Regression tests in codeunit 96031 `LangModel 60 Defaults Tests` exercise card selection, partial configurations, repeated selection and table validation.

- OpenAI requests normalize surrounding whitespace and trailing slashes from the resolved base URL before adding chat, responses and models paths; stored default/custom values stay unchanged. Whitespace-only Base URL now defaults on OpenAI selection. Codeunit 10035410 `LangModel Prov. Base ori`; table 10035335; codeunits 10035413 `OpenAI LangModel Prov. ori` and 10035412 `LangModel Chat Proxy ori` expose their internal runtime endpoint builders to codeunit 96031, which checks default/custom hosts, custom chat paths and whitespace. Both apps remain Cloud.

- Shared endpoint joining now inserts exactly one slash between base and path and avoids repeating `/v1` when the base ends in `/v1` or `/v1/`. OpenAI chat, completions, responses and model discovery plus configured Azure chat/models paths use codeunit 10035410; stored values remain unchanged. Codeunits 10035413, 10035412 and 10035414 delegate to that helper. Codeunit 96031 covers versioned bases, paths without leading slashes, multiple join slashes and segment-boundary preservation. No new labels or translation changes.

### Changed (2026-10-11) - CI compiles against BC 28.5

- Current (pull requests, CI/CD, and the Test Current workflow) uses sandbox artifact `28.5.54151.55751` (w1). `.AL-Go/settings.json` and `.github/Test Current.settings.json` set `artifact` to `/sandbox/28.5.54151.55751/w1/latest`. `fullBuildPatterns` already lists `.AL-Go/settings.json`. Next Minor and Next Major stay on `////nextminor` and `////nextmajor`.
- The two `TryGetApiKey` priority tests now follow the stamp-after-call design. `TryGetApiKey` has been read-only since 2a8421a (#53), and both tests have failed on main since then, on BC 29 as well as 28.5. The read leaves `Last Used On` at 0DT; `MarkApiKeyUsed` stamps the key that was used.

### Fixed (2026-10-10) - Bounded canonical verification repairs

- The 14 list chat actions (pageextensions 10035347, 10035356, 10035359, 10035361, 10035364, 10035366–10035367, 10035369, 10035371, 10035374, 10035376–10035377, 10035379 and 10035381) delegate to `LangModel Chat Provider ori` (codeunit 10035382), preserving the original table, SystemId, caption, visibility and promoted actions. Purchase Orders/Return Orders preserve their existing Purchase Header table number with Purchase Line identity; this change does not repair that legacy semantic mismatch.
- `Copilot Install ori` (codeunit 10035390) owns confirmation and initialization orchestration called by `Bifrost LangModel List ori` (page 10035344). The same two Icelandic labels move to the codeunit without changing their text.
- The default model lookup in codeunit 10035382, `CountModelsWithoutKey` in `LangModel Secrets ori` (codeunit 10035422), and the read-only `ChatSvcGate Tests` probe (codeunit 96013) use local read isolation.
- `LangModel Chat Provider Tests` (96002), `Copilot Install Tests` (96018) and `LangModel Secrets Tests` (96009) cover real page actions, forwarding arguments, cancellation, errors and empty/key-scope cases. `LangModel Context Spy ori` (new test codeunit 96030) observes value arguments after the real setter; it does not inspect Foundation private state or rendered captions.

### Fixed (2026-10-10) - Verification coverage and documentation

- `LangModel Field Restrict ori` (codeunit 10035408) now has the Icelandic endpoint-edit hint in the committed XLF; `Bifrost Chat Proc. Type ori` (enum 10035338) preserves its intentionally blank caption without a review placeholder.
- Existing app/test object and procedure summaries are attached to their declarations without changing executable tokens, including the 36 chat page extensions (10035346–10035381). `Chat Svc Gate Tests` (codeunit 96013) describes its read-only absence assertion. README lists each app object and explains the existing request and credential flow.
- `.AL-Go/settings.json` enables product CodeCop/UICop and test-app analyzers. Warnings now fail CI; existing AppSourceCop affixes, signing policy and Default/Test separation are preserved. The only new object is test codeunit 96030.

### Fixed (2026-10-10) - Deferred API key usage test coverage

- Codeunit 96009 `LangModel Secrets Tests` now verifies that API key retrieval leaves usage timestamps unchanged and that explicit `MarkApiKeyUsed` stamps the personal key or shared fallback. Added missing-key and blank-code controls. Product behavior and deployment paths are unchanged.

### Fixed (2026-10-10) - UAT dependency installation

- UAT feature-app deployment uses the Foundation app already deployed by its own pipeline in Dev scope, avoiding an unauthorized AppSource Foundation installation. `.github/AL-Go-Settings.json`: `DeployToBifrost.DependencyInstallMode = "ignore"`. AppSource delivery is unchanged; no AL objects or IDs change.

### Fixed (2026-10-05) - The chat failed whenever an API key had not been used yet that day

- `LangModel Secrets ori.TryGetApiKey` stamped the key as used on Bifrost App Secrets (a write, once a day per key) before the provider call. Foundation's `Bootstrap` then runs message types through `Codeunit.Run`, which the platform refuses in an open write transaction, so the first chat of the day failed with *An error occurred and the transaction is stopped*, and the rolled-back stamp made every later attempt fail the same way. `TryGetApiKey` now only reads; the new `MarkApiKeyUsed` stamps the key after the provider call (chat send and continue, `LLM.Prompt.Complete`). Found by the live chat test through `Test.LanguageModel.Chat` on bc28-is.

### Fixed (2026-10-05) - Reasoning models refused tool calls (Azure OpenAI, OpenAI)

- A reasoning model such as Azure OpenAI `gpt-6-sol` answers 400 *Function tools with reasoning_effort are not supported ... set reasoning_effort to 'none'* when a chat request carries tools. The OpenAI-compatible chat proxy resends that request once with `reasoning_effort: "none"`; a model that does not know the parameter never receives it. After that first refusal, later tool rounds and the figure-check follow-up of the same turn send `reasoning_effort: "none"` on the first try. Verified live on Azure OpenAI (`/openai/v1/chat/completions`, `gpt-6-sol`): two tool rounds and the right answer.

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

### Changed (2026-10-12) - Retry eligibility test documentation

- `LangModel Chat Proxy Tests` (codeunit 96029) now documents its four retry-eligibility assertions: matching error with tools, no tools, reasoning effort already set, and an unrelated error. Test behavior is unchanged.

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
