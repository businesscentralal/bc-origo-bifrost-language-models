namespace Origo.Bifrost.LanguageModels;

/// <summary>
/// Per-company caps and defaults of LLM.Prompt.Ask (#120). The headless runner reads them instead of fixed numbers.
/// A request limit above its cap is clamped with a clamped:&lt;key&gt; warning; a request without a limit uses the default.
/// Install and upgrade insert the row with the values that were fixed before (caps 40 / 20 / 20000, defaults 15 / 10 / 8000).
/// The tool-call and round caps accept 1..999 (Gunnar 11.11.2026); the result-size cap counts characters and only needs 1 or more.
/// Reading is inherent (GetSetup), so every Ask caller sees the caps; changing them needs write permission on the table data,
/// which only the language-model admin sets ("BIFROST LLM ori" and the "BIFROST Full ori" extension) grant.
/// </summary>
table 10035434 "LangModel Ask Setup ori"
{
    Caption = 'Language Model Ask Setup', Comment = 'is-IS=Uppsetning mállíkansspurninga';
    DataClassification = SystemMetadata;
    DataPerCompany = true;
    Access = Internal;
    Extensible = false;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key', Comment = 'is-IS=Aðallykill';
            ToolTip = 'Specifies the primary key of the single setup row.', Comment = 'is-IS=Tilgreinir aðallykil einu uppsetningarlínunnar.';
            AllowInCustomizations = Never;
        }
        field(2; "Ask Max Tool Calls Cap"; Integer)
        {
            Caption = 'Ask Max Tool Calls Cap', Comment = 'is-IS=Hámark verkfærakalla í spurningu';
            ToolTip = 'Specifies the most tool calls one LLM.Prompt.Ask request may use, from 1 to 999. A higher limits.maxToolCalls is cut to this value with a clamped:maxToolCalls warning.', Comment = 'is-IS=Tilgreinir flest verkfærakköll sem ein LLM.Prompt.Ask beiðni má nota, frá 1 til 999. Hærra limits.maxToolCalls er lækkað í þetta gildi með viðvöruninni clamped:maxToolCalls.';
            InitValue = 40;

            trigger OnValidate()
            begin
                CheckCountCap(Rec."Ask Max Tool Calls Cap", Rec.FieldCaption("Ask Max Tool Calls Cap"));
                CheckDefaultNotAboveCap(Rec."Ask Default Tool Calls", Rec."Ask Max Tool Calls Cap", Rec.FieldCaption("Ask Default Tool Calls"), Rec.FieldCaption("Ask Max Tool Calls Cap"));
            end;
        }
        field(3; "Ask Max Rounds Cap"; Integer)
        {
            Caption = 'Ask Max Rounds Cap', Comment = 'is-IS=Hámark umferða í spurningu';
            ToolTip = 'Specifies the most provider requests (rounds) one LLM.Prompt.Ask request may use, from 1 to 999. A higher limits.maxRounds is cut to this value with a clamped:maxRounds warning.', Comment = 'is-IS=Tilgreinir flestar beiðnir til veitanda (umferðir) sem ein LLM.Prompt.Ask beiðni má nota, frá 1 til 999. Hærra limits.maxRounds er lækkað í þetta gildi með viðvöruninni clamped:maxRounds.';
            InitValue = 20;

            trigger OnValidate()
            begin
                CheckCountCap(Rec."Ask Max Rounds Cap", Rec.FieldCaption("Ask Max Rounds Cap"));
                CheckDefaultNotAboveCap(Rec."Ask Default Rounds", Rec."Ask Max Rounds Cap", Rec.FieldCaption("Ask Default Rounds"), Rec.FieldCaption("Ask Max Rounds Cap"));
            end;
        }
        field(4; "Ask Max Result Chars Cap"; Integer)
        {
            Caption = 'Ask Max Result Chars Cap', Comment = 'is-IS=Hámark stafa í verkfæraniðurstöðu';
            ToolTip = 'Specifies the most characters of one tool result that LLM.Prompt.Ask sends to the model, 1 or more. A higher limits.maxResultChars is cut to this value with a clamped:maxResultChars warning.', Comment = 'is-IS=Tilgreinir flesta stafi einnar verkfæraniðurstöðu sem LLM.Prompt.Ask sendir líkaninu, 1 eða fleiri. Hærra limits.maxResultChars er lækkað í þetta gildi með viðvöruninni clamped:maxResultChars.';
            InitValue = 20000;

            trigger OnValidate()
            begin
                if Rec."Ask Max Result Chars Cap" < 1 then
                    Error(MinOneErr, Rec.FieldCaption("Ask Max Result Chars Cap"));
                CheckDefaultNotAboveCap(Rec."Ask Default Result Chars", Rec."Ask Max Result Chars Cap", Rec.FieldCaption("Ask Default Result Chars"), Rec.FieldCaption("Ask Max Result Chars Cap"));
            end;
        }
        field(5; "Ask Default Tool Calls"; Integer)
        {
            Caption = 'Ask Default Tool Calls', Comment = 'is-IS=Sjálfgefin verkfærakköll í spurningu';
            ToolTip = 'Specifies the tool calls an LLM.Prompt.Ask request may use when it sends no limits.maxToolCalls. It cannot be above Ask Max Tool Calls Cap.', Comment = 'is-IS=Tilgreinir verkfærakköllin sem LLM.Prompt.Ask beiðni má nota þegar hún sendir ekkert limits.maxToolCalls. Það má ekki vera hærra en Hámark verkfærakalla í spurningu.';
            InitValue = 15;

            trigger OnValidate()
            begin
                if Rec."Ask Default Tool Calls" < 1 then
                    Error(MinOneErr, Rec.FieldCaption("Ask Default Tool Calls"));
                CheckDefaultNotAboveCap(Rec."Ask Default Tool Calls", Rec."Ask Max Tool Calls Cap", Rec.FieldCaption("Ask Default Tool Calls"), Rec.FieldCaption("Ask Max Tool Calls Cap"));
            end;
        }
        field(6; "Ask Default Rounds"; Integer)
        {
            Caption = 'Ask Default Rounds', Comment = 'is-IS=Sjálfgefnar umferðir í spurningu';
            ToolTip = 'Specifies the provider requests (rounds) an LLM.Prompt.Ask request may use when it sends no limits.maxRounds. It cannot be above Ask Max Rounds Cap.', Comment = 'is-IS=Tilgreinir beiðnir til veitanda (umferðir) sem LLM.Prompt.Ask beiðni má nota þegar hún sendir ekkert limits.maxRounds. Það má ekki vera hærra en Hámark umferða í spurningu.';
            InitValue = 10;

            trigger OnValidate()
            begin
                if Rec."Ask Default Rounds" < 1 then
                    Error(MinOneErr, Rec.FieldCaption("Ask Default Rounds"));
                CheckDefaultNotAboveCap(Rec."Ask Default Rounds", Rec."Ask Max Rounds Cap", Rec.FieldCaption("Ask Default Rounds"), Rec.FieldCaption("Ask Max Rounds Cap"));
            end;
        }
        field(7; "Ask Default Result Chars"; Integer)
        {
            Caption = 'Ask Default Result Chars', Comment = 'is-IS=Sjálfgefnir stafir í verkfæraniðurstöðu';
            ToolTip = 'Specifies the characters of one tool result LLM.Prompt.Ask sends to the model when the request sends no limits.maxResultChars. It cannot be above Ask Max Result Chars Cap.', Comment = 'is-IS=Tilgreinir stafi einnar verkfæraniðurstöðu sem LLM.Prompt.Ask sendir líkaninu þegar beiðnin sendir ekkert limits.maxResultChars. Það má ekki vera hærra en Hámark stafa í verkfæraniðurstöðu.';
            InitValue = 8000;

            trigger OnValidate()
            begin
                if Rec."Ask Default Result Chars" < 1 then
                    Error(MinOneErr, Rec.FieldCaption("Ask Default Result Chars"));
                CheckDefaultNotAboveCap(Rec."Ask Default Result Chars", Rec."Ask Max Result Chars Cap", Rec.FieldCaption("Ask Default Result Chars"), Rec.FieldCaption("Ask Max Result Chars Cap"));
            end;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    begin
        CheckLimits();
    end;

    trigger OnModify()
    begin
        CheckLimits();
    end;

    var
        CountCapRangeErr: Label '%1 must be from %2 to %3.', Comment = '%1 = field caption, %2 = lowest value, %3 = highest value, is-IS=%1 verður að vera frá %2 til %3.';
        MinOneErr: Label '%1 must be 1 or more.', Comment = '%1 = field caption, is-IS=%1 verður að vera 1 eða meira.';
        DefaultAboveCapErr: Label '%1 (%2) cannot be above %3 (%4).', Comment = '%1 = default field caption, %2 = default value, %3 = cap field caption, %4 = cap value, is-IS=%1 (%2) má ekki vera hærra en %3 (%4).';

    /// <summary>
    /// Returns the setup row of the company, or the install values when the row does not exist yet. Never writes.
    /// </summary>
    [InherentPermissions(PermissionObjectType::TableData, Database::"LangModel Ask Setup ori", 'r')]
    procedure GetSetup()
    begin
        Rec.ReadIsolation := IsolationLevel::ReadCommitted;
        if not Rec.Get() then begin
            Rec.Init();
            Rec."Primary Key" := '';
        end;
    end;

    /// <summary>
    /// Inserts the setup row with the install values when it does not exist. Called from install and upgrade; idempotent.
    /// </summary>
    [InherentPermissions(PermissionObjectType::TableData, Database::"LangModel Ask Setup ori", 'ri')]
    procedure InitSetup()
    begin
        if Rec.Get() then
            exit;
        Rec.Init();
        Rec."Primary Key" := '';
        Rec.Insert();
    end;

    /// <summary>
    /// Validates NewValue into field FieldNo of a copy of Current (the stored row or the install values) and writes it:
    /// Modify when the row exists, Insert on the first change. The table triggers check every cap and default again.
    /// </summary>
    procedure SetValue(Current: Record "LangModel Ask Setup ori"; FieldNo: Integer; NewValue: Integer)
    var
        RecRef: RecordRef;
        FieldRef: FieldRef;
        Exists: Boolean;
    begin
        Rec := Current;
        RecRef.GetTable(Rec);
        FieldRef := RecRef.Field(FieldNo);
        FieldRef.Validate(NewValue);
        RecRef.SetTable(Rec);
        Exists := Current.Get();
        if Exists then
            Rec.Modify(true)
        else
            Rec.Insert(true);
    end;

    /// <summary>
    /// Checks every cap and default together: count caps 1..999, result-size cap 1 or more, defaults 1 or more and not above their cap.
    /// </summary>
    procedure CheckLimits()
    begin
        CheckCountCap(Rec."Ask Max Tool Calls Cap", Rec.FieldCaption("Ask Max Tool Calls Cap"));
        CheckCountCap(Rec."Ask Max Rounds Cap", Rec.FieldCaption("Ask Max Rounds Cap"));
        if Rec."Ask Max Result Chars Cap" < 1 then
            Error(MinOneErr, Rec.FieldCaption("Ask Max Result Chars Cap"));
        if Rec."Ask Default Tool Calls" < 1 then
            Error(MinOneErr, Rec.FieldCaption("Ask Default Tool Calls"));
        if Rec."Ask Default Rounds" < 1 then
            Error(MinOneErr, Rec.FieldCaption("Ask Default Rounds"));
        if Rec."Ask Default Result Chars" < 1 then
            Error(MinOneErr, Rec.FieldCaption("Ask Default Result Chars"));
        CheckDefaultNotAboveCap(Rec."Ask Default Tool Calls", Rec."Ask Max Tool Calls Cap", Rec.FieldCaption("Ask Default Tool Calls"), Rec.FieldCaption("Ask Max Tool Calls Cap"));
        CheckDefaultNotAboveCap(Rec."Ask Default Rounds", Rec."Ask Max Rounds Cap", Rec.FieldCaption("Ask Default Rounds"), Rec.FieldCaption("Ask Max Rounds Cap"));
        CheckDefaultNotAboveCap(Rec."Ask Default Result Chars", Rec."Ask Max Result Chars Cap", Rec.FieldCaption("Ask Default Result Chars"), Rec.FieldCaption("Ask Max Result Chars Cap"));
    end;

    /// <summary>
    /// The lowest value of the tool-call and round caps.
    /// </summary>
    procedure CountCapMin(): Integer
    begin
        exit(1);
    end;

    /// <summary>
    /// The highest value of the tool-call and round caps (Gunnar 11.11.2026).
    /// </summary>
    procedure CountCapMax(): Integer
    begin
        exit(999);
    end;

    local procedure CheckCountCap(Value: Integer; Caption: Text)
    begin
        if (Value < CountCapMin()) or (Value > CountCapMax()) then
            Error(CountCapRangeErr, Caption, CountCapMin(), CountCapMax());
    end;

    local procedure CheckDefaultNotAboveCap(DefaultValue: Integer; CapValue: Integer; DefaultCaption: Text; CapCaption: Text)
    begin
        if DefaultValue > CapValue then
            Error(DefaultAboveCapErr, DefaultCaption, DefaultValue, CapCaption, CapValue);
    end;
}
