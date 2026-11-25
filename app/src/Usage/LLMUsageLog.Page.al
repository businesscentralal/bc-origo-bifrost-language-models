namespace Origo.Bifrost.LanguageModels;

using System.DataAdministration;

/// <summary>Read-only call usage with standard filtering by date, model, user and source.</summary>
page 10035440 "LLM Usage Log ori"
{
    PageType = List;
    SourceTable = "LLM Usage Log ori";
    Caption = 'LLM Usage Log', Comment = 'is-IS=Notkunarskrá mállíkana';
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
                field("Called At"; Rec."Called At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies called at for the recorded calls.', Comment = 'is-IS=Tilgreinir tíma kalls fyrir skráð köll.';
                }
                field("Duration Ms"; Rec."Duration Ms")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies duration ms for the recorded calls.', Comment = 'is-IS=Tilgreinir lengd kalls fyrir skráð köll.';
                }
                field("Success"; Rec."Success")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies success for the recorded calls.', Comment = 'is-IS=Tilgreinir hvort kall tókst fyrir skráð köll.';
                }
                field("Error Code"; Rec."Error Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies error code for the recorded calls.', Comment = 'is-IS=Tilgreinir villukóða fyrir skráð köll.';
                }
                field("Usage Not Reported"; Rec."Usage Not Reported")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies usage not reported for the recorded calls.', Comment = 'is-IS=Tilgreinir hvort notkun vanti fyrir skráð köll.';
                }
                field("Request Log Entry No."; Rec."Request Log Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies request log entry no. for the recorded calls.', Comment = 'is-IS=Tilgreinir færslunúmer beiðniskrár fyrir skráð köll.';
                }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(UsageGuide)
            {
                Caption = 'Usage guide', Comment = 'is-IS=Leiðbeiningar um notkun';
                ApplicationArea = All;
                Image = Help;
                ToolTip = 'Explains prices, missing usage, compression and standard retention policies.', Comment = 'is-IS=Útskýrir verð, vöntun táknanotkunar, þjöppun og staðlaðar varðveislureglur.';
                trigger OnAction()
                var
                    UsageHelp: Codeunit "LLM Usage Help ori";
                begin
                    UsageHelp.Show();
                end;
            }
            action(CompressUsage)
            {
                Caption = 'Compress usage', Comment = 'is-IS=Þjappa notkun';
                ApplicationArea = All;
                Image = Compress;
                ToolTip = 'Aggregates calls older than the configured period into daily totals and removes those detail rows.', Comment = 'is-IS=Leggur eldri köll saman í dagsamtöl og fjarlægir nákvæmar færslur þeirra.';
                AccessByPermission = tabledata "LLM Usage Daily ori" = M;
                trigger OnAction()
                var
                    Compression: Codeunit "LLM Usage Compression ori";
                begin
                    Compression.Compress();
                    CurrPage.Update(false);
                end;
            }
            action(DailyTotals)
            {
                Caption = 'Daily totals', Comment = 'is-IS=Dagsamtöl';
                ApplicationArea = All;
                Image = Statistics;
                RunObject = page "LLM Usage Daily ori";
                ToolTip = 'Opens compressed daily usage, separated by model and currency.', Comment = 'is-IS=Opnar þjappaða daglega notkun eftir mállíkani og gjaldmiðli.';
            }
            action(UsageSetup)
            {
                Caption = 'Compression setup', Comment = 'is-IS=Uppsetning þjöppunar';
                ApplicationArea = All;
                Image = Setup;
                RunObject = page "LLM Usage Setup ori";
                ToolTip = 'Specifies the age and user-identity options for compression.', Comment = 'is-IS=Tilgreinir aldur og varðveislu notanda við þjöppun.';
            }
            action(RetentionPolicies)
            {
                Caption = 'Retention policies', Comment = 'is-IS=Varðveislureglur';
                ApplicationArea = All;
                Image = Setup;
                RunObject = page "Retention Policy Setup List";
                ToolTip = 'Opens standard retention policies. Default usage policies are disabled until an administrator enables them.', Comment = 'is-IS=Opnar staðlaðar varðveislureglur. Sjálfgefnar reglur notkunar eru óvirkar þar til stjórnandi virkjar þær.';
            }
        }
    }
}
