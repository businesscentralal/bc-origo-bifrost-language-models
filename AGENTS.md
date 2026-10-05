# Bifrost Language Models — Agent Context

This file gives AI agents the big-picture context needed to work in this repository correctly and safely.
Project rules (object ids, naming, secrets, setup) are in `.claude/CLAUDE.md`; read both.

---

## What This Extension Does

**Bifrost Language Models** connects Bifröst to language models. Bifrost Foundation owns the chat (control
add-in, FactBox and Focus pages, `Bifrost Chat Mgt ori`, the chat gate, the MCP Tool Server); this app supplies:

1. **Language models**: `Bifrost Language Model ori`, one row per model with provider, endpoint, limits,
   `Context Tokens` and a Markdown *skill* text. One model can be the default; users get one through
   **Language Model Code** on the Bifröst user setup.
2. **Providers**: the single-procedure interface `Bifrost LangModel Provider ori` with seven implementations
   (Copilot, OpenAI, Azure OpenAI, Custom LLM, Anthropic, xAI, Gemini), selected by the extensible enum
   `Bifrost LangModel Prov. ori`.
3. **The chat provider of Bifröst**: `LangModel Chat Provider ori` implements Foundation's `Chat Provider ori`
   (enum value `LanguageModels` on `Chat Provider Type ori`).
4. **The chat on 36 standard pages** through page extensions that add Foundation's FactBox.
5. **`LLM.Prompt.Complete`**: one-shot completions for playbooks and scheduled tasks, no tools, no state.

---

## Relationship to Bifrost Foundation

The app depends on Foundation **28.0.1.0** or later and uses only its public API (`internalsVisibleTo` in
Foundation names only Foundation's own test app). Foundation owns the extension points; this app supplies the
values:

| Foundation object | Extension in this app | Why |
| --- | --- | --- |
| enum `Message Type ori` | `LangModel Message Type ori` | `LLM.Prompt.Complete` |
| enum `Request Log Type ori` | `LangModel Req Log Type ori` | `Copilot` and `LLM` with their maskers |
| enum `Chat Provider Type ori` | `LangModel Chat Provider Type` | `LanguageModels` |
| table `User Setup ori` | `User Setup LangModel ori` | field `Bifrost Language Model Code` |
| page `User Setup Editor ori` | `User Setup Editor LangMdl ori` | the field and the chat FactBox |
| page `Setup ori` | `Setup LangModel ori` | the one **Bifrost Language Models** action |
| codeunit `App Registry ori` | `LangModel Registration ori` | one `OnRegisterApps` subscriber |
| table `Message Argument ori` events | `LangModel Field Restrict ori` | generic writes to the endpoint fields are refused |

**Never** ask for a change in Foundation that this app can make through an extension object, and never edit
`bc-origo-bifrost-core`. When the public surface is missing something, file a core issue naming the use case.

---

## Repository Structure

```
app/                          AppSource app "Bifrost Language Models" (Origo, range 10035335-10035484)
  src/
    BifrostChat/              LangModel Chat Provider, the model list lookup
      Copilot/                Copilot provider, chat proxy, AOAI function, masker, install, upgrade
      Extensions/             36 page extensions that add Foundation's chat FactBox to standard pages
      LanguageModel/          Bifrost Language Model table, Card/List pages, provider enum + interface, argument table
      Message Types/          LLM.Prompt.Complete implementation and contract chapters
    Extensions/               Extensions of Bifrost Foundation objects
    Providers/                Shared/ (base, API client, chat proxy, turn guard, service gate, masker) + one folder per provider
    Setup/                    LangModel Setup page, LangModel Secrets, LangModel Registration, LangModel Field Restrict
    Permission Set/           BIFROST LLM, BIFROST LLM Rd, BIFROST LLM Chat, BIFROST ChatSvc
  Translations/               is-IS.xlf, built by tools/Update-IcelandicXlf.ps1 (the g.xlf is not committed)
test/                         Test app "Bifrost Language Models - Tests" (range 96000-96199)
  src/                        Mocks: a language model provider (enum value Mock) and another chat provider
  test/                       BifrostChat/, Providers/, Setup/
tools/                        The source guards and xlf builder copied from Bifrost Foundation
```

Documentation is not kept in this repository. Product docs and in-product help live in `businesscentralal/bifrost`
(`docs/language-models/`, `help/language-models/`). Pages that may not be public yet wait in
`businesscentralal/bifrost-support` (`scratchpad/`).

---

## Core Architectural Concepts

### Provider dispatch

`LangModel Chat Provider ori` resolves the active language model (the user's **Language Model Code**; Bifrost
Chat is hidden without one), builds a `Bifrost Chat Argument ori` and calls the `Bifrost LangModel Provider ori`
interface. The interface has one method taking that temporary record; the operation is a
`Bifrost Chat Proc. Type ori` value on it, so new operations are enum values and existing providers keep compiling.

### The chat provider claim

`Copilot Install ori.ClaimChatProvider` (from install and from upgrade) calls Foundation's
`Setup ori.TryClaimChatProvider(LanguageModels)`, which carries its own inherent permissions. It claims only while
the value is `None` or already ours, never overriding another app or an administrator. No permission probe, no
telemetry (#34, #35).

### One chat turn (#40)

`LangModel Turn Guard ori` holds the rules every provider path applies: the history budget from the model's
context size (`Bifrost Language Model ori.GetContextTokens()`, provider default when 0), the repair of tool
messages whose partner was trimmed away, and one follow-up per turn when a reply states figures without any tool
call. The user's own prompt is carried once by Foundation's `Bootstrap`; providers must not append it.

### Errors

A message type answers `status = Error` through the coded `Argument.RespondWithError(code, message, parameter,
received, expected, nextStep)`, never an uncoded text. The contract's errors chapter uses the same labels as the
live answers (Foundation builds the chapters in English).

### Secrets and gates

API keys go through `LangModel Secrets ori` into Foundation's `Secret Store ori`, as `SecretText` all the way into
the HTTP header. Foundation's chat gate (`BIFROST Chat ori`) decides who may chat; `Chat Svc Gate ori`
(`BIFROST ChatSvc ori`) decides who may manage the shared key.

---

## Rules for Agents

- Namespace on line 1; `using Origo.Bifrost;` wherever a Foundation object is referenced.
- Object names are fixed. Renaming one is a breaking change for every tenant that has the app installed.
- New object ids come from 10035335-10035484 (tests 96000-96199); check `.claude/CLAUDE.md` and open PRs first.
- Every table, page and enum declares `Extensible`; new objects are `Extensible = false` unless another app extends them.
- Compile with CodeCop + UICop + AppSourceCop and accept nothing but zero errors and zero warnings. Run the guards
  in `tools/` before a PR.
- Implementation means code **and** tests **and** documentation. Publish and run the tests on bc28-w1 before
  calling anything done.
- Never print, log or store the `BC28IS_USER` / `BC28IS_PASSWORD` values.
