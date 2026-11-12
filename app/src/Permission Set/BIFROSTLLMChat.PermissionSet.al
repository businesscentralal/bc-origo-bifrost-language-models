namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

/// <summary>
/// Grants Language Models chat-provider capability (provider codeunits + secrets).
/// Named "BIFROST LLM Chat ori" so it does not collide with Foundation's "BIFROST Chat ori"
/// (the Chat Gate write licence). Assign Foundation's "BIFROST Chat ori" together with this set
/// so a user can open chat. Also grants read on the Bifrost Language Model table, which chat and
/// LLM.Prompt.Complete read to resolve the model. Not bundled into Bifrost Read or Bifrost Full.
/// </summary>
permissionset 10035398 "BIFROST LLM Chat ori"
{
    Assignable = true;
    Caption = 'Bifrost LLM Chat', MaxLength = 30, Comment = 'is-IS=Bifröst LLM-spjall';

    Permissions =
        codeunit "LLM Staging Files ori" = X,
        tabledata "Bifrost Language Model ori" = R,
        tabledata "LangModel Ask Setup ori" = R,
        codeunit "LangModel Secrets ori" = X,
        codeunit "Secret Store ori" = X,
        codeunit "LangModel Prov. Base ori" = X,
        codeunit "LangModel API Client ori" = X,
        codeunit "LangModel File Handling ori" = X,
        codeunit "LangModel Chat Proxy ori" = X,
        codeunit "LangModel Turn Guard ori" = X,
        codeunit "LLM Ask Tool Policy ori" = X,
        codeunit "LLM Session Time ori" = X,
        codeunit "LLM Ask Runner ori" = X,
        codeunit "MCP Tool Server ori" = X,
        codeunit "Anthropic LangModel Proxy ori" = X,
        codeunit "OpenAI LangModel Prov. ori" = X,
        codeunit "Azure OAI LangModel Prov. ori" = X,
        codeunit "Custom LLM LangModel Prov. ori" = X,
        codeunit "Anthropic LangModel Prov. ori" = X,
        codeunit "xAI LangModel Prov. ori" = X,
        codeunit "Gemini LangModel Prov. ori" = X,
        codeunit "LLM Req Log Masker ori" = X;
}
