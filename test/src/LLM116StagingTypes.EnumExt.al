namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;

/// <summary>Test-only stand-in registration for the optional Attachments storage-to-staging path.</summary>
enumextension 96069 "LLM116 Staging Types" extends "Message Type ori"
{
    value(96069; "Storage.Upload.CommitToStaging")
    {
        Caption = 'Storage.Upload.CommitToStaging', Locked = true;
        Implementation = "Msg Interface ori" = "Test LangModel Chat Impl";
    }
    value(96070; "Test.LLM116.Probe")
    {
        Caption = 'Test.LLM116.Probe', Locked = true;
        Implementation = "Msg Interface ori" = "LLM116 Probe ori";
    }
}

