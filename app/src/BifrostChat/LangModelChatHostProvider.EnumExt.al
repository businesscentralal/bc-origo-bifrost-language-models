namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

/// <summary>
/// Registers Language Models as a chat host implementation on Bifrost Foundation's
/// "Chat Host Provider ori" enum. See "Copilot Install ori" for how
/// "Setup ori"."Chat Host Provider" is claimed on install.
/// </summary>
enumextension 10035384 "LangModel Chat Host Provider" extends "Chat Host Provider ori"
{
    value(10035384; LanguageModels)
    {
        Caption = 'Bifrost Language Models', Comment = 'is-IS=Bifröst mállíkön';
        Implementation = "Chat Host ori" = "LangModel Chat Host ori";
    }
}
