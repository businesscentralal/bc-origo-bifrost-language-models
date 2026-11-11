namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests the ORI-LM-ASK-* telemetry of LLM.Prompt.Ask (#102): the six events with id, verbosity and the terminal-event rule,
/// the dimension allow-list, no content in any dimension, callerSource normalization and language-independent numbers.
/// Events are observed through the test seam of "LLM Ask Telemetry ori"; the scripted "Mock Bifrost Chat Provider" runs the loop.
/// </summary>
codeunit 96066 "LLM Ask Telemetry Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        ModelCodeTok: Label 'ASK-TELE', Locked = true;
        CopilotCodeTok: Label 'ASK-TELE-COP', Locked = true;
        ReplyTok: Label '{"type":"reply","reply":"%1"}', Locked = true;
        ToolCallTok: Label '{"type":"tool_calls","toolCalls":[%1],"conversationState":"{\"messages\":[],\"model\":\"mock\"}"}', Locked = true;
        CallTok: Label '{"id":"%1","name":"%2","arguments":%3}', Locked = true;
        SentinelTok: Label 'ZQXSENT', Locked = true;

    [Test]
    procedure Telemetry_Completed_EmitsStartedThenCompleted()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        Spy: Codeunit "LLM Ask Telemetry Spy";
        Dimensions: Dictionary of [Text, Text];
    begin
        // [SCENARIO AC01] a plain reply: started (Normal) then exactly one completed (Normal)
        Initialize();
        BindSubscription(Spy);
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'All good.'));

        Execute('{"question":"Q"}', 1033, '');

        Assert.AreEqual(2, Spy.Count(), 'started and completed');
        Assert.AreEqual('ORI-LM-ASK-0001', Spy.GetId(1), 'started id');
        Assert.AreEqual(Format(Verbosity::Normal), Spy.GetVerbosity(1), 'started verbosity');
        Assert.AreEqual('ORI-LM-ASK-0002', Spy.GetId(2), 'completed id');
        Assert.AreEqual(Format(Verbosity::Normal), Spy.GetVerbosity(2), 'completed verbosity');
        Dimensions := Spy.GetDimensions(2);
        Assert.AreEqual('Bifrost.LanguageModels.Ask', Dimensions.Get('Category'), 'Category');
        Assert.AreEqual('Mock', Dimensions.Get('provider'), 'provider is the enum name');
        Assert.AreEqual(ModelCodeTok, Dimensions.Get('modelCode'), 'modelCode');
        Assert.AreEqual('1', Dimensions.Get('rounds'), 'rounds');
        Assert.AreEqual('0', Dimensions.Get('toolCalls'), 'toolCalls');
        Assert.AreEqual('0', Dimensions.Get('toolErrors'), 'toolErrors');
        Assert.AreEqual('0', Dimensions.Get('deniedToolCalls'), 'deniedToolCalls');
        Assert.AreEqual('completed', Dimensions.Get('stopReason'), 'stopReason');
        Assert.AreEqual('notRequested', Dimensions.Get('schemaValid'), 'schemaValid');
        Assert.IsTrue(Dimensions.Get('callerSource') in ['Direct', 'Queue', 'Task', 'Dispatcher'], 'callerSource is a fixed invocation name');
        Assert.IsTrue(Dimensions.ContainsKey('durationMs'), 'durationMs');
        VerifyAllowList(Spy);
    end;

    [Test]
    procedure Telemetry_SchemaInvalid_EmitsCompletedWithSchemaFalse()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        Spy: Codeunit "LLM Ask Telemetry Spy";
        Dimensions: Dictionary of [Text, Text];
    begin
        // [SCENARIO AC01] stopReason schemaInvalid is reported by the completed event with schemaValid false
        Initialize();
        BindSubscription(Spy);
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'not json'));
        MockProvider.EnqueueAnswer('{"type":"reply","reply":"{\"verdict\":\"maybe\"}"}');

        Execute('{"question":"Q","responseSchema":{"type":"object","required":["verdict"],"properties":{"verdict":{"type":"string","enum":["pass","fail"]}}}}', 1033, '');

        Assert.AreEqual(2, Spy.Count(), 'started and one terminal event');
        Assert.AreEqual('ORI-LM-ASK-0002', Spy.GetId(2), 'completed id');
        Dimensions := Spy.GetDimensions(2);
        Assert.AreEqual('schemaInvalid', Dimensions.Get('stopReason'), 'stopReason');
        Assert.AreEqual('false', Dimensions.Get('schemaValid'), 'schemaValid');
        Assert.AreEqual('2', Dimensions.Get('rounds'), 'rounds');
    end;

    [Test]
    procedure Telemetry_SchemaValid_ReportsTrue()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        Spy: Codeunit "LLM Ask Telemetry Spy";
    begin
        // [SCENARIO AC01] a valid answer reports schemaValid true
        Initialize();
        BindSubscription(Spy);
        MockProvider.EnqueueAnswer('{"type":"reply","reply":"{\"verdict\":\"pass\"}"}');

        Execute('{"question":"Q","responseSchema":{"type":"object","required":["verdict"],"properties":{"verdict":{"type":"string"}}}}', 1033, '');

        Assert.AreEqual('ORI-LM-ASK-0002', Spy.GetId(2), 'completed id');
        Assert.AreEqual('true', Spy.GetDimensions(2).Get('schemaValid'), 'schemaValid');
    end;

    [Test]
    procedure Telemetry_MaxToolCalls_EmitsLimitHitWarning()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        Spy: Codeunit "LLM Ask Telemetry Spy";
        Dimensions: Dictionary of [Text, Text];
    begin
        // [SCENARIO AC01] maxToolCalls: started then one limitHit (Warning)
        Initialize();
        BindSubscription(Spy);
        MockProvider.EnqueueAnswer(ToolCalls(StrSubstNo(CallTok, 'c1', 'who_am_i', '{}') + ',' + StrSubstNo(CallTok, 'c2', 'who_am_i', '{}')));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'Final.'));

        Execute('{"question":"Q","limits":{"maxToolCalls":1}}', 1033, '');

        Assert.AreEqual(2, Spy.Count(), 'started and limitHit');
        Assert.AreEqual('ORI-LM-ASK-0003', Spy.GetId(2), 'limitHit id');
        Assert.AreEqual(Format(Verbosity::Warning), Spy.GetVerbosity(2), 'limitHit verbosity');
        Dimensions := Spy.GetDimensions(2);
        Assert.AreEqual('maxToolCalls', Dimensions.Get('stopReason'), 'stopReason');
        Assert.AreEqual('1', Dimensions.Get('toolCalls'), 'toolCalls');
    end;

    [Test]
    procedure Telemetry_MaxRounds_EmitsLimitHitWarning()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        Spy: Codeunit "LLM Ask Telemetry Spy";
    begin
        // [SCENARIO AC01] maxRounds: started then one limitHit (Warning)
        Initialize();
        BindSubscription(Spy);
        MockProvider.EnqueueAnswer(ToolCalls(StrSubstNo(CallTok, 'c1', 'who_am_i', '{}')));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'Final.'));

        Execute('{"question":"Q","limits":{"maxRounds":1}}', 1033, '');

        Assert.AreEqual(2, Spy.Count(), 'started and limitHit');
        Assert.AreEqual('ORI-LM-ASK-0003', Spy.GetId(2), 'limitHit id');
        Assert.AreEqual('maxRounds', Spy.GetDimensions(2).Get('stopReason'), 'stopReason');
    end;

    [Test]
    procedure Telemetry_DeniedCall_EmitsDeniedBeforeTerminalEvent()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        Spy: Codeunit "LLM Ask Telemetry Spy";
        Dimensions: Dictionary of [Text, Text];
    begin
        // [SCENARIO AC01] a denied tool call: started, one denied (Warning, a count), then completed
        Initialize();
        BindSubscription(Spy);
        MockProvider.EnqueueAnswer(ToolCalls(StrSubstNo(CallTok, 'c1', 'set_records', '{}') + ',' + StrSubstNo(CallTok, 'c2', 'set_records', '{}')));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'unknown'));

        Execute('{"question":"Change the customer."}', 1033, '');

        Assert.AreEqual(3, Spy.Count(), 'started, denied, completed');
        Assert.AreEqual('ORI-LM-ASK-0001', Spy.GetId(1), 'started');
        Assert.AreEqual('ORI-LM-ASK-0004', Spy.GetId(2), 'denied comes before the terminal event');
        Assert.AreEqual(Format(Verbosity::Warning), Spy.GetVerbosity(2), 'denied verbosity');
        Assert.AreEqual('ORI-LM-ASK-0002', Spy.GetId(3), 'completed');
        Dimensions := Spy.GetDimensions(2);
        Assert.AreEqual('2', Dimensions.Get('deniedToolCalls'), 'a count, not one event per call');
        Assert.IsFalse(Dimensions.ContainsKey('set_records'), 'no tool name key');
        VerifyAllowList(Spy);
    end;

    [Test]
    procedure Telemetry_ProviderError_EmitsProviderErrorEvent()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        Spy: Codeunit "LLM Ask Telemetry Spy";
    begin
        // [SCENARIO AC01] a provider error: started then exactly one providerError (Error)
        Initialize();
        BindSubscription(Spy);
        MockProvider.EnqueueAnswer('{"error":"Could not reach the LLM API.","httpStatus":503}');

        Execute('{"question":"Q"}', 1033, '');

        Assert.AreEqual(2, Spy.Count(), 'started and providerError');
        Assert.AreEqual('ORI-LM-ASK-0005', Spy.GetId(2), 'providerError id');
        Assert.AreEqual(Format(Verbosity::Error), Spy.GetVerbosity(2), 'providerError verbosity');
        Assert.AreEqual('providerError', Spy.GetDimensions(2).Get('stopReason'), 'stopReason');
    end;

    [Test]
    procedure Telemetry_CopilotRefused_EmitsOnlyProviderNotSupported()
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
        Spy: Codeunit "LLM Ask Telemetry Spy";
        Dimensions: Dictionary of [Text, Text];
    begin
        // [SCENARIO AC01] Copilot is refused: one providerNotSupported (Warning) with provider and Category only, no started event
        Initialize();
        BifrostLanguageModel.Init();
        BifrostLanguageModel.Code := CopilotCodeTok;
        BifrostLanguageModel."Chat Provider" := Enum::"Bifrost LangModel Prov. ori"::Copilot;
        BifrostLanguageModel.Insert(true);
        BindSubscription(Spy);

        Execute(StrSubstNo('{"question":"Q","roleCode":"%1"}', CopilotCodeTok), 1033, CopilotCodeTok);

        Assert.AreEqual(1, Spy.Count(), 'only providerNotSupported');
        Assert.AreEqual('ORI-LM-ASK-0006', Spy.GetId(1), 'id');
        Assert.AreEqual(Format(Verbosity::Warning), Spy.GetVerbosity(1), 'verbosity');
        Dimensions := Spy.GetDimensions(1);
        Assert.AreEqual(2, Dimensions.Count(), 'Category and provider only');
        Assert.AreEqual('Copilot', Dimensions.Get('provider'), 'provider');
        BifrostLanguageModel.Get(CopilotCodeTok);
        BifrostLanguageModel.Delete(true);
    end;

    [Test]
    procedure Telemetry_ProviderWithoutSplitTools_EmitsProviderNotSupported()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        Spy: Codeunit "LLM Ask Telemetry Spy";
    begin
        // [SCENARIO AC01] a provider without split tool execution is refused: one providerNotSupported, no started event
        Initialize();
        BindSubscription(Spy);
        MockProvider.SetNoSplitToolExecution(true);

        Execute('{"question":"Q"}', 1033, '');

        Assert.AreEqual(1, Spy.Count(), 'only providerNotSupported');
        Assert.AreEqual('ORI-LM-ASK-0006', Spy.GetId(1), 'id');
        Assert.AreEqual('Mock', Spy.GetDimensions(1).Get('provider'), 'provider');
    end;

    [Test]
    procedure Telemetry_ValidationRefusal_EmitsNoEvent()
    var
        Spy: Codeunit "LLM Ask Telemetry Spy";
    begin
        // [SCENARIO AC01] a request refused by validation never started: no event
        Initialize();
        BindSubscription(Spy);

        Execute('{"question":""}', 1033, '');

        Assert.AreEqual(0, Spy.Count(), 'no event');
    end;

    [Test]
    procedure Telemetry_BuildDimensions_ReturnsOnlyAllowListedKeys()
    var
        AskTelemetry: Codeunit "LLM Ask Telemetry ori";
        Dimensions: Dictionary of [Text, Text];
        Allowed: List of [Text];
        EventId: Text;
        DimensionKey: Text;
        Index: Integer;
    begin
        // [SCENARIO AC02] for every event BuildDimensions returns only keys from the allow-list
        Allowed := AskTelemetry.GetAllowedKeys();
        Assert.AreEqual(11, Allowed.Count(), 'the allow-list has eleven keys');
        for Index := 1 to 6 do begin
            EventId := StrSubstNo('ORI-LM-ASK-000%1', Index);
            Dimensions := AskTelemetry.BuildDimensions(EventId, 'Mock', 'CODE', 'x', 1, 2, 3, 4, 'completed', 5, 'true');
            foreach DimensionKey in Dimensions.Keys() do
                Assert.IsTrue(Allowed.Contains(DimensionKey), StrSubstNo('%1 carries %2 which is not allow-listed', EventId, DimensionKey));
        end;
        Dimensions := AskTelemetry.BuildDimensions('ORI-LM-ASK-0006', 'Mock', 'CODE', 'x', 1, 2, 3, 4, 'completed', 5, 'true');
        Assert.AreEqual(2, Dimensions.Count(), 'event 0006 carries Category and provider only');
        Dimensions := AskTelemetry.BuildDimensions('ORI-LM-ASK-0001', 'Mock', 'CODE', 'x', 1, 2, 3, 4, 'completed', 5, 'true');
        Assert.AreEqual(4, Dimensions.Count(), 'event 0001 carries Category, provider, modelCode and callerSource');
        Dimensions := AskTelemetry.BuildDimensions('ORI-LM-ASK-0002', 'Mock', 'CODE', 'x', 1, 2, 3, 4, 'completed', 5, 'true');
        Assert.AreEqual(11, Dimensions.Count(), 'a terminal event carries all eleven');
    end;

    [Test]
    procedure Telemetry_BuildDimensions_NormalizesStopReasonAndSchemaValid()
    var
        AskTelemetry: Codeunit "LLM Ask Telemetry ori";
        Dimensions: Dictionary of [Text, Text];
    begin
        // [SCENARIO AC02] free text in stopReason or schemaValid never reaches a dimension
        Dimensions := AskTelemetry.BuildDimensions('ORI-LM-ASK-0002', 'Mock', 'CODE', '', 1, 1, 0, 0, SentinelTok, 1, SentinelTok);
        Assert.AreEqual('unknown', Dimensions.Get('stopReason'), 'unknown stopReason is not passed through');
        Assert.AreEqual('notRequested', Dimensions.Get('schemaValid'), 'unknown schemaValid is not passed through');
    end;

    [Test]
    procedure Telemetry_Sentinels_NeverReachADimension()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        Spy: Codeunit "LLM Ask Telemetry Spy";
        Dimensions: Dictionary of [Text, Text];
        DimensionKey: Text;
        Index: Integer;
        Request: Text;
    begin
        // [SCENARIO AC03] sentinels in question, context, instructions, subject, answer, tool argument, tool result and trace never appear
        Initialize();
        BindSubscription(Spy);
        MockProvider.EnqueueAnswer(ToolCalls(StrSubstNo(CallTok, 'c1', 'who_am_i', StrSubstNo('{"note":"%1ARG"}', SentinelTok)) + ',' + StrSubstNo(CallTok, 'c2', 'set_records', StrSubstNo('{"note":"%1DENIED"}', SentinelTok))));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, SentinelTok + 'ANSWER'));
        Request := StrSubstNo('{"question":"%1Q","context":"%1C","instructions":"%1I","includeTrace":true}', SentinelTok);

        Execute(Request, 1033, SentinelTok + 'SOURCE');

        Assert.IsTrue(Spy.Count() >= 3, 'started, denied and a terminal event');
        for Index := 1 to Spy.Count() do begin
            Dimensions := Spy.GetDimensions(Index);
            foreach DimensionKey in Dimensions.Keys() do begin
                Assert.IsFalse(DimensionKey.Contains(SentinelTok), 'a key carries a sentinel');
                Assert.IsFalse(Dimensions.Get(DimensionKey).Contains(SentinelTok), StrSubstNo('dimension %1 carries a sentinel', DimensionKey));
                Assert.IsFalse(Dimensions.Get(DimensionKey).Contains('who_am_i'), 'a tool name reaches a dimension');
                Assert.IsFalse(Dimensions.Get(DimensionKey).Contains('set_records'), 'a denied tool name reaches a dimension');
            end;
            Assert.IsTrue(Dimensions.Get('callerSource') in ['Direct', 'Queue', 'Task', 'Dispatcher'], 'a raw source is never logged');
        end;
        VerifyAllowList(Spy);
    end;

    [Test]
    procedure Telemetry_CallerName_IsFixedFromInvocationSource()
    var
        AskTelemetry: Codeunit "LLM Ask Telemetry ori";
        Dimensions: Dictionary of [Text, Text];
    begin
        // [SCENARIO AC04] callerSource is a fixed name from Foundation's trusted invocation source; caller text never reaches it
        Assert.AreEqual('Direct', AskTelemetry.GetCallerName("Invocation Source ori"::Direct), 'direct');
        Assert.AreEqual('Queue', AskTelemetry.GetCallerName("Invocation Source ori"::Queue), 'queue');
        Assert.AreEqual('Task', AskTelemetry.GetCallerName("Invocation Source ori"::Task), 'task');
        Assert.AreEqual('Dispatcher', AskTelemetry.GetCallerName("Invocation Source ori"::Dispatcher), 'dispatcher');
        Dimensions := AskTelemetry.BuildDimensions('ORI-LM-ASK-0001', 'Mock', 'CODE', 'Bifrost Orchestrator Playbook', 0, 0, 0, 0, '', 0, '');
        Assert.AreEqual('Other', Dimensions.Get('callerSource'), 'any other text, including a raw Source, is Other');
        Dimensions := AskTelemetry.BuildDimensions('ORI-LM-ASK-0001', 'Mock', 'CODE', PadStr('', 250, 'x'), 0, 0, 0, 0, '', 0, '');
        Assert.AreEqual('Other', Dimensions.Get('callerSource'), '250 characters');
        Dimensions := AskTelemetry.BuildDimensions('ORI-LM-ASK-0001', 'Mock', 'CODE', '', 0, 0, 0, 0, '', 0, '');
        Assert.AreEqual('Other', Dimensions.Get('callerSource'), 'empty');
    end;

    [Test]
    procedure Telemetry_NumericDimensions_AreSameIn1033And1039()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        Spy1033: Codeunit "LLM Ask Telemetry Spy";
        Spy1039: Codeunit "LLM Ask Telemetry Spy";
        PropName: Text;
        PropNames: List of [Text];
    begin
        // [SCENARIO AC05] rounds, toolCalls, toolErrors and deniedToolCalls and the provider name do not depend on the session language
        Initialize();
        PropNames := GetNumericKeys();
        BindSubscription(Spy1033);
        MockProvider.EnqueueAnswer(ToolCalls(StrSubstNo(CallTok, 'c1', 'who_am_i', '{}') + ',' + StrSubstNo(CallTok, 'c2', 'set_records', '{}')));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'done'));
        Execute('{"question":"Q"}', 1033, '');
        UnbindSubscription(Spy1033);

        BindSubscription(Spy1039);
        MockProvider.EnqueueAnswer(ToolCalls(StrSubstNo(CallTok, 'c1', 'who_am_i', '{}') + ',' + StrSubstNo(CallTok, 'c2', 'set_records', '{}')));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'done'));
        Execute('{"question":"Q"}', 1039, '');

        Assert.AreEqual(Spy1033.Count(), Spy1039.Count(), 'same events');
        foreach PropName in PropNames do
            Assert.AreEqual(Spy1033.GetDimensions(Spy1033.Count()).Get(PropName), Spy1039.GetDimensions(Spy1039.Count()).Get(PropName), PropName + ' differs between 1033 and 1039');
        Assert.AreEqual('2', Spy1039.GetDimensions(Spy1039.Count()).Get('toolCalls'), 'two tool calls');
        Assert.AreEqual('1', Spy1039.GetDimensions(Spy1039.Count()).Get('deniedToolCalls'), 'one denied');
    end;

    [Test]
    procedure Telemetry_Logging_DoesNotChangeTheResponse()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        Spy: Codeunit "LLM Ask Telemetry Spy";
        WithSpy: JsonObject;
        WithoutSpy: JsonObject;
    begin
        // [SCENARIO AC06] a run answers the same whether or not a subscriber observes the events
        Initialize();
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'same'));
        WithoutSpy := Execute('{"question":"Q"}', 1033, '');
        BindSubscription(Spy);
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'same'));
        WithSpy := Execute('{"question":"Q"}', 1033, '');

        Assert.AreEqual(WithoutSpy.GetText('status'), WithSpy.GetText('status'), 'status');
        Assert.AreEqual(WithoutSpy.GetText('answer'), WithSpy.GetText('answer'), 'answer');
        Assert.AreEqual(WithoutSpy.GetInteger('rounds'), WithSpy.GetInteger('rounds'), 'rounds');
    end;

    local procedure GetNumericKeys() Names: List of [Text]
    begin
        Names.Add('rounds');
        Names.Add('toolCalls');
        Names.Add('toolErrors');
        Names.Add('deniedToolCalls');
        Names.Add('stopReason');
        Names.Add('provider');
        Names.Add('modelCode');
    end;

    local procedure VerifyAllowList(var Spy: Codeunit "LLM Ask Telemetry Spy")
    var
        AskTelemetry: Codeunit "LLM Ask Telemetry ori";
        Allowed: List of [Text];
        DimensionKey: Text;
        Index: Integer;
    begin
        Allowed := AskTelemetry.GetAllowedKeys();
        for Index := 1 to Spy.Count() do
            foreach DimensionKey in Spy.GetDimensions(Index).Keys() do
                Assert.IsTrue(Allowed.Contains(DimensionKey), StrSubstNo('%1 carries %2 which is not allow-listed', Spy.GetId(Index), DimensionKey));
    end;

    local procedure ToolCalls(CallsJson: Text): Text
    begin
        exit(StrSubstNo(ToolCallTok, CallsJson));
    end;

    local procedure Execute(RequestBody: Text; LanguageId: Integer; Source: Text) ResponseJson: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        Data: JsonObject;
        EmptyTaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
        ResponseContentType: Text[100];
        ResponseText: Text;
        DataText: Text;
        SourceText: Text[250];
    begin
        Data.ReadFrom(RequestBody);
        if not Data.Contains('roleCode') then
            Data.Add('roleCode', ModelCodeTok);
        Data.WriteTo(DataText);
        SourceText := CopyStr(Source, 1, MaxStrLen(SourceText));
        RequestContent.AddText(DataText);
        Dispatcher.EnqueueAndProcess("Message Type ori"::"LLM.Prompt.Ask", "Message Version ori"::"1.0", '', SourceText, 'text/json', RequestContent, EmptyTaskId, LanguageId, MessageId, ResponseContent, ResponseContentType, ResponseTime);
        ResponseContent.GetSubText(ResponseText, 1);
        Assert.IsTrue(ResponseJson.ReadFrom(ResponseText), ResponseText);
    end;

    local procedure Initialize()
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
