namespace Origo.Bifrost.LanguageModels;

/// <summary>Company-level options for anonymized daily compression.</summary>
table 10035442 "LLM Usage Setup ori"
{
    Caption = 'LLM Usage Setup', Comment = 'is-IS=Uppsetning mállíkananotkunar';
    DataClassification = SystemMetadata;
    Extensible = false;
    InherentPermissions = r;
    InherentEntitlements = r;
    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key', Comment = 'is-IS=Aðallykill';
        }
        field(2; "Compress After Days"; Integer)
        {
            Caption = 'Compress After Days', Comment = 'is-IS=Þjappa eftir daga';
            InitValue = 30;
            MinValue = 1;
            ToolTip = 'Specifies how many days of detailed calls to keep before compression.', Comment = 'is-IS=Tilgreinir hversu marga daga á að geyma nákvæmar kallfærslur fyrir þjöppun.';
        }
        field(3; "Keep User in Daily Totals"; Boolean)
        {
            Caption = 'Keep User in Daily Totals', Comment = 'is-IS=Geyma notanda í dagsamtölum';
            ToolTip = 'Specifies whether compressed rows retain the user identity. Off by default.', Comment = 'is-IS=Tilgreinir hvort þjappaðar færslur geymi auðkenni notanda. Sjálfgefið er slökkt.';
        }
    }
    keys { key(PK; "Primary Key") { Clustered = true; } }

    /// <summary>Creates the company setup with the default compression period when absent.</summary>
    internal procedure EnsureDefault()
    begin
        if Get() then
            exit;
        Init();
        "Compress After Days" := 30;
        Insert(true);
    end;
}
