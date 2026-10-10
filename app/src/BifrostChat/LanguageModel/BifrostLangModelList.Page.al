namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

/// <summary>
/// List page for managing Bifrost Language Models.
/// Allows creating language models with code/description and editing skill content via action.
/// </summary>

page 10035344 "Bifrost LangModel List ori"
{
    Caption = 'Bifrost Language Models', Comment = 'is-IS=Bifröst mállíkön';
    ContextSensitiveHelpPage = 'bifrost-lang-model-list';
    PageType = List;
    Extensible = false;
    SourceTable = "Bifrost Language Model ori";
    ApplicationArea = All;
    UsageCategory = None;
    Editable = false;
    CardPageId = "Bifrost LangModel Card ori";

    layout
    {
        area(Content)
        {
            repeater(LanguageModels)
            {
                field("Code"; Rec."Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unique code for this language model.', Comment = 'is-IS=Tilgreinir einkvæman kóða þessa mállíkans.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies a description of what this language model does.', Comment = 'is-IS=Tilgreinir lýsingu á því hvað þetta mállíkan gerir.';
                }
                field(Default; Rec.Default)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether this is the default language model.', Comment = 'is-IS=Tilgreinir hvort þetta sé sjálfgefið mállíkan.';
                }
                field("Chat Provider"; Rec."Chat Provider")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the chat provider for this language model.', Comment = 'is-IS=Tilgreinir spjallveitandann fyrir þetta mállíkan.';
                }
                field(HasSkill; Rec.Skill.HasValue())
                {
                    ApplicationArea = All;
                    Caption = 'Has Skill', Comment = 'is-IS=Hefur hæfni';
                    ToolTip = 'Indicates whether this language model has skill content configured.', Comment = 'is-IS=Gefur til kynna hvort þetta mállíkan hafi hæfniefni stillt.';
                    Editable = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(InitCopilotDefaults)
            {
                ApplicationArea = All;
                Caption = 'Init Copilot Defaults', Comment = 'is-IS=Frumstilla Copilot sjálfgildi';
                ToolTip = 'Registers the Copilot capability with Microsoft billing, creates a default COPILOT language model if needed, and refreshes the default skill content.', Comment = 'is-IS=Skráir Copilot-getu með Microsoft-reikningagerð, býr til sjálfgefið COPILOT-mállíkan ef þarf og uppfærir sjálfgefið hæfniefni.';
                Image = Setup;

                trigger OnAction()
                var
                    CopilotInstall: Codeunit "Copilot Install ori";
                begin
                    if CopilotInstall.InitCopilotDefaults() then
                        CurrPage.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process', Comment = 'is-IS=Vinnsla';

                actionref(InitCopilotDefaults_Promoted; InitCopilotDefaults) { }
            }
        }
    }
}
