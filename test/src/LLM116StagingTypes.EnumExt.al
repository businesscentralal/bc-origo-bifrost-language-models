namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;

/// <summary>Test-only message registration for the owned staging attachment probe.</summary>
enumextension 96069 "LLM116 Staging Types" extends "Message Type ori"
{
    value(96070; "Test.LLM116.Probe")
    {
        Caption = 'Test.LLM116.Probe', Locked = true;
        Implementation = "Msg Interface ori" = "LLM116 Probe ori";
    }
}

