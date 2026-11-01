namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;

/// <summary>Nonshipping LM98 trial entry point; never include this branch in a release.</summary>
enumextension 96050 "LM98 Probe MsgType ori" extends "Message Type ori"
{
    value(96050; "Test.LanguageModel.AskProbe")
    {
        Caption = 'Test.LanguageModel.AskProbe', Locked = true;
        Implementation = "Msg Interface ori" = "LM98 Probe Impl ori",
                         "Msg Contract ori" = "LM98 Probe Impl ori";
    }
}
