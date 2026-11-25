namespace Origo.Bifrost.LanguageModels;

using System.DataAdministration;

/// <summary>Read-only daily totals with standard filtering by date, model, user and source.</summary>
page 10035441 "LLM Usage Daily ori"
{
    PageType = List;
    SourceTable = "LLM Usage Daily ori";
    Caption = 'LLM Daily Usage', Comment = 'is-IS=Dagleg mállíkananotkun';
    ApplicationArea = All;
    UsageCategory = Administration;
    Extensible = false;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    ContextSensitiveHelpPage = 'bifrost-lang-model-card';
    layout
    {
        area(Content)
        {
            repeater(Entries)
            {
                field("Call Date"; Rec."Call Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies call date for the recorded calls.', Comment = 'is-IS=Tilgreinir dagsetningu kalls fyrir skráð köll.';
                }
                field("Company"; Rec."Company")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies company for the recorded calls.', Comment = 'is-IS=Tilgreinir fyrirtæki fyrir skráð köll.';
                }
                field("Language Model Code"; Rec."Language Model Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies language model code for the recorded calls.', Comment = 'is-IS=Tilgreinir kóða mállíkans fyrir skráð köll.';
                }
                field("Provider"; Rec."Provider")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies provider for the recorded calls.', Comment = 'is-IS=Tilgreinir veitanda fyrir skráð köll.';
                }
                field("Model ID"; Rec."Model ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies model id for the recorded calls.', Comment = 'is-IS=Tilgreinir líkankenni fyrir skráð köll.';
                }
                field("Invocation Source"; Rec."Invocation Source")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies invocation source for the recorded calls.', Comment = 'is-IS=Tilgreinir uppruna kalls fyrir skráð köll.';
                }
                field("User Security ID"; Rec."User Security ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies user security id for the recorded calls.', Comment = 'is-IS=Tilgreinir öryggiskenni notanda fyrir skráð köll.';
                }
                field("Input Tokens"; Rec."Input Tokens")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies input tokens for the recorded calls.', Comment = 'is-IS=Tilgreinir inntakstákn fyrir skráð köll.';
                }
                field("Output Tokens"; Rec."Output Tokens")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies output tokens for the recorded calls.', Comment = 'is-IS=Tilgreinir úttakstákn fyrir skráð köll.';
                }
                field("Cached Tokens"; Rec."Cached Tokens")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies cached tokens for the recorded calls.', Comment = 'is-IS=Tilgreinir tákn úr skyndiminni fyrir skráð köll.';
                }
                field("Reasoning Tokens"; Rec."Reasoning Tokens")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies reasoning tokens for the recorded calls.', Comment = 'is-IS=Tilgreinir röksemdafærslutákn fyrir skráð köll.';
                }
                field("Cost"; Rec."Cost")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies cost for the recorded calls.', Comment = 'is-IS=Tilgreinir kostnað fyrir skráð köll.';
                }
                field("Currency Code"; Rec."Currency Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies currency code for the recorded calls.', Comment = 'is-IS=Tilgreinir gjaldmiðil fyrir skráð köll.';
                }
                field("Call Count"; Rec."Call Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies call count for the recorded calls.', Comment = 'is-IS=Tilgreinir fjölda kalla fyrir skráð köll.';
                }
                field("Error Count"; Rec."Error Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies error count for the recorded calls.', Comment = 'is-IS=Tilgreinir fjölda villna fyrir skráð köll.';
                }
            }
        }
    }
}
