namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;

/// <summary>
/// Test-only message types of the Language Models test app. They set up language models with their API keys and
/// run a full chat turn against one of them, so the chat of every provider can be verified through the task API or
/// the MCP server without the setup pages. They refuse to run in a SaaS production environment.
/// </summary>
enumextension 96023 "LangModel Test MsgType" extends "Message Type ori"
{
    value(96023; "Test.LanguageModel.Set")
    {
        Caption = 'Test.LanguageModel.Set', Locked = true;
        Implementation = "Msg Interface ori" = "Test LangModel Set Impl";
    }
    value(96024; "Test.LanguageModel.Delete")
    {
        Caption = 'Test.LanguageModel.Delete', Locked = true;
        Implementation = "Msg Interface ori" = "Test LangModel Delete Impl";
    }
    value(96025; "Test.LanguageModel.Chat")
    {
        Caption = 'Test.LanguageModel.Chat', Locked = true;
        Implementation = "Msg Interface ori" = "Test LangModel Chat Impl";
    }
}
