namespace Origo.Bifrost.LanguageModels;

using Origo.Bifrost;

/// <summary>
/// Opens Language Models setup from the Related menu of the Bifrost page.
/// </summary>
pageextension 10035448 "Bifrost LangModel ori" extends "Bifrost ori"
{
    ContextSensitiveHelpPage = 'language-models-setup';

    actions
    {
        addafter(BifrostSetup)
        {
            action(LangModelSetup)
            {
                ApplicationArea = All;
                Caption = 'Bifrost Language Models Setup', Comment = 'is-IS=Uppsetning Bifröst mállíkana';
                ToolTip = 'Open the setup page of Bifrost Language Models, with the models, the MCP tool server and the provider API keys.', Comment = 'is-IS=Opna uppsetningarsíðu Bifröst mállíkana, með líkönunum, MCP-verkfæraþjóni og API-lyklum veitenda.';
                Image = Setup;
                RunObject = page "LangModel Setup ori";
            }
        }
    }
}
