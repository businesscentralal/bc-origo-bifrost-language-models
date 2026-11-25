namespace Origo.Bifrost.LanguageModels;

/// <summary>Configures usage compression; retention remains on the standard Retention Policies page.</summary>
page 10035442 "LLM Usage Setup ori"
{
    PageType = Card;
    SourceTable = "LLM Usage Setup ori";
    Caption = 'LLM Usage Setup', Comment = 'is-IS=Uppsetning mállíkananotkunar';
    ApplicationArea = All;
    UsageCategory = Administration;
    Extensible = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ContextSensitiveHelpPage = 'bifrost-lang-model-card';
    layout
    {
        area(Content)
        {
            group(Compression)
            {
                Caption = 'Compression', Comment = 'is-IS=Þjöppun';
                field("Compress After Days"; Rec."Compress After Days") { ApplicationArea = All; }
                field("Keep User in Daily Totals"; Rec."Keep User in Daily Totals") { ApplicationArea = All; }
            }
        }
    }
    trigger OnOpenPage()
    begin
        Rec.EnsureDefault();
    end;
}
