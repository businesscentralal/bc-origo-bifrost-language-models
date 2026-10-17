namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

/// <summary>
/// Adds read access to the Language Models objects to Foundation's "BIFROST Read ori" role. The grants match the assignable "BIFROST LLM Rd ori" set.
/// Foundation-owned objects (chat pages, chat codeunits, MCP tool server, secret store) are already granted by its own role sets.
/// </summary>
permissionsetextension 10035427 "BIFROST LLM Read ori" extends "BIFROST Read ori"
{
    Permissions =
        table "Bifrost Language Model ori" = X,
        tabledata "Bifrost Language Model ori" = R,
        table "Bifrost Chat Argument ori" = X,
        // RIMD, not R: "Bifrost Chat Argument ori" is TableType = Temporary — the in-memory DTO of
        // the provider interface. Every provider writes its output fields back into the record the
        // caller passed in, so read-only users need the same insert/modify rights on it as anyone
        // else. No row ever reaches the database.
        tabledata "Bifrost Chat Argument ori" = RIMD,
        page "Bifrost Chat Model List ori" = X,
        page "Bifrost LangModel Card ori" = X,
        page "Bifrost LangModel List ori" = X,
        page "LangModel Setup ori" = X,
        codeunit "LangModel Chat Provider ori" = X,
        codeunit "LangModel Secrets ori" = X,
        codeunit "Bifrost LangModel None ori" = X,
        codeunit "Bifrost LangModel Test Ctx ori" = X,
        codeunit "Copilot AOAI Func Impl ori" = X,
        codeunit "Copilot Chat Proxy ori" = X,
        codeunit "LangModel Turn Guard ori" = X,
        codeunit "Copilot Default Skill ori" = X,
        codeunit "Copilot LangModel Prov. ori" = X,
        codeunit "Copilot Req Log Masker ori" = X,
        codeunit "LLM Prompt Compl Impl ori" = X;
}
