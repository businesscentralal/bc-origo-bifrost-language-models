namespace Origo.Bifrost.LanguageModels.Test;

/// <summary>One-row SQL source used only while the test installer creates the synthetic foreign-owner staging fixture.</summary>
table 96170 "LLM116 Fixture Seed ori"
{
    Access = Internal;
    Extensible = false;
    DataClassification = SystemMetadata;
    Caption = 'LLM116 Fixture Seed', Locked = true;

    fields
    {
        field(1; "Run Id"; Guid)
        {
            Caption = 'Run Id', Locked = true;
        }
    }
    keys
    {
        key(PK; "Run Id") { Clustered = true; }
    }
}
