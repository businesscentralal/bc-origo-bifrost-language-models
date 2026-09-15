namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

/// <summary>
/// Registers Language Models as a chat provider implementation on Bifrost Foundation's
/// "Chat Provider Type ori" enum. See "Copilot Install ori" for how
/// "Setup ori"."Chat Provider Type" is claimed on install.
/// </summary>
enumextension 10035384 "LangModel Chat Provider Type" extends "Chat Provider Type ori"
{
    value(10035384; LanguageModels)
    {
        Caption = 'Bifrost Language Models', Comment = 'is-IS=Bifröst mállíkön';
        Implementation = "Chat Provider ori" = "LangModel Chat Provider ori";
    }
}
