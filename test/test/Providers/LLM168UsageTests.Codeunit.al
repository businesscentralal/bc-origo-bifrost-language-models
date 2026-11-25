namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;
using System.AI;
using System.DataAdministration;
using System.TestLibraries.Utilities;
using System.Threading;

/// <summary>Issue 168: provider usage, immutable prices, privacy, retention and daily compression.</summary>
codeunit 96083 "LLM 168 Usage Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;
    var
        Model: Record "Bifrost Language Model ori";
        Assert: Codeunit "Library Assert";
        Mock: Codeunit "LLM 168 Usage Mock";
        SecretMarkerTok: Label 'X-PRIVATE-PROMPT-RESPONSE-FILE', Locked = true;

    /// <summary>Verifies the named issue 168 acceptance scenario through the production operation.</summary>
    [Test]
    procedure Scenario_AC01_AllExternalCompletions_OneRow()
    var
        ProviderType: Enum "Bifrost LangModel Prov. ori";
        Ordinal: Integer;
    begin
        // Story #168 AC01 | Time: current call | Risk: double logging or a missing provider.
        Initialize();
        for Ordinal := 2 to 7 do begin
            ProviderType := Enum::"Bifrost LangModel Prov. ori".FromInteger(Ordinal);
            RunCall(ProviderType, true, UsageBody(), 200, false);
            VerifyRow(100, 25, true);
        end;
    end;

    /// <summary>Verifies the named issue 168 acceptance scenario through the production operation.</summary>
    [Test]
    procedure Scenario_AC01_ChatAndAsk_OneRowPerRound()
    var
        ProviderType: Enum "Bifrost LangModel Prov. ori";
        Ordinal: Integer;
    begin
        // Story #168 AC01 | Time: current call | Risk: chat transports evade the shared recorder.
        Initialize();
        for Ordinal := 2 to 7 do begin
            ProviderType := Enum::"Bifrost LangModel Prov. ori".FromInteger(Ordinal);
            RunCall(ProviderType, false, UsageBody(), 200, false);
            VerifyRow(100, 25, true);
        end;
    end;

    /// <summary>Verifies the named issue 168 acceptance scenario through the production operation.</summary>
    [Test]
    procedure Scenario_AC01_Copilot_OneRow()
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        AzureOpenAI: Codeunit "Azure OpenAI";
        Messages: Codeunit "AOAI Chat Messages";
        Parameters: Codeunit "AOAI Chat Completion Params";
        Operation: Codeunit "AOAI Operation Response";
        Copilot: Codeunit "LLM Usage Copilot ori";
        Usage: Codeunit "LLM Usage Recorder ori";
    begin
        // Story #168 AC01 | Time: current call | Risk: managed calls miss logging. Calls the production managed boundary.
        Initialize();
        PrepareModel(Enum::"Bifrost LangModel Prov. ori"::Copilot, TempArgument);
        Usage.SetContext(TempArgument);
        Mock.Configure(UsageBody(), 200, false);
        Commit();
        BindSubscription(Mock);
        Usage.BeginScope();
        Assert.IsTrue(Copilot.Generate(AzureOpenAI, Messages, Parameters, Operation), 'Mocked managed call succeeds.');
        Usage.EndScope();
        UnbindSubscription(Mock);
        VerifyRow(100, 25, true);
    end;

    /// <summary>Verifies the named issue 168 acceptance scenario through the production operation.</summary>
    [Test]
    procedure Scenario_AC02_FailedProviders_ZeroTokens()
    var
        UsageLog: Record "LLM Usage Log ori";
        ProviderType: Enum "Bifrost LangModel Prov. ori";
        Ordinal: Integer;
    begin
        // Story #168 AC02 | Time: current call | Risk: failure bodies are counted or retained.
        Initialize();
        for Ordinal := 2 to 7 do begin
            ProviderType := Enum::"Bifrost LangModel Prov. ori".FromInteger(Ordinal);
            RunCall(ProviderType, true, '{"error":{"message":"X-PRIVATE-PROMPT-RESPONSE-FILE"},"usage":{"prompt_tokens":999}}', 429, false);
            VerifyRow(0, 0, false);
            UsageLog.FindLast();
            Assert.AreEqual('HTTP_429', UsageLog."Error Code", 'Controlled HTTP error code.');
        end;
    end;

    /// <summary>Verifies the named issue 168 acceptance scenario through the production operation.</summary>
    [Test]
    procedure Scenario_AC02_ChatFailure_OneRow()
    begin
        // Story #168 AC02 | Time: current call | Risk: caught transport exceptions lose the usage record.
        Initialize();
        RunCall(Enum::"Bifrost LangModel Prov. ori"::"Custom LLM", false, '{"error":{}}', 503, false);
        VerifyRow(0, 0, false);
    end;

    /// <summary>Verifies the named issue 168 acceptance scenario through the production operation.</summary>
    [Test]
    procedure Scenario_AC02_MissingUsage_Flagged()
    var
        UsageLog: Record "LLM Usage Log ori";
    begin
        // Story #168 AC02 | Time: current call | Risk: missing usage is confused with measured zero.
        Initialize();
        RunCall(Enum::"Bifrost LangModel Prov. ori"::"Custom LLM", true, '{"choices":[{"message":{"content":"ok"}}]}', 200, false);
        VerifyRow(0, 0, true);
        UsageLog.FindLast();
        Assert.IsTrue(UsageLog."Usage Not Reported", 'Missing usage is explicit.');
    end;

    /// <summary>Verifies the named issue 168 acceptance scenario through the production operation.</summary>
    [Test]
    procedure Scenario_AC02_TransportException_ZeroTokens()
    begin
        // Story #168 AC02 | Time: current call | Risk: exceptions lose failure evidence.
        Initialize();
        RunCall(Enum::"Bifrost LangModel Prov. ori"::"Custom LLM", true, '', 0, true);
        VerifyRow(0, 0, false);
    end;

    /// <summary>Verifies the named issue 168 acceptance scenario through the production operation.</summary>
    [Test]
    procedure Scenario_AC02_InvalidJson_FailureLogged()
    begin
        // Story #168 AC02 | Time: current call | Risk: invalid successful HTTP responses are counted as success.
        Initialize();
        RunCall(Enum::"Bifrost LangModel Prov. ori"::"Custom LLM", true, 'not-json', 200, false);
        VerifyRow(0, 0, false);
    end;

    /// <summary>Verifies the named issue 168 acceptance scenario through the production operation.</summary>
    [Test]
    procedure Scenario_AC03_PriceChanges_PreserveHistory()
    var
        UsageLog: Record "LLM Usage Log ori";
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Usage: Codeunit "LLM Usage Recorder ori";
        Provider: Interface "Bifrost LangModel Provider ori";
        OldEntryNo: BigInteger;
    begin
        // Story #168 AC03 | Time: current call | Risk: costs are recalculated at today's price.
        Initialize();
        RunCall(Enum::"Bifrost LangModel Prov. ori"::"Custom LLM", true, UsageBody(), 200, false);
        UsageLog.FindLast();
        OldEntryNo := UsageLog."Entry No.";
        Assert.AreEqual(0.0004, UsageLog.Cost, '100 * 2 / 1M + 25 * 8 / 1M.');
        Model."Input Price per 1M" := 10;
        Model."Output Price per 1M" := 20;
        Model.Modify();
        BuildArgument(TempArgument, true);
        Provider := Model."Chat Provider";
        Mock.Configure(UsageBody(), 200, false);
        Commit();
        BindSubscription(Mock);
        Usage.BeginScope();
        Provider.Execute(TempArgument);
        Usage.EndScope();
        UnbindSubscription(Mock);
        UsageLog.FindLast();
        Assert.AreEqual(0.0015, UsageLog.Cost, 'New call uses changed prices.');
        UsageLog.Get(OldEntryNo);
        Assert.AreEqual(0.0004, UsageLog.Cost, 'Old cost is immutable.');
    end;

    /// <summary>Verifies the named issue 168 acceptance scenario through the production operation.</summary>
    [Test]
    procedure Scenario_AC04_NoContent_InRowsOrTelemetry()
    var
        UsageLog: Record "LLM Usage Log ori";
        TempEntry: Record "LLM Usage Log ori" temporary;
        Usage: Codeunit "LLM Usage Recorder ori";
        EntryRef: RecordRef;
        Field: FieldRef;
        Dimensions: Dictionary of [Text, Text];
        Value: Text;
        FieldIndex: Integer;
    begin
        // Story #168 AC04 | Time: current call | Risk: sensitive payload leaks into a free-text field.
        Initialize();
        RunCall(Enum::"Bifrost LangModel Prov. ori"::"Custom LLM", true, UsageBody(), 200, false);
        UsageLog.FindLast();
        EntryRef.GetTable(UsageLog);
        for FieldIndex := 1 to EntryRef.FieldCount() do begin
            Field := EntryRef.FieldIndex(FieldIndex);
            Assert.IsFalse(Format(Field.Value).Contains(SecretMarkerTok), 'No sensitive marker in any stored field.');
            Assert.IsFalse(Field.Type = FieldType::Blob, 'No content blob.');
        end;
        TempEntry := UsageLog;
        Dimensions := Usage.GetTelemetryDimensions(TempEntry);
        foreach Value in Dimensions.Values() do
            Assert.IsFalse(Value.Contains(SecretMarkerTok), 'No content in telemetry.');
        Assert.IsFalse(Dimensions.ContainsKey('user'), 'No user identity in telemetry.');
        Assert.IsTrue(UsageLog."Request Log Entry No." > 0, 'Correlates to a real request-log entry.');
    end;

    /// <summary>Verifies the named issue 168 acceptance scenario through the production operation.</summary>
    [Test]
    procedure Scenario_AC05a_DefaultPolicies_Disabled()
    var
        Policy: Record "Retention Policy Setup";
        Period: Record "Retention Period";
        Allowed: Codeunit "Reten. Pol. Allowed Tables";
        Install: Codeunit "Copilot Install ori";
    begin
        // Story #168 AC05a | Time: none | Risk: install enables deletion or uses SystemCreatedAt.
        Initialize();
        Policy.SetFilter("Table Id", '%1|%2', Database::"LLM Usage Log ori", Database::"LLM Usage Daily ori");
        Policy.DeleteAll(true);
        Period.SetFilter(Code, '%1|%2', 'LLM-90D', 'LLM-2Y');
        Period.DeleteAll(true);
        Install.InitUsageSetup();
        Assert.IsTrue(Allowed.IsAllowedTable(Database::"LLM Usage Log ori"), 'Detail registered.');
        Assert.IsTrue(Allowed.IsAllowedTable(Database::"LLM Usage Daily ori"), 'Daily registered.');
        Policy.Get(Database::"LLM Usage Log ori");
        Assert.IsFalse(Policy.Enabled, 'Detail disabled by default.');
        Assert.AreEqual(20, Policy."Date Field No.", 'Call time, not creation time.');
        Period.Get(Policy."Retention Period");
        Assert.AreEqual(CalcDate('<-90D>', Today()), CalcDate(Period."Ret. Period Calculation", Today()), '90 day default.');
        Policy.Get(Database::"LLM Usage Daily ori");
        Assert.IsFalse(Policy.Enabled, 'Daily disabled by default.');
        Assert.AreEqual(2, Policy."Date Field No.", 'Daily call date.');
        Period.Get(Policy."Retention Period");
        Assert.AreEqual(CalcDate('<-2Y>', Today()), CalcDate(Period."Ret. Period Calculation", Today()), 'Two year default.');
    end;

    /// <summary>Verifies the named issue 168 acceptance scenario through the production operation.</summary>
    [Test]
    procedure Scenario_AC05b_CompressAction_TotalsAndBoundary()
    var
        UsageLog: Record "LLM Usage Log ori";
        Daily: Record "LLM Usage Daily ori";
        UsagePage: TestPage "LLM Usage Log ori";
    begin
        // Story #168 AC05b | Time: relative days | Risk: compression loses values or deletes the boundary.
        Initialize();
        SeedDetail(Today() - 31, 100, true, 'USD');
        SeedDetail(Today() - 31, 200, false, 'USD');
        SeedDetail(Today() - 30, 400, true, 'USD');
        UsagePage.OpenView();
        UsagePage.CompressUsage.Invoke();
        UsagePage.Close();
        Assert.AreEqual(1, UsageLog.Count(), 'Only boundary row remains.');
        Assert.AreEqual(1, Daily.Count(), 'Old rows aggregate into one day.');
        Daily.FindFirst();
        Assert.AreEqual(BigInt(300), Daily."Input Tokens", 'Input sum.');
        Assert.AreEqual(BigInt(30), Daily."Output Tokens", 'Output sum.');
        Assert.AreEqual(BigInt(6), Daily."Cached Tokens", 'Cache sum.');
        Assert.AreEqual(BigInt(4), Daily."Reasoning Tokens", 'Reasoning sum.');
        Assert.AreEqual(0.3, Daily.Cost, 'Cost sum.');
        Assert.AreEqual(2, Daily."Call Count", 'Call count.');
        Assert.AreEqual(1, Daily."Error Count", 'Error count.');
        UsagePage.OpenView();
        UsagePage.CompressUsage.Invoke();
        UsagePage.Close();
        Daily.FindFirst();
        Assert.AreEqual(2, Daily."Call Count", 'Second run does not count again.');
        SeedDetail(Today() - 31, 50, true, 'USD');
        UsagePage.OpenView();
        UsagePage.CompressUsage.Invoke();
        UsagePage.Close();
        Daily.FindFirst();
        Assert.AreEqual(BigInt(350), Daily."Input Tokens", 'Late old entries add to existing totals.');
    end;

    /// <summary>Verifies the named issue 168 acceptance scenario through the production operation.</summary>
    [Test]
    procedure Scenario_AC05c_CompressWithoutUser_Anonymous()
    var
        Daily: Record "LLM Usage Daily ori";
        UsagePage: TestPage "LLM Usage Log ori";
    begin
        // Story #168 AC05c | Time: relative days | Risk: compressed totals retain personal data by default.
        Initialize();
        SeedDetail(Today() - 31, 100, true, 'USD');
        SeedDetail(Today() - 31, 200, true, 'EUR');
        UsagePage.OpenView();
        UsagePage.CompressUsage.Invoke();
        UsagePage.Close();
        Assert.AreEqual(2, Daily.Count(), 'Currencies are never combined.');
        if Daily.FindSet() then
            repeat
                Assert.IsTrue(IsNullGuid(Daily."User Security ID"), 'User is omitted by default.');
            until Daily.Next() = 0;
    end;

    /// <summary>Verifies the named issue 168 acceptance scenario through the production operation.</summary>
    [Test]
    procedure Scenario_AC05c_KeepUser_IdentityPreserved()
    var
        Daily: Record "LLM Usage Daily ori";
        SetupPage: TestPage "LLM Usage Setup ori";
        UsagePage: TestPage "LLM Usage Log ori";
    begin
        // Story #168 AC05c | Time: relative days | Risk: an explicit keep-user setting is ignored.
        Initialize();
        SetupPage.OpenEdit();
        SetupPage."Keep User in Daily Totals".SetValue(true);
        SetupPage.Close();
        SeedDetail(Today() - 31, 100, true, 'USD');
        UsagePage.OpenView();
        UsagePage.CompressUsage.Invoke();
        UsagePage.Close();
        Daily.FindFirst();
        Assert.AreEqual(UserSecurityId(), Daily."User Security ID", 'Opt-in identity.');
    end;

    /// <summary>Verifies the named issue 168 acceptance scenario through the production operation.</summary>
    [Test]
    procedure Scenario_AC05b_JobQueue_Compresses()
    var
        Job: Record "Job Queue Entry";
        UsageLog: Record "LLM Usage Log ori";
        Daily: Record "LLM Usage Daily ori";
    begin
        // Story #168 AC05b | Time: relative days | Risk: the job queue OnRun does not invoke compression.
        Initialize();
        SeedDetail(Today() - 31, 100, true, 'USD');
        Job.Init();
        Commit();
        Codeunit.Run(Codeunit::"LLM Usage Compression ori", Job);
        Assert.IsTrue(UsageLog.IsEmpty(), 'Job removed eligible detail.');
        Assert.AreEqual(1, Daily.Count(), 'Job created totals.');
    end;

    /// <summary>Verifies the named issue 168 acceptance scenario through the production operation.</summary>
    [Test]
    procedure Scenario_AC05a_Retention_DeletesOnlyOldCalls()
    var
        UsageLog: Record "LLM Usage Log ori";
        Policy: Record "Retention Policy Setup";
        ApplyPolicy: Codeunit "Apply Retention Policy";
    begin
        // Story #168 AC05a | Time: relative call dates | Risk: fresh imported rows evade retention.
        Initialize();
        SeedDetail(Today() - 100, 100, true, 'USD');
        SeedDetail(Today() - 20, 200, true, 'USD');
        Policy.Get(Database::"LLM Usage Log ori");
        Policy.Validate(Enabled, true);
        Policy.Modify(true);
        Commit();
        ApplyPolicy.ApplyRetentionPolicy(Policy, false);
        Assert.AreEqual(1, UsageLog.Count(), 'Only the expired call is removed.');
        UsageLog.FindFirst();
        Assert.AreEqual(Today() - 20, UsageLog."Call Date", 'Newer call is preserved.');
    end;

    /// <summary>Verifies the named issue 168 acceptance scenario through the production operation.</summary>
    [Test]
    procedure Scenario_AC05b_ModelCard_CombinesDailyAndDetail()
    var
        Daily: Record "LLM Usage Daily ori";
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Card: TestPage "Bifrost LangModel Card ori";
    begin
        // Story #168 AC05b | Time: current month | Risk: compressed history disappears from the model card.
        Initialize();
        PrepareModel(Enum::"Bifrost LangModel Prov. ori"::"Custom LLM", TempArgument);
        Model.Code := 'X168';
        if not Model.Get('X168') then begin
            Model.Init();
            Model.Code := 'X168';
            Model."Usage Currency Code" := 'USD';
            Model.Insert();
        end;
        SeedDetail(Today(), 100, true, 'USD');
        Daily.Init();
        Daily."Call Date" := Today();
        Daily."Language Model Code" := 'X168';
        Daily."Currency Code" := 'USD';
        Daily."Input Tokens" := 200;
        Daily."Output Tokens" := 20;
        Daily.Cost := 0.2;
        Daily.Insert();
        Card.OpenEdit();
        Card.GoToRecord(Model);
        Card.MonthInputTokens.AssertEquals(300);
        Card.MonthOutputTokens.AssertEquals(30);
        Card.MonthCost.AssertEquals(0.3);
        asserterror Card."Input Price per 1M".SetValue(-1);
        Card.Close();
    end;

    /// <summary>Verifies the named issue 168 acceptance scenario through the production operation.</summary>
    [Test]
    [HandlerFunctions('UsageGuideHandler')]
    procedure Scenario_AC06_UsageGuide_Localized()
    var
        UsagePage: TestPage "LLM Usage Log ori";
        OriginalLanguage: Integer;
    begin
        // Story #168 AC06 | Time: none | Risk: the usage action has no usable localized help.
        Initialize();
        OriginalLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        UsagePage.OpenView();
        UsagePage.UsageGuide.Invoke();
        UsagePage.Close();
        GlobalLanguage(1039);
        UsagePage.OpenView();
        UsagePage.UsageGuide.Invoke();
        UsagePage.Close();
        GlobalLanguage(OriginalLanguage);
    end;

    /// <summary>Checks the guide displayed by the actual page action in each supported language.</summary>
    [MessageHandler]
    procedure UsageGuideHandler(HelpText: Text[1024])
    begin
        if GlobalLanguage() = 1039 then
            Assert.IsTrue(HelpText.Contains('Stilltu verð'), 'Icelandic instructions.')
        else
            Assert.IsTrue(HelpText.Contains('Set input and output prices'), 'English instructions.');
    end;

    local procedure Initialize()
    var
        UsageLog: Record "LLM Usage Log ori";
        Daily: Record "LLM Usage Daily ori";
        Setup: Record "LLM Usage Setup ori";
    begin
        UnbindSubscription(Mock);
        Clear(Mock);
        UsageLog.DeleteAll();
        Daily.DeleteAll();
        if not Setup.Get() then begin
            Setup.Init();
            Setup.Insert();
        end;
        Setup."Compress After Days" := 30;
        Setup."Keep User in Daily Totals" := false;
        Setup.Modify();
    end;

    local procedure PrepareModel(ProviderType: Enum "Bifrost LangModel Prov. ori"; var TempArgument: Record "Bifrost Chat Argument ori" temporary)
    begin
        Model.Init();
        Model.Code := CopyStr('X168-' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 20);
        Model."Chat Provider" := ProviderType;
        Model.Model := 'x-usage-model';
        Model."Base URL" := 'https://example.invalid';
        Model."Input Price per 1M" := 2;
        Model."Output Price per 1M" := 8;
        Model."Usage Currency Code" := 'USD';
        Model.Insert();
        BuildArgument(TempArgument, true);
    end;

    local procedure BuildArgument(var TempArgument: Record "Bifrost Chat Argument ori" temporary; Complete: Boolean)
    var
        FakeKey: SecretText;
        FakeKeyText: Text;
    begin
        Clear(TempArgument);
        TempArgument."Language Model SystemId" := Model.SystemId;
        TempArgument.Model := Model.Model;
        TempArgument."Base URL" := Model."Base URL";
        TempArgument."Max Tokens" := 1000;
        TempArgument."Context Tokens" := 32000;
        TempArgument."Timeout Ms" := 1000;
        FakeKeyText := 'X-FAKE-KEY-NOT-A-CREDENTIAL';
        FakeKey := FakeKeyText;
        TempArgument.SetApiKey(FakeKey);
        TempArgument.SetPayload('{"messages":[{"role":"user","content":"X-PRIVATE-PROMPT-RESPONSE-FILE"}]}');
        if Complete then begin
            TempArgument."Invocation Source" := 'LLM.Prompt.Complete';
            TempArgument."Procedure Type" := TempArgument."Procedure Type"::CompletePrompt;
        end else begin
            TempArgument."Invocation Source" := 'LLM.Prompt.Ask';
            TempArgument."Procedure Type" := TempArgument."Procedure Type"::SendChatMessage;
        end;
    end;

    local procedure RunCall(ProviderType: Enum "Bifrost LangModel Prov. ori"; Complete: Boolean; Body: Text; Status: Integer; ThrowError: Boolean)
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        UsageLog: Record "LLM Usage Log ori";
        Usage: Codeunit "LLM Usage Recorder ori";
        Provider: Interface "Bifrost LangModel Provider ori";
        BeforeCount: Integer;
        Response: JsonObject;
        TokenUsage: JsonObject;
    begin
        if Body = UsageBody() then begin
            Response.ReadFrom(Body);
            if ProviderType <> ProviderType::Google then
                Response.Remove('usageMetadata');
            TokenUsage := Response.GetObject('usage');
            if ProviderType in [ProviderType::"Custom LLM", ProviderType::"Azure OpenAI"] then begin
                TokenUsage.Remove('input_tokens');
                TokenUsage.Remove('output_tokens');
            end else begin
                TokenUsage.Remove('prompt_tokens');
                TokenUsage.Remove('completion_tokens');
            end;
            Response.Replace('usage', TokenUsage);
            Response.WriteTo(Body);
        end;
        PrepareModel(ProviderType, TempArgument);
        BuildArgument(TempArgument, Complete);
        Provider := ProviderType;
        BeforeCount := UsageLog.Count();
        Mock.Configure(Body, Status, ThrowError);
        Commit();
        BindSubscription(Mock);
        Usage.BeginScope();
        Provider.Execute(TempArgument);
        Usage.EndScope();
        UnbindSubscription(Mock);
        Assert.AreEqual(1, Mock.GetCalls(), 'Exactly one provider request.');
        Assert.AreEqual(BeforeCount + 1, UsageLog.Count(), 'Exactly one persisted usage row.');
    end;

    local procedure VerifyRow(InputTokens: BigInteger; OutputTokens: BigInteger; Success: Boolean)
    var
        UsageLog: Record "LLM Usage Log ori";
    begin
        UsageLog.FindLast();
        Assert.AreEqual(InputTokens, UsageLog."Input Tokens", 'Provider input tokens.');
        Assert.AreEqual(OutputTokens, UsageLog."Output Tokens", 'Provider output tokens.');
        Assert.AreEqual(Success, UsageLog.Success, 'Outcome.');
        Assert.AreEqual(Model.Code, UsageLog."Language Model Code", 'Model identity.');
        Assert.AreEqual(Model."Chat Provider", UsageLog.Provider, 'Provider identity.');
    end;

    local procedure BigInt(Value: BigInteger): BigInteger
    begin
        exit(Value);
    end;

    local procedure UsageBody(): Text
    begin
        exit('{"choices":[{"message":{"role":"assistant","content":"X-PRIVATE-PROMPT-RESPONSE-FILE"},"finish_reason":"stop"}],"content":[{"type":"text","text":"X-PRIVATE-PROMPT-RESPONSE-FILE"}],"stop_reason":"end_turn","output":[{"type":"message","role":"assistant","content":[{"type":"output_text","text":"X-PRIVATE-PROMPT-RESPONSE-FILE"}]}],"candidates":[{"content":{"parts":[{"text":"X-PRIVATE-PROMPT-RESPONSE-FILE"}]},"finishReason":"STOP"}],"usage":{"prompt_tokens":100,"completion_tokens":25,"input_tokens":100,"output_tokens":25,"cache_read_input_tokens":3,"prompt_tokens_details":{"cached_tokens":3},"completion_tokens_details":{"reasoning_tokens":2}},"usageMetadata":{"promptTokenCount":100,"candidatesTokenCount":25,"cachedContentTokenCount":3,"thoughtsTokenCount":2}}');
    end;

    local procedure SeedDetail(CallDate: Date; InputTokens: BigInteger; Success: Boolean; CurrencyCode: Code[10])
    var
        UsageLog: Record "LLM Usage Log ori";
    begin
        UsageLog.Init();
        UsageLog."Called At" := CreateDateTime(CallDate, 120000T);
        UsageLog."Call Date" := CallDate;
        UsageLog.Company := CopyStr(CompanyName(), 1, 30);
        UsageLog."Language Model Code" := 'X168';
        UsageLog.Provider := UsageLog.Provider::OpenAI;
        UsageLog."Model ID" := 'x-usage-model';
        UsageLog."Invocation Source" := 'Chat';
        UsageLog."User Security ID" := UserSecurityId();
        UsageLog."Input Tokens" := InputTokens;
        UsageLog."Output Tokens" := InputTokens div 10;
        UsageLog."Cached Tokens" := 3;
        UsageLog."Reasoning Tokens" := 2;
        UsageLog.Cost := InputTokens / 1000;
        UsageLog."Currency Code" := CurrencyCode;
        UsageLog.Success := Success;
        UsageLog.Insert();
    end;
}
