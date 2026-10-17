namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

/// <summary>
/// Adds the Language Models objects to Foundation's "BIFROST Full ori" role, so a Bifröst administrator gets them without a second assignment. The grants match the assignable "BIFROST LLM ori" set. Write access to the Chat Gate and the shared-key gate stay separate ("BIFROST Chat ori", "BIFROST ChatSvc ori").
/// Foundation-owned objects (chat pages, chat codeunits, MCP tool server, secret store) are already granted by its own role sets.
/// </summary>
permissionsetextension 10035426 "BIFROST LLM Full ori" extends "BIFROST Full ori"
{
    Permissions =
        table "Bifrost Language Model ori" = X,
        tabledata "Bifrost Language Model ori" = RIMD,
        table "Bifrost Chat Argument ori" = X,
        // RIMD, not R: "Bifrost Chat Argument ori" is TableType = Temporary — the in-memory DTO of
        // the provider interface. Every provider writes its output fields back into the record the
        // caller passed in. No row ever reaches the database.
        tabledata "Bifrost Chat Argument ori" = RIMD,
        page "Bifrost Chat Model List ori" = X,
        page "Bifrost LangModel Card ori" = X,
        page "Bifrost LangModel List ori" = X,
        page "LangModel Setup ori" = X,
        codeunit "LangModel Chat Provider ori" = X,
        codeunit "LangModel Registration ori" = X,
        codeunit "LangModel Secrets ori" = X,
        codeunit "Bifrost LangModel None ori" = X,
        codeunit "Bifrost LangModel Test Ctx ori" = X,
        codeunit "Copilot AOAI Func Impl ori" = X,
        codeunit "Copilot Chat Proxy ori" = X,
        codeunit "LangModel Turn Guard ori" = X,
        codeunit "Copilot Default Skill ori" = X,
        codeunit "Copilot Install ori" = X,
        codeunit "Copilot LangModel Prov. ori" = X,
        codeunit "Copilot Req Log Masker ori" = X,
        codeunit "Copilot Upgrade ori" = X,
        codeunit "LLM Prompt Compl Impl ori" = X;
}
