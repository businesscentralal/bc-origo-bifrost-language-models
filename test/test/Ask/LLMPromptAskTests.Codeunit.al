namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests LLM.Prompt.Ask (#101) end to end through Foundation's dispatcher with the scripted "Mock Bifrost Chat Provider".
/// No real provider is called. Tool calls run through Foundation's MCP Tool Server as the test user.
/// </summary>
codeunit 96063 "LLM Prompt Ask Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        ModelCodeTok: Label 'ASK-MOCK', Locked = true;
        CopilotCodeTok: Label 'ASK-COPILOT', Locked = true;
        ReplyTok: Label '{"type":"reply","reply":"%1"}', Locked = true;
        ToolCallTok: Label '{"type":"tool_calls","toolCalls":[%1],"conversationState":"{\"messages\":[],\"model\":\"mock\"}"}', Locked = true;
        CallTok: Label '{"id":"%1","name":"%2","arguments":{}}', Locked = true;

    [Test]
    procedure Ask_ReplyWithoutTools_ReturnsCompleted()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC05] a reply with no tool call returns Success, one round, no tool calls, stopReason completed
        Initialize();
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'All good.'));

        ResponseJson := Execute(Request('{"question":"Is customer 10000 ready?"}'), 1033);

        Assert.AreEqual('Success', ResponseJson.GetText('status'), Describe(ResponseJson));
        Assert.AreEqual('All good.', ResponseJson.GetText('answer'), 'answer must be the reply');
        Assert.AreEqual(1, ResponseJson.GetInteger('rounds'), 'one round');
        Assert.AreEqual(0, ResponseJson.GetInteger('toolCalls'), 'no tool calls');
        Assert.AreEqual('completed', ResponseJson.GetText('stopReason'), 'stopReason');
        Assert.IsFalse(ResponseJson.Contains('trace'), 'trace is absent by default');
        Assert.IsFalse(ResponseJson.Contains('schemaValid'), 'schemaValid only with a schema');
    end;

    [Test]
    procedure Ask_ToolRoundsThenReply_CountsAndAnswersEveryCall()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
        ToolResults: JsonArray;
    begin
        // [SCENARIO AC06] two tool rounds then a reply: counters right, every call id gets a result
        Initialize();
        MockProvider.EnqueueAnswer(ToolCalls(StrSubstNo(CallTok, 'c1', 'who_am_i') + ',' + StrSubstNo(CallTok, 'c2', 'who_am_i')));
        MockProvider.EnqueueAnswer(ToolCalls(StrSubstNo(CallTok, 'c3', 'who_am_i')));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'Done.'));

        ResponseJson := Execute(Request('{"question":"Who am I?"}'), 1033);

        Assert.AreEqual('Success', ResponseJson.GetText('status'), Describe(ResponseJson));
        Assert.AreEqual('Done.', ResponseJson.GetText('answer'), 'final reply');
        Assert.AreEqual(3, ResponseJson.GetInteger('rounds'), 'three rounds');
        Assert.AreEqual(3, ResponseJson.GetInteger('toolCalls'), 'three tool calls');
        Assert.AreEqual(0, ResponseJson.GetInteger('deniedToolCalls'), 'none denied');
        ToolResults.ReadFrom(MockProvider.GetToolResultsLog().Get(1));
        Assert.AreEqual(2, ToolResults.Count(), 'both calls of round 1 get a result');
    end;

    [Test]
    procedure Ask_DeniedWriteCall_ReturnsToolErrorAndContinues()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC08] set_records is denied, returned to the model as an error, the loop continues
        Initialize();
        MockProvider.EnqueueAnswer(ToolCalls(StrSubstNo(CallTok, 'c1', 'set_records')));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'unknown'));

        ResponseJson := Execute(Request('{"question":"Change the customer."}'), 1033);

        Assert.AreEqual('Success', ResponseJson.GetText('status'), Describe(ResponseJson));
        Assert.AreEqual(1, ResponseJson.GetInteger('deniedToolCalls'), 'denied call counted');
        Assert.AreEqual(1, ResponseJson.GetInteger('toolCalls'), 'a denied call counts against the cap');
        Assert.IsTrue(MockProvider.GetToolResultsLog().Get(1).Contains('read-only'), 'the model is told the session is read-only');
    end;

    [Test]
    procedure Ask_MaxToolCallsReached_ForcesFinalRoundWithoutTools()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
        ToolResults: JsonArray;
        StateObject: JsonObject;
        AllowedToken: JsonToken;
    begin
        // [SCENARIO AC07] maxToolCalls 1 with two calls in the round: the second gets "limit reached", one final tools-free round
        Initialize();
        MockProvider.EnqueueAnswer(ToolCalls(StrSubstNo(CallTok, 'c1', 'who_am_i') + ',' + StrSubstNo(CallTok, 'c2', 'who_am_i')));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'Final.'));

        ResponseJson := Execute(Request('{"question":"Q","limits":{"maxToolCalls":1}}'), 1033);

        Assert.AreEqual('maxToolCalls', ResponseJson.GetText('stopReason'), Describe(ResponseJson));
        Assert.AreEqual('Final.', ResponseJson.GetText('answer'), 'final answer');
        Assert.AreEqual(1, ResponseJson.GetInteger('toolCalls'), 'one call ran');
        ToolResults.ReadFrom(MockProvider.GetToolResultsLog().Get(1));
        Assert.AreEqual(2, ToolResults.Count(), 'every call id gets a result');
        Assert.IsTrue(MockProvider.GetToolResultsLog().Get(1).Contains('limit reached'), 'the second call gets limit reached');
        StateObject.ReadFrom(MockProvider.GetStatesLog().Get(1));
        Assert.IsTrue(StateObject.Get('allowedTools', AllowedToken), 'the final state carries allowedTools');
        Assert.AreEqual(0, AllowedToken.AsArray().Count(), 'the final round offers no tools');
    end;

    [Test]
    procedure Ask_MaxRoundsReached_StopsWithMaxRounds()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC07] maxRounds 1: the first round asks for a tool, the final round answers
        Initialize();
        MockProvider.EnqueueAnswer(ToolCalls(StrSubstNo(CallTok, 'c1', 'who_am_i')));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'Final.'));

        ResponseJson := Execute(Request('{"question":"Q","limits":{"maxRounds":1}}'), 1033);

        Assert.AreEqual('maxRounds', ResponseJson.GetText('stopReason'), Describe(ResponseJson));
        Assert.AreEqual(2, ResponseJson.GetInteger('rounds'), 'the forced final round is counted');
    end;

    [Test]
    procedure Ask_LimitsAboveCaps_AreClampedWithWarnings()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
        WarningsText: Text;
    begin
        // [SCENARIO AC07] limits above 40, 20 and 20000 are clamped and each adds a clamped:<key> warning
        Initialize();
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'ok'));

        ResponseJson := Execute(Request('{"question":"Q","limits":{"maxToolCalls":99,"maxRounds":99,"maxResultChars":99999}}'), 1033);

        ResponseJson.GetArray('warnings').WriteTo(WarningsText);
        Assert.IsTrue(WarningsText.Contains('clamped:maxToolCalls'), WarningsText);
        Assert.IsTrue(WarningsText.Contains('clamped:maxRounds'), WarningsText);
        Assert.IsTrue(WarningsText.Contains('clamped:maxResultChars'), WarningsText);
    end;

    [Test]
    procedure Ask_SchemaValid_SetsData()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC12] a valid answer wrapped in a code fence sets data and schemaValid true
        Initialize();
        MockProvider.EnqueueAnswer('{"type":"reply","reply":"Here:\n```json\n{\"verdict\":\"pass\"}\n```"}');

        ResponseJson := Execute(Request('{"question":"Q","responseSchema":{"type":"object","required":["verdict"],"properties":{"verdict":{"type":"string","enum":["pass","fail","unknown"]}}}}'), 1033);

        Assert.IsTrue(ResponseJson.GetBoolean('schemaValid'), Describe(ResponseJson));
        Assert.AreEqual('pass', ResponseJson.GetObject('data').GetText('verdict'), 'data holds the parsed answer');
        Assert.AreEqual('completed', ResponseJson.GetText('stopReason'), 'completed');
    end;

    [Test]
    procedure Ask_SchemaInvalidTwice_EndsSchemaInvalidWithoutData()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
        RetryPayload: Text;
    begin
        // [SCENARIO AC12] an invalid answer is retried once through a new SendChatMessage carrying the errors
        Initialize();
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'not json'));
        MockProvider.EnqueueAnswer('{"type":"reply","reply":"{\"verdict\":\"maybe\"}"}');

        ResponseJson := Execute(Request('{"question":"Q","responseSchema":{"type":"object","required":["verdict"],"properties":{"verdict":{"type":"string","enum":["pass","fail"]}}}}'), 1033);

        Assert.AreEqual('Success', ResponseJson.GetText('status'), Describe(ResponseJson));
        Assert.IsFalse(ResponseJson.GetBoolean('schemaValid'), 'schemaValid false');
        Assert.AreEqual('schemaInvalid', ResponseJson.GetText('stopReason'), 'stopReason');
        Assert.IsFalse(ResponseJson.Contains('data'), 'no data');
        Assert.AreEqual(2, ResponseJson.GetInteger('rounds'), 'the retry counts as a round');
        Assert.AreEqual(2, MockProvider.GetSendPayloads().Count(), 'the retry is a new SendChatMessage');
        RetryPayload := MockProvider.GetSendPayloads().Get(2);
        Assert.IsTrue(RetryPayload.Contains('did not match'), 'the retry carries the validation errors');
    end;

    [Test]
    procedure Ask_Payload_CarriesHeadlessSuffixAndQuestionInUserMessage()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        Payload: JsonObject;
        SystemSuffix: Text;
        PayloadText: Text;
    begin
        // [SCENARIO AC13] systemSuffix holds HEADLESS MODE and instructions; QUESTION and CONTEXT stay in the user message
        Initialize();
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'ok'));

        Execute(Request('{"question":"Q1","context":{"customer":"C-CTX-1"},"instructions":"Be brief."}'), 1033);

        PayloadText := MockProvider.GetSendPayloads().Get(1);
        Payload.ReadFrom(PayloadText);
        SystemSuffix := Payload.GetText('systemSuffix');
        Assert.IsTrue(SystemSuffix.StartsWith('HEADLESS MODE:'), SystemSuffix);
        Assert.IsTrue(SystemSuffix.Contains('Be brief.'), 'instructions in the suffix');
        Assert.IsFalse(SystemSuffix.Contains('OUTPUT FORMAT'), 'no OUTPUT FORMAT without a schema');
        Assert.IsFalse(SystemSuffix.Contains('C-CTX-1'), 'the context is not in the system text');
        Assert.IsTrue(PayloadText.Contains('QUESTION:'), 'QUESTION in the user message');
        Assert.IsTrue(PayloadText.Contains('C-CTX-1'), 'CONTEXT in the user message');
        Assert.IsFalse(Payload.Contains('recordContext'), 'no RECORD CONTEXT without subject');
    end;

    [Test]
    procedure Ask_IncludeTrace_ReturnsTruncatedEntries()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
        Entry: JsonToken;
    begin
        // [SCENARIO AC15] includeTrace returns one entry per call with the documented fields
        Initialize();
        MockProvider.EnqueueAnswer(ToolCalls(StrSubstNo(CallTok, 'c1', 'who_am_i')));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'ok'));

        ResponseJson := Execute(Request('{"question":"Q","includeTrace":true}'), 1033);

        Assert.AreEqual(1, ResponseJson.GetArray('trace').Count(), Describe(ResponseJson));
        ResponseJson.GetArray('trace').Get(0, Entry);
        Assert.AreEqual('who_am_i', Entry.AsObject().GetText('tool'), 'tool');
        Assert.IsTrue(Entry.AsObject().Contains('preview'), 'preview');
        Assert.IsTrue(Entry.AsObject().Contains('resultChars'), 'resultChars');
    end;

    [Test]
    procedure Ask_ToolResultLongerThanMax_IsCutWithMarker()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC10] a tool result longer than maxResultChars reaches the provider cut, with a marker
        Initialize();
        MockProvider.EnqueueAnswer(ToolCalls(StrSubstNo(CallTok, 'c1', 'who_am_i')));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'ok'));

        ResponseJson := Execute(Request('{"question":"Q","limits":{"maxResultChars":20}}'), 1033);

        Assert.AreEqual('Success', ResponseJson.GetText('status'), Describe(ResponseJson));
        Assert.IsTrue(MockProvider.GetToolResultsLog().Get(1).Contains('truncated by Bifrost: 20 of'), MockProvider.GetToolResultsLog().Get(1));
    end;

    [Test]
    procedure Ask_FoundationRefusesTool_CountsToolErrorAndContinues()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC09] a tool call Foundation refuses comes back as a tool error, counted, and the run succeeds
        Initialize();
        MockProvider.EnqueueAnswer(ToolCalls('{"id":"c1","name":"get_records","arguments":{"tableName":"No Such Table LM101"}}'));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'unknown'));

        ResponseJson := Execute(Request('{"question":"Q"}'), 1033);

        Assert.AreEqual('Success', ResponseJson.GetText('status'), Describe(ResponseJson));
        Assert.AreEqual(1, ResponseJson.GetInteger('toolErrors'), Describe(ResponseJson));
        Assert.AreEqual(0, ResponseJson.GetInteger('deniedToolCalls'), 'not a policy denial');
    end;

    [Test]
    procedure Ask_TwentyRounds_CompletesWithoutTimeout()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        AskImpl: Codeunit "LLM Prompt Ask Impl ori";
        ResponseJson: JsonObject;
        Parameters: JsonArray;
        ParametersText: Text;
        Index: Integer;
    begin
        // [SCENARIO AC11] a run of 20 rounds completes; GetParameters declares no timeout
        Initialize();
        for Index := 1 to 19 do
            MockProvider.EnqueueAnswer(ToolCalls(StrSubstNo(CallTok, 'c' + Format(Index), 'who_am_i')));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'Done.'));

        ResponseJson := Execute(Request('{"question":"Q","limits":{"maxRounds":20,"maxToolCalls":40}}'), 1033);

        Assert.AreEqual('completed', ResponseJson.GetText('stopReason'), Describe(ResponseJson));
        Assert.AreEqual(20, ResponseJson.GetInteger('rounds'), 'twenty rounds');
        AskImpl.GetParameters(Parameters);
        Parameters.WriteTo(ParametersText);
        Assert.IsFalse(ParametersText.ToLower().Contains('timeout"'), 'no timeout parameter');
    end;

    [Test]
    procedure Ask_Usage_IsSumOfProviderUsage()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC16] usage is the sum of what the provider reported over the rounds; model and warnings are present
        Initialize();
        MockProvider.EnqueueAnswer('{"type":"tool_calls","toolCalls":[{"id":"c1","name":"who_am_i","arguments":{}}],"conversationState":"{\"messages\":[]}","usage":{"input_tokens":100,"output_tokens":10}}');
        MockProvider.EnqueueAnswer('{"type":"reply","reply":"ok","usage":{"input_tokens":50,"output_tokens":5}}');

        ResponseJson := Execute(Request('{"question":"Q"}'), 1033);

        Assert.AreEqual(150, ResponseJson.GetObject('usage').GetInteger('input_tokens'), Describe(ResponseJson));
        Assert.AreEqual(15, ResponseJson.GetObject('usage').GetInteger('output_tokens'), Describe(ResponseJson));
        Assert.AreEqual(ModelCodeTok, ResponseJson.GetObject('model').GetText('code'), 'model code');
        Assert.IsTrue(ResponseJson.Contains('warnings'), 'warnings present');
    end;

    [Test]
    procedure Ask_NoUsageReported_UsageAbsent()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC16] usage is absent when no provider reports it
        Initialize();
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'ok'));
        ResponseJson := Execute(Request('{"question":"Q"}'), 1033);
        Assert.IsFalse(ResponseJson.Contains('usage'), Describe(ResponseJson));
    end;

    [Test]
    procedure Ask_ProviderWithoutSplitTools_PreconditionFailed()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] a provider with no split tool execution is refused before any provider request
        Initialize();
        MockProvider.SetNoSplitToolExecution(true);
        ResponseJson := Execute(Request('{"question":"Q"}'), 1033);
        Assert.AreEqual('PreconditionFailed', ResponseJson.GetText('code'), Describe(ResponseJson));
        Assert.IsFalse(MockProvider.WasSendChatMessageCalled(), 'the provider must not be called');
    end;

    [Test]
    procedure Ask_MissingQuestion_MissingParameter_1033()
    begin
        // [SCENARIO AC03] question missing
        VerifyError('{"context":"x"}', 'MissingParameter', 1033);
    end;

    [Test]
    procedure Ask_EmptyQuestion_MissingParameter_1039()
    begin
        // [SCENARIO AC03] question empty, Icelandic
        VerifyError('{"question":""}', 'MissingParameter', 1039);
    end;

    [Test]
    procedure Ask_QuestionNotString_InvalidParameterFormat()
    begin
        // [SCENARIO AC03] question not a string
        VerifyError('{"question":42}', 'InvalidParameterFormat', 1033);
    end;

    [Test]
    procedure Ask_ContextNumber_InvalidParameterFormat()
    begin
        // [SCENARIO AC03] context of type number
        VerifyError('{"question":"Q","context":1}', 'InvalidParameterFormat', 1033);
    end;

    [Test]
    procedure Ask_ContextBoolean_InvalidParameterFormat()
    begin
        // [SCENARIO AC03] context of type Boolean
        VerifyError('{"question":"Q","context":true}', 'InvalidParameterFormat', 1033);
    end;

    [Test]
    procedure Ask_ContextArray_InvalidParameterFormat()
    begin
        // [SCENARIO AC03] context of type array
        VerifyError('{"question":"Q","context":[1]}', 'InvalidParameterFormat', 1033);
    end;

    [Test]
    procedure Ask_UnknownRoleCode_RecordNotFound()
    begin
        // [SCENARIO AC03] roleCode unknown
        VerifyError('{"question":"Q","roleCode":"NO-SUCH-MODEL"}', 'RecordNotFound', 1033);
    end;

    [Test]
    procedure Ask_LimitNotInteger_InvalidParameterFormat()
    begin
        // [SCENARIO AC03] limits non-integer
        VerifyError('{"question":"Q","limits":{"maxRounds":1.5}}', 'InvalidParameterFormat', 1033);
    end;

    [Test]
    procedure Ask_LimitBelowOne_InvalidParameter()
    begin
        // [SCENARIO AC03] limits below 1
        VerifyError('{"question":"Q","limits":{"maxToolCalls":0}}', 'InvalidParameter', 1033);
    end;

    [Test]
    procedure Ask_SchemaNotObject_InvalidParameterFormat()
    begin
        // [SCENARIO AC03] responseSchema not an object
        VerifyError('{"question":"Q","responseSchema":"x"}', 'InvalidParameterFormat', 1033);
    end;

    [Test]
    procedure Ask_SubjectUnknownTable_InvalidParameter()
    begin
        // [SCENARIO AC03] subject with an unknown table
        VerifyError('{"question":"Q","subject":{"table":"No Such Table XYZ","systemId":"6b1f3c9e-3c1e-4d6e-9d55-111111111111"}}', 'InvalidParameter', 1033);
    end;

    [Test]
    procedure Ask_SubjectInvalidGuid_InvalidParameter()
    begin
        // [SCENARIO AC03] subject with an invalid GUID
        VerifyError('{"question":"Q","subject":{"table":"Customer","systemId":"not-a-guid"}}', 'InvalidParameter', 1033);
    end;

    [Test]
    procedure Ask_ContextObject_IsAccepted()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC03] a context object is accepted
        Initialize();
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'ok'));
        ResponseJson := Execute(Request('{"question":"Q","context":{"a":1}}'), 1033);
        Assert.AreEqual('Success', ResponseJson.GetText('status'), Describe(ResponseJson));
    end;

    [Test]
    procedure Ask_CopilotModel_PreconditionFailedWithoutProviderCall_1033()
    begin
        // [SCENARIO AC04] Copilot as the selected model is refused, in English
        VerifyCopilotRefused(1033);
    end;

    [Test]
    procedure Ask_CopilotModel_PreconditionFailedWithoutProviderCall_1039()
    begin
        // [SCENARIO AC04] Copilot as the selected model is refused, in Icelandic
        VerifyCopilotRefused(1039);
    end;

    [Test]
    procedure Ask_NotConfigured_PreconditionFailed()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] no usable model: PreconditionFailed, the provider is not called
        Initialize();
        MockProvider.SetIsConfigured(false);
        ResponseJson := Execute(Request('{"question":"Q"}'), 1033);
        Assert.AreEqual('PreconditionFailed', ResponseJson.GetText('code'), Describe(ResponseJson));
        Assert.IsFalse(MockProvider.WasSendChatMessageCalled(), 'the provider must not be called');
    end;

    [Test]
    procedure Ask_ProviderError_ReturnsCodedError()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC01] a coded provider error ends the run with the coded error
        Initialize();
        MockProvider.EnqueueAnswer('{"error":"Could not reach the LLM API.","httpStatus":503}');
        ResponseJson := Execute(Request('{"question":"Q"}'), 1033);
        Assert.AreEqual('Error', ResponseJson.GetText('status'), Describe(ResponseJson));
    end;

    local procedure VerifyCopilotRefused(LanguageId: Integer)
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
    begin
        Initialize();
        if not BifrostLanguageModel.Get(CopilotCodeTok) then begin
            BifrostLanguageModel.Init();
            BifrostLanguageModel.Code := CopilotCodeTok;
            BifrostLanguageModel."Chat Provider" := Enum::"Bifrost LangModel Prov. ori"::Copilot;
            BifrostLanguageModel.Insert(true);
        end;
        ResponseJson := Execute(StrSubstNo('{"question":"Q","roleCode":"%1"}', CopilotCodeTok), LanguageId);
        Assert.AreEqual('PreconditionFailed', ResponseJson.GetText('code'), Describe(ResponseJson));
        Assert.IsTrue(ResponseJson.GetText('error').Contains('Copilot'), 'the refusal names Copilot');
        Assert.IsFalse(MockProvider.WasSendChatMessageCalled(), 'the provider must not be called');
        BifrostLanguageModel.Get(CopilotCodeTok);
        BifrostLanguageModel.Delete(true);
    end;

    local procedure VerifyError(RequestBody: Text; ExpectedCode: Text; LanguageId: Integer)
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
    begin
        Initialize();
        ResponseJson := Execute(Request(RequestBody), LanguageId);
        Assert.AreEqual('Error', ResponseJson.GetText('status'), Describe(ResponseJson));
        Assert.AreEqual(ExpectedCode, ResponseJson.GetText('code'), Describe(ResponseJson));
        Assert.IsFalse(MockProvider.WasSendChatMessageCalled(), 'the provider must not be called');
    end;

    local procedure Request(DataJson: Text): Text
    var
        Data: JsonObject;
        DataText: Text;
    begin
        Data.ReadFrom(DataJson);
        if not Data.Contains('roleCode') then
            Data.Add('roleCode', ModelCodeTok);
        Data.WriteTo(DataText);
        exit(DataText);
    end;

    local procedure ToolCalls(CallsJson: Text): Text
    begin
        exit(StrSubstNo(ToolCallTok, CallsJson));
    end;

    local procedure Describe(ResponseJson: JsonObject) ResponseText: Text
    begin
        ResponseJson.WriteTo(ResponseText);
    end;

    local procedure Execute(RequestBody: Text; LanguageId: Integer) ResponseJson: JsonObject
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
        Dispatcher.EnqueueAndProcess("Message Type ori"::"LLM.Prompt.Ask", "Message Version ori"::"1.0", '', '', 'text/json', RequestContent, EmptyTaskId, LanguageId, MessageId, ResponseContent, ResponseContentType, ResponseTime);
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
