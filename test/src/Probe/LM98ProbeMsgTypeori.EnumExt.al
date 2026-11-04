namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;

/// <summary>Test-app-only LM98 diagnostic entry point; excluded from the product app.</summary>
enumextension 96050 "LM98 Probe MsgType ori" extends "Message Type ori"
{
    value(96050; "Test.LanguageModel.AskProbe")
    {
        Caption = 'Test.LanguageModel.AskProbe', Locked = true;
        Implementation = "Msg Interface ori" = "LM98 Probe Impl ori",
                         "Msg Contract ori" = "LM98 Probe Impl ori";
    }
}
