namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests the configurable LLM.Prompt.Ask caps and defaults (#120): install and upgrade values, the 1..999 range of the
/// count caps, defaults against caps, the runner reading the company setup (below, at and above a cap, a raised cap
/// with 100 tool calls), the help text, the setup page in 1033 and 1039 and the permission split. Mock provider only.
/// </summary>
codeunit 96067 "LLM Ask Setup Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        ModelCodeTok: Label 'ASK-CAPS', Locked = true;
        ReplyTok: Label '{"type":"reply","reply":"%1"}', Locked = true;
        ToolCallTok: Label '{"type":"tool_calls","toolCalls":[%1],"conversationState":"{\"messages\":[],\"model\":\"mock\"}"}', Locked = true;
        CallTok: Label '{"id":"%1","name":"%2","arguments":{}}', Locked = true;

    [Test]
    procedure Install_InsertsTheEarlierFixedValues()
    var
        AskSetup: Record "LangModel Ask Setup ori";
        CopilotInstall: Codeunit "Copilot Install ori";
    begin
        // [SCENARIO AC01/AC02] install inserts caps 40 / 20 / 20000 and defaults 15 / 10 / 8000
        Initialize();
        Assert.IsTrue(AskSetup.IsEmpty(), 'precondition: no setup row');

        CopilotInstall.InitAskSetup();

        Assert.IsTrue(AskSetup.Get(), 'install inserts the row');
        VerifyValues(AskSetup, 40, 20, 20000, 15, 10, 8000);
    end;

    [Test]
    procedure Upgrade_KeepsAnExistingRaisedCap()
    var
        AskSetup: Record "LangModel Ask Setup ori";
        CopilotInstall: Codeunit "Copilot Install ori";
    begin
        // [SCENARIO AC01] the install/upgrade step is idempotent and never lowers a cap an administrator raised
        Initialize();
        SetCaps(250, 60, 50000);

        CopilotInstall.InitAskSetup();

        AskSetup.Get();
        VerifyValues(AskSetup, 250, 60, 50000, 15, 10, 8000);
    end;

    [Test]
    procedure GetSetup_WithoutRow_ReturnsTheInstallValues()
    var
        AskSetup: Record "LangModel Ask Setup ori";
    begin
        // [SCENARIO AC03] a company without the row behaves as before and nothing is written
        Initialize();

        AskSetup.GetSetup();

        VerifyValues(AskSetup, 40, 20, 20000, 15, 10, 8000);
        Assert.IsTrue(AskSetup.IsEmpty(), 'GetSetup never writes');
    end;

    [Test]
    procedure ToolCallsCap_Accepts1And999_Refuses0And1000()
    var
        AskSetup: Record "LangModel Ask Setup ori";
    begin
        // [SCENARIO AC01] Gunnar 11.11.2026: Ask Max Tool Calls Cap accepts 1..999
        Initialize();
        VerifyCountCap(AskSetup.FieldNo("Ask Max Tool Calls Cap"));
    end;

    [Test]
    procedure RoundsCap_Accepts1And999_Refuses0And1000()
    var
        AskSetup: Record "LangModel Ask Setup ori";
    begin
        // [SCENARIO AC01] Gunnar 11.11.2026: Ask Max Rounds Cap accepts 1..999
        Initialize();
        VerifyCountCap(AskSetup.FieldNo("Ask Max Rounds Cap"));
    end;

    [Test]
    procedure ResultCharsCap_HasNo999Limit_Refuses0()
    var
        AskSetup: Record "LangModel Ask Setup ori";
        StoredAskSetup: Record "LangModel Ask Setup ori";
    begin
        // [SCENARIO AC01] the result-size cap counts characters: 1 or more, no 999 ceiling
        Initialize();
        StoredAskSetup.GetSetup();
        AskSetup.SetValue(StoredAskSetup, AskSetup.FieldNo("Ask Max Result Chars Cap"), 1000000);
        StoredAskSetup.Get();
        Assert.AreEqual(1000000, StoredAskSetup."Ask Max Result Chars Cap", 'a million characters is accepted and stored');

        asserterror ValidateInMemory(AskSetup.FieldNo("Ask Max Result Chars Cap"), 0);
        Assert.ExpectedError('must be 1 or more');
    end;

    [Test]
    procedure Default_AboveCap_IsRefused()
    var
        AskSetup: Record "LangModel Ask Setup ori";
        StoredAskSetup: Record "LangModel Ask Setup ori";
    begin
        // [SCENARIO AC02] a default above its cap is refused; a cap below its default is refused too; equal is accepted
        Initialize();
        StoredAskSetup.GetSetup();
        AskSetup.SetValue(StoredAskSetup, AskSetup.FieldNo("Ask Default Tool Calls"), 40);
        StoredAskSetup.Get();
        Assert.AreEqual(40, StoredAskSetup."Ask Default Tool Calls", 'a default equal to its cap is accepted');

        asserterror ValidateOnInstallValues(AskSetup.FieldNo("Ask Default Tool Calls"), 41);
        Assert.ExpectedError('cannot be above');
        asserterror ValidateOnInstallValues(AskSetup.FieldNo("Ask Default Rounds"), 21);
        Assert.ExpectedError('cannot be above');
        asserterror ValidateOnInstallValues(AskSetup.FieldNo("Ask Default Result Chars"), 20001);
        Assert.ExpectedError('cannot be above');
        asserterror ValidateOnInstallValues(AskSetup.FieldNo("Ask Max Tool Calls Cap"), 14);
        Assert.ExpectedError('cannot be above');
        asserterror ValidateOnInstallValues(AskSetup.FieldNo("Ask Default Tool Calls"), 0);
        Assert.ExpectedError('must be 1 or more');
    end;

    [Test]
    procedure Modify_WithAnInvalidRow_IsRefused()
    var
        AskSetup: Record "LangModel Ask Setup ori";
    begin
        // [SCENARIO AC01] every write path re-checks the row, not only field validation
        Initialize();
        AskSetup.InitSetup();
        AskSetup."Ask Max Rounds Cap" := 1000;
        asserterror AskSetup.Modify(true);
        Assert.ExpectedError('must be from 1 to 999');
    end;

    [Test]
    procedure Runner_BelowAndAtCap_UsedAsSent()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC03] cap 5: a request of 4 runs 4 calls and a request of 5 runs 5, without a clamped warning
        Initialize();
        SetCaps(5, 20, 20000);
        MockProvider.EnqueueAnswer(ToolCalls(Calls(6)));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'Final.'));
        ResponseJson := Execute(Request('{"question":"Q","limits":{"maxToolCalls":4}}'));
        Assert.AreEqual(4, ResponseJson.GetInteger('toolCalls'), Describe(ResponseJson));
        Assert.IsFalse(WarningsOf(ResponseJson).Contains('clamped:maxToolCalls'), Describe(ResponseJson));

        InitializeModel();
        MockProvider.EnqueueAnswer(ToolCalls(Calls(6)));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'Final.'));
        ResponseJson := Execute(Request('{"question":"Q","limits":{"maxToolCalls":5}}'));
        Assert.AreEqual(5, ResponseJson.GetInteger('toolCalls'), Describe(ResponseJson));
        Assert.AreEqual('maxToolCalls', ResponseJson.GetText('stopReason'), Describe(ResponseJson));
        Assert.IsFalse(WarningsOf(ResponseJson).Contains('clamped:maxToolCalls'), Describe(ResponseJson));
    end;

    [Test]
    procedure Runner_AboveCap_ClampedToTheSetupCap()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC03] cap 5: a request of 6 is clamped to 5 with the existing clamped:maxToolCalls warning
        Initialize();
        SetCaps(5, 20, 20000);
        MockProvider.EnqueueAnswer(ToolCalls(Calls(6)));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'Final.'));

        ResponseJson := Execute(Request('{"question":"Q","limits":{"maxToolCalls":6}}'));

        Assert.AreEqual(5, ResponseJson.GetInteger('toolCalls'), Describe(ResponseJson));
        Assert.IsTrue(WarningsOf(ResponseJson).Contains('clamped:maxToolCalls'), Describe(ResponseJson));
    end;

    [Test]
    procedure Runner_RaisedCap_Allows100ToolCalls()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC03] with the tool-call cap raised to 150 a request of 120 runs all 100 calls of the model, not 40
        Initialize();
        SetCaps(150, 20, 20000);
        MockProvider.EnqueueAnswer(ToolCalls(Calls(100)));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'Done.'));

        ResponseJson := Execute(Request('{"question":"Q","limits":{"maxToolCalls":120}}'));

        Assert.AreEqual('Success', ResponseJson.GetText('status'), Describe(ResponseJson));
        Assert.AreEqual(100, ResponseJson.GetInteger('toolCalls'), Describe(ResponseJson));
        Assert.AreEqual('completed', ResponseJson.GetText('stopReason'), Describe(ResponseJson));
        Assert.IsFalse(WarningsOf(ResponseJson).Contains('clamped:'), Describe(ResponseJson));
    end;

    [Test]
    procedure Runner_RaisedRoundsCap_AllowsMoreThan20Rounds()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
        Index: Integer;
    begin
        // [SCENARIO AC03] with the round cap raised to 30 a request of 25 rounds completes in 25 rounds without a warning
        Initialize();
        SetCaps(40, 30, 20000);
        for Index := 1 to 24 do
            MockProvider.EnqueueAnswer(ToolCalls(StrSubstNo(CallTok, 'r' + Format(Index), 'who_am_i')));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'Done.'));

        ResponseJson := Execute(Request('{"question":"Q","limits":{"maxRounds":25,"maxToolCalls":40}}'));

        Assert.AreEqual('completed', ResponseJson.GetText('stopReason'), Describe(ResponseJson));
        Assert.AreEqual(25, ResponseJson.GetInteger('rounds'), Describe(ResponseJson));
        Assert.IsFalse(WarningsOf(ResponseJson).Contains('clamped:'), Describe(ResponseJson));
    end;

    [Test]
    procedure Runner_NoLimitSent_UsesTheSetupDefault()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC02/AC03] default tool calls 2 in the setup: a request without limits runs 2 calls
        Initialize();
        SetDefaults(2, 10, 8000);
        MockProvider.EnqueueAnswer(ToolCalls(Calls(3)));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'Final.'));

        ResponseJson := Execute(Request('{"question":"Q"}'));

        Assert.AreEqual(2, ResponseJson.GetInteger('toolCalls'), Describe(ResponseJson));
        Assert.AreEqual('maxToolCalls', ResponseJson.GetText('stopReason'), Describe(ResponseJson));
    end;

    [Test]
    procedure Runner_ResultCharsCap_FromSetup()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
        ToolResultsText: Text;
    begin
        // [SCENARIO AC03] result-size cap 10 in the setup: a request of 50 is clamped and the tool result is cut at 10
        Initialize();
        SetDefaults(15, 10, 10);
        SetCaps(40, 20, 10);
        MockProvider.EnqueueAnswer(ToolCalls(Calls(1)));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'Final.'));

        ResponseJson := Execute(Request('{"question":"Q","limits":{"maxResultChars":50}}'));

        Assert.IsTrue(WarningsOf(ResponseJson).Contains('clamped:maxResultChars'), Describe(ResponseJson));
        ToolResultsText := MockProvider.GetToolResultsLog().Get(1);
        Assert.IsTrue(ToolResultsText.Contains('10 of '), 'the result is cut at the setup cap: ' + ToolResultsText);
    end;

    [Test]
    procedure Help_NamesTheSetupAndTheCompanyCaps()
    var
        AskImpl: Codeunit "LLM Prompt Ask Impl ori";
        Parameters: JsonArray;
        ParametersText: Text;
        Notes: Text;
    begin
        // [SCENARIO AC04] the limits text points at the setup and names the install defaults; the notes show this company's caps
        Initialize();
        SetCaps(120, 30, 25000);

        AskImpl.GetParameters(Parameters);
        Parameters.WriteTo(ParametersText);
        AskImpl.GetNotes(Notes);

        Assert.IsTrue(ParametersText.Contains('Language Model setup'), ParametersText);
        Assert.IsFalse(ParametersText.Contains('cap 40'), 'no fixed cap is stated: ' + ParametersText);
        Assert.IsTrue(ParametersText.Contains('on install 15 and 40'), ParametersText);
        Assert.IsTrue(Notes.Contains('maxToolCalls 15 (cap 120), maxRounds 10 (cap 30), maxResultChars 8000 (cap 25000)'), Notes);
        Assert.IsFalse(Notes.Contains('at most 40'), Notes);
    end;

    [Test]
    procedure SetupPage_EditsTheCaps_1033()
    begin
        VerifySetupPage(1033);
    end;

    [Test]
    procedure SetupPage_EditsTheCaps_1039()
    begin
        VerifySetupPage(1039);
    end;

    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Permissions_OnlyAdminSetsWrite()
    var
        AskSetup: Record "LangModel Ask Setup ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [SCENARIO AC05] changing the caps needs the language-model admin set; the read and chat sets only read
        LibraryLowerPermissions.SetO365Basic();
        LibraryLowerPermissions.AddPermissionSet('BIFROST LLM Rd ori');
        Assert.IsTrue(AskSetup.ReadPermission(), 'Read reads the caps');
        Assert.IsFalse(AskSetup.WritePermission(), 'Read cannot change the caps');

        LibraryLowerPermissions.SetO365Basic();
        LibraryLowerPermissions.AddPermissionSet('BIFROST API ori');
        LibraryLowerPermissions.AddPermissionSet('BIFROST Chat ori');
        LibraryLowerPermissions.AddPermissionSet('BIFROST LLM Chat ori');
        Assert.IsFalse(AskSetup.WritePermission(), 'API + Chat + LLM Chat cannot change the caps');

        LibraryLowerPermissions.SetO365Basic();
        LibraryLowerPermissions.AddPermissionSet('BIFROST LLM ori');
        Assert.IsTrue(AskSetup.WritePermission(), 'the language-model admin set changes the caps');
    end;

    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Permissions_AskCallerReadsTheRaisedCap()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC03/AC06] API + Chat + LLM Chat: the runner reads the raised cap 50, so 45 is not clamped; the tool stays read-only
        LibraryLowerPermissions.SetO365Basic();
        LibraryLowerPermissions.AddPermissionSet('BIFROST LLM ori');
        Initialize();
        SetCaps(50, 20, 20000);
        MockProvider.EnqueueAnswer(ToolCalls(Calls(1) + ',' + '{"id":"w1","name":"set_records","arguments":{}}'));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'ok'));
        LibraryLowerPermissions.SetO365Basic();
        LibraryLowerPermissions.AddPermissionSet('BIFROST API ori');
        LibraryLowerPermissions.AddPermissionSet('BIFROST Chat ori');
        LibraryLowerPermissions.AddPermissionSet('BIFROST LLM Chat ori');

        ResponseJson := Execute(Request('{"question":"Q","limits":{"maxToolCalls":45}}'));

        Assert.AreEqual('Success', ResponseJson.GetText('status'), Describe(ResponseJson));
        Assert.IsFalse(WarningsOf(ResponseJson).Contains('clamped:maxToolCalls'), Describe(ResponseJson));
        Assert.AreEqual(1, ResponseJson.GetInteger('deniedToolCalls'), 'a write tool is still denied with a raised cap');
    end;

    local procedure VerifySetupPage(LanguageId: Integer)
    var
        AskSetup: Record "LangModel Ask Setup ori";
        LangModelSetup: TestPage "LangModel Setup ori";
        PreviousLanguage: Integer;
    begin
        // [SCENARIO AC05] the setup page shows the six fields with the install values, saves valid values and refuses 1000 with a translated error
        Initialize();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);

        LangModelSetup.OpenEdit();
        Assert.AreEqual(40, LangModelSetup.AskMaxToolCallsCap.AsInteger(), 'install value shown');
        Assert.AreEqual(15, LangModelSetup.AskDefaultToolCalls.AsInteger(), 'default shown');
        Assert.AreEqual(20, LangModelSetup.AskMaxRoundsCap.AsInteger(), 'rounds cap shown');
        Assert.AreEqual(10, LangModelSetup.AskDefaultRounds.AsInteger(), 'rounds default shown');
        Assert.AreEqual(20000, LangModelSetup.AskMaxResultCharsCap.AsInteger(), 'result cap shown');
        Assert.AreEqual(8000, LangModelSetup.AskDefaultResultChars.AsInteger(), 'result default shown');
        Assert.IsTrue(LangModelSetup.AskMaxToolCallsCap.Editable(), 'editable for an administrator');
        LangModelSetup.AskMaxToolCallsCap.SetValue(150);
        LangModelSetup.AskMaxRoundsCap.SetValue(999);
        LangModelSetup.Close();

        AskSetup.Get();
        Assert.AreEqual(150, AskSetup."Ask Max Tool Calls Cap", 'the page saves the tool-call cap');
        Assert.AreEqual(999, AskSetup."Ask Max Rounds Cap", 'the page saves 999');

        // the refusal is the last step: asserterror rolls the transaction back
        LangModelSetup.OpenEdit();
        asserterror LangModelSetup.AskMaxRoundsCap.SetValue(1000);
        Assert.ExpectedError('999');
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure VerifyCountCap(FieldNo: Integer)
    begin
        Assert.AreEqual(1, ValidateInMemory(FieldNo, 1), '1 is accepted');
        Assert.AreEqual(999, ValidateInMemory(FieldNo, 999), '999 is accepted');
        asserterror ValidateInMemory(FieldNo, 0);
        Assert.ExpectedError('must be from 1 to 999');
        asserterror ValidateInMemory(FieldNo, 1000);
        Assert.ExpectedError('must be from 1 to 999');
    end;

    local procedure ValidateOnInstallValues(FieldNo: Integer; NewValue: Integer)
    var
        AskSetup: Record "LangModel Ask Setup ori";
        RecRef: RecordRef;
        FieldRef: FieldRef;
    begin
        AskSetup.Init();
        RecRef.GetTable(AskSetup);
        FieldRef := RecRef.Field(FieldNo);
        FieldRef.Validate(NewValue);
    end;

    local procedure ValidateInMemory(FieldNo: Integer; NewValue: Integer): Integer
    var
        AskSetup: Record "LangModel Ask Setup ori";
        RecRef: RecordRef;
        FieldRef: FieldRef;
    begin
        AskSetup.GetSetup();
        AskSetup."Ask Default Tool Calls" := 1;
        AskSetup."Ask Default Rounds" := 1;
        AskSetup."Ask Default Result Chars" := 1;
        RecRef.GetTable(AskSetup);
        FieldRef := RecRef.Field(FieldNo);
        FieldRef.Validate(NewValue);
        exit(FieldRef.Value());
    end;

    local procedure VerifyValues(AskSetup: Record "LangModel Ask Setup ori"; ToolCallsCap: Integer; RoundsCap: Integer; ResultCharsCap: Integer; DefaultToolCalls: Integer; DefaultRounds: Integer; DefaultResultChars: Integer)
    begin
        Assert.AreEqual(ToolCallsCap, AskSetup."Ask Max Tool Calls Cap", 'Ask Max Tool Calls Cap');
        Assert.AreEqual(RoundsCap, AskSetup."Ask Max Rounds Cap", 'Ask Max Rounds Cap');
        Assert.AreEqual(ResultCharsCap, AskSetup."Ask Max Result Chars Cap", 'Ask Max Result Chars Cap');
        Assert.AreEqual(DefaultToolCalls, AskSetup."Ask Default Tool Calls", 'Ask Default Tool Calls');
        Assert.AreEqual(DefaultRounds, AskSetup."Ask Default Rounds", 'Ask Default Rounds');
        Assert.AreEqual(DefaultResultChars, AskSetup."Ask Default Result Chars", 'Ask Default Result Chars');
    end;

    local procedure SetCaps(ToolCallsCap: Integer; RoundsCap: Integer; ResultCharsCap: Integer)
    var
        AskSetup: Record "LangModel Ask Setup ori";
    begin
        AskSetup.InitSetup();
        AskSetup.Get();
        SetLimits(ToolCallsCap, RoundsCap, ResultCharsCap, Min(AskSetup."Ask Default Tool Calls", ToolCallsCap), Min(AskSetup."Ask Default Rounds", RoundsCap), Min(AskSetup."Ask Default Result Chars", ResultCharsCap));
    end;

    local procedure SetDefaults(DefaultToolCalls: Integer; DefaultRounds: Integer; DefaultResultChars: Integer)
    var
        AskSetup: Record "LangModel Ask Setup ori";
    begin
        AskSetup.InitSetup();
        AskSetup.Get();
        SetLimits(AskSetup."Ask Max Tool Calls Cap", AskSetup."Ask Max Rounds Cap", AskSetup."Ask Max Result Chars Cap", DefaultToolCalls, DefaultRounds, DefaultResultChars);
    end;

    local procedure SetLimits(ToolCallsCap: Integer; RoundsCap: Integer; ResultCharsCap: Integer; DefaultToolCalls: Integer; DefaultRounds: Integer; DefaultResultChars: Integer)
    var
        AskSetup: Record "LangModel Ask Setup ori";
    begin
        AskSetup.InitSetup();
        AskSetup.Get();
        AskSetup."Ask Max Tool Calls Cap" := ToolCallsCap;
        AskSetup."Ask Max Rounds Cap" := RoundsCap;
        AskSetup."Ask Max Result Chars Cap" := ResultCharsCap;
        AskSetup."Ask Default Tool Calls" := DefaultToolCalls;
        AskSetup."Ask Default Rounds" := DefaultRounds;
        AskSetup."Ask Default Result Chars" := DefaultResultChars;
        AskSetup.Modify(true);
    end;

    local procedure Min(Left: Integer; Right: Integer): Integer
    begin
        if Left < Right then
            exit(Left);
        exit(Right);
    end;

    local procedure Calls(Count: Integer) CallsJson: Text
    var
        Index: Integer;
    begin
        for Index := 1 to Count do begin
            if Index > 1 then
                CallsJson += ',';
            CallsJson += StrSubstNo(CallTok, 'c' + Format(Index), 'who_am_i');
        end;
    end;

    local procedure ToolCalls(CallsJson: Text): Text
    begin
        exit(StrSubstNo(ToolCallTok, CallsJson));
    end;

    local procedure WarningsOf(ResponseJson: JsonObject) WarningsText: Text
    var
        Token: JsonToken;
    begin
        if ResponseJson.Get('warnings', Token) then
            Token.WriteTo(WarningsText);
    end;

    local procedure Request(DataJson: Text): Text
    var
        Data: JsonObject;
        DataText: Text;
    begin
        Data.ReadFrom(DataJson);
        Data.Add('roleCode', ModelCodeTok);
        Data.WriteTo(DataText);
        exit(DataText);
    end;

    local procedure Describe(ResponseJson: JsonObject) ResponseText: Text
    begin
        ResponseJson.WriteTo(ResponseText);
    end;

    local procedure Execute(RequestBody: Text) ResponseJson: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        EmptyTaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
        ResponseContentType: Text[100];
        ResponseText: Text;
    begin
        RequestContent.AddText(RequestBody);
        Dispatcher.EnqueueAndProcess("Message Type ori"::"LLM.Prompt.Ask", "Message Version ori"::"1.0", '', '', 'text/json', RequestContent, EmptyTaskId, 1033, MessageId, ResponseContent, ResponseContentType, ResponseTime);
        ResponseContent.GetSubText(ResponseText, 1);
        Assert.IsTrue(ResponseJson.ReadFrom(ResponseText), ResponseText);
    end;

    local procedure Initialize()
    var
        AskSetup: Record "LangModel Ask Setup ori";
    begin
        AskSetup.DeleteAll();
        InitializeModel();
    end;

    local procedure InitializeModel()
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
    begin
        MockProvider.Reset();
        MockProvider.SetIsConfigured(true);
        if BifrostLanguageModel.Get(ModelCodeTok) then
            BifrostLanguageModel.Delete(true);
        BifrostLanguageModel.Init();
        BifrostLanguageModel.Code := ModelCodeTok;
        BifrostLanguageModel."Chat Provider" := Enum::"Bifrost LangModel Prov. ori"::Mock;
        BifrostLanguageModel.Insert(true);
    end;
}
