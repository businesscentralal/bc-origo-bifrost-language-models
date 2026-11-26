namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests #171: no runtime error leaks out of the LLM.Prompt.Ask tool loop. Non-object tool arguments and results,
/// a tool that fails with a JSON cast error, usage sums above 2^31 and a provider failure after tool rounds.
/// Mock provider only; tool calls are answered by this codeunit through the OnBeforeCallTool test hook when bound.
/// </summary>
codeunit 96086 "LLM 171 Ask Loop Error Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;
    EventSubscriberInstance = Manual;

    var
        Assert: Codeunit "Library Assert";
        ToolMode: Text;
        ModelCodeTok: Label 'ASK-171', Locked = true;
        ReplyTok: Label '{"type":"reply","reply":"%1"}', Locked = true;
        ToolCallTok: Label '{"type":"tool_calls","toolCalls":[%1],"conversationState":"{\"messages\":[],\"model\":\"mock\"}"}', Locked = true;
        UsageRoundTok: Label '{"type":"tool_calls","toolCalls":[{"id":"c%1","name":"who_am_i","arguments":{}}],"conversationState":"{\"messages\":[]}","usage":{"input_tokens":2000000000,"cost_in_usd_ticks":1500000000}}', Comment = '%1 = call number', Locked = true;

    [Test]
    procedure Ask_ToolArgumentsNotObject_RunWithEmptyArguments()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC1] tool arguments that are an array, a string, a number or null run as an empty object; no runtime error
        Initialize();
        MockProvider.EnqueueAnswer(StrSubstNo(ToolCallTok, '{"id":"a1","name":"who_am_i","arguments":[1,2]},{"id":"a2","name":"who_am_i","arguments":"text"},{"id":"a3","name":"who_am_i","arguments":42},{"id":"a4","name":"who_am_i","arguments":null}'));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'ok'));

        ResponseJson := Execute(Request('{"question":"Q"}'), 1033);

        Assert.AreEqual('Success', ResponseJson.GetText('status'), Describe(ResponseJson));
        Assert.AreEqual('completed', ResponseJson.GetText('stopReason'), Describe(ResponseJson));
        Assert.AreEqual(4, ResponseJson.GetInteger('toolCalls'), Describe(ResponseJson));
        Assert.AreEqual(0, ResponseJson.GetInteger('toolErrors'), Describe(ResponseJson));
    end;

    [Test]
    procedure Ask_ToolCallEntriesNotObject_AreSkipped()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC1 edge] toolCalls entries that are not objects are skipped, the object entry still runs
        Initialize();
        MockProvider.EnqueueAnswer(StrSubstNo(ToolCallTok, '"who_am_i",7,[1],{"id":"b1","name":"who_am_i","arguments":{}}'));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'ok'));

        ResponseJson := Execute(Request('{"question":"Q"}'), 1039);

        Assert.AreEqual('Success', ResponseJson.GetText('status'), Describe(ResponseJson));
        Assert.AreEqual(1, ResponseJson.GetInteger('toolCalls'), Describe(ResponseJson));
    end;

    [Test]
    procedure Ask_ToolResultArray_ReachesModel()
    begin
        // [SCENARIO AC1] a tool result that is a JSON array reaches the model as it is; no runtime error
        VerifyNonObjectResult('array', '[1,2,3]');
    end;

    [Test]
    procedure Ask_ToolResultString_ReachesModel()
    begin
        // [SCENARIO AC1] a tool result that is a JSON string reaches the model as it is
        VerifyNonObjectResult('string', '"plain"');
    end;

    [Test]
    procedure Ask_ToolResultNumber_ReachesModel()
    begin
        // [SCENARIO AC1] a tool result that is a JSON number reaches the model as it is
        VerifyNonObjectResult('number', '42');
    end;

    [Test]
    procedure Ask_ToolCastError_ModelGetsToolError_1033()
    begin
        // [SCENARIO AC1] a tool that fails with a NavJsonToken to NavJsonObject cast error: the model gets a tool error and the run succeeds
        VerifyCastErrorBecomesToolError(1033);
    end;

    [Test]
    procedure Ask_ToolCastError_ModelGetsToolError_1039()
    begin
        // [SCENARIO AC1] the same in Icelandic (the runtime text is localized)
        VerifyCastErrorBecomesToolError(1039);
    end;

    [Test]
    procedure Ask_UsageAbove2Pow31_SumsWithoutOverflow()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
        UsageJson: JsonObject;
    begin
        // [SCENARIO AC2] usage and cost ticks summed over three rounds pass 2^31; no overflow, exact sums
        Initialize();
        MockProvider.EnqueueAnswer(StrSubstNo(UsageRoundTok, 1));
        MockProvider.EnqueueAnswer(StrSubstNo(UsageRoundTok, 2));
        MockProvider.EnqueueAnswer('{"type":"reply","reply":"ok","usage":{"input_tokens":2000000000,"cost_in_usd_ticks":3000000000}}');

        ResponseJson := Execute(Request('{"question":"Q"}'), 1033);

        Assert.AreEqual('Success', ResponseJson.GetText('status'), Describe(ResponseJson));
        UsageJson := ResponseJson.GetObject('usage');
        Assert.AreEqual(6000000000.0, UsageJson.GetDecimal('input_tokens'), Describe(ResponseJson));
        Assert.AreEqual(6000000000.0, UsageJson.GetDecimal('cost_in_usd_ticks'), 'a single value above 2^31 is summed too');
    end;

    [Test]
    procedure Ask_UsageNonNumberValues_AreLeftOut()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
        UsageJson: JsonObject;
    begin
        // [SCENARIO AC2 edge] usage entries that are objects, null or text do not fail the run and are not summed
        Initialize();
        MockProvider.EnqueueAnswer('{"type":"reply","reply":"ok","usage":{"input_tokens":5,"input_tokens_details":{"cached_tokens":1},"model":"grok","extra":null}}');

        ResponseJson := Execute(Request('{"question":"Q"}'), 1033);

        Assert.AreEqual('Success', ResponseJson.GetText('status'), Describe(ResponseJson));
        UsageJson := ResponseJson.GetObject('usage');
        Assert.AreEqual(5, UsageJson.GetInteger('input_tokens'), Describe(ResponseJson));
        Assert.IsFalse(UsageJson.Contains('input_tokens_details'), Describe(ResponseJson));
        Assert.IsFalse(UsageJson.Contains('extra'), Describe(ResponseJson));
    end;

    [Test]
    procedure Ask_ProviderFailsAfterToolRound_CodedWithStopReasonAndUsage_1033()
    begin
        // [SCENARIO AC1/AC3] a provider failure after a tool round answers with a stable code, stopReason and the usage so far
        VerifyProviderFailureAfterRound(1033);
    end;

    [Test]
    procedure Ask_ProviderFailsAfterToolRound_CodedWithStopReasonAndUsage_1039()
    begin
        // [SCENARIO AC1/AC3] the same in Icelandic
        VerifyProviderFailureAfterRound(1039);
    end;

    [Test]
    procedure Ask_ProviderAnswerNotJson_PreconditionFailedWithStopReason()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC1 invalid input] a provider answer that is a JSON array, not an object, ends with a coded error
        Initialize();
        MockProvider.EnqueueAnswer('[1,2]');

        ResponseJson := Execute(Request('{"question":"Q"}'), 1033);

        Assert.AreEqual('Error', ResponseJson.GetText('status'), Describe(ResponseJson));
        Assert.AreEqual('PreconditionFailed', ResponseJson.GetText('code'), Describe(ResponseJson));
        Assert.AreEqual('providerError', ResponseJson.GetText('stopReason'), Describe(ResponseJson));
        Assert.AreEqual(1, ResponseJson.GetInteger('rounds'), Describe(ResponseJson));
    end;

    [Test]
    procedure Help_ListsToolLoopErrorCodes()
    var
        AskImpl: Codeunit "LLM Prompt Ask Impl ori";
        Errors: JsonArray;
        ErrorsText: Text;
        Notes: Text;
    begin
        // [SCENARIO AC3] the help names the error codes the tool loop can return and the run state they carry
        AskImpl.GetErrors(Errors);
        Errors.WriteTo(ErrorsText);
        Assert.IsTrue(ErrorsText.Contains('"Retryable"'), ErrorsText);
        Assert.IsTrue(ErrorsText.Contains('"PreconditionFailed"'), ErrorsText);
        Assert.IsTrue(ErrorsText.Contains('"InvalidParameter"'), ErrorsText);
        AskImpl.GetNotes(Notes);
        Assert.IsTrue(Notes.Contains('Error codes the tool loop can return'), Notes);
        Assert.IsTrue(Notes.Contains('stopReason providerError'), Notes);
        Assert.IsTrue(Notes.Contains('cost_in_usd_ticks'), Notes);
    end;

    local procedure VerifyNonObjectResult(Mode: Text; ExpectedResult: Text)
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        LoopErrorTests: Codeunit "LLM 171 Ask Loop Error Tests";
        ResponseJson: JsonObject;
        ToolResults: JsonArray;
        ResultToken: JsonToken;
        ResultsLog: List of [Text];
    begin
        Initialize();
        MockProvider.EnqueueAnswer(StrSubstNo(ToolCallTok, '{"id":"r1","name":"who_am_i","arguments":{}}'));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'ok'));
        LoopErrorTests.SetToolMode(Mode);
        BindSubscription(LoopErrorTests);

        ResponseJson := Execute(Request('{"question":"Q"}'), 1033);
        UnbindSubscription(LoopErrorTests);

        Assert.AreEqual('Success', ResponseJson.GetText('status'), Describe(ResponseJson));
        Assert.AreEqual(0, ResponseJson.GetInteger('toolErrors'), Describe(ResponseJson));
        ResultsLog := MockProvider.GetToolResultsLog();
        Assert.AreEqual(1, ResultsLog.Count(), 'one continuation');
        ToolResults.ReadFrom(ResultsLog.Get(1));
        ToolResults.Get(0, ResultToken);
        Assert.AreEqual(ExpectedResult, ResultToken.AsObject().GetText('result'), ResultsLog.Get(1));
    end;

    local procedure VerifyCastErrorBecomesToolError(LanguageId: Integer)
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        LoopErrorTests: Codeunit "LLM 171 Ask Loop Error Tests";
        ResponseJson: JsonObject;
        ToolResults: JsonArray;
        ResultToken: JsonToken;
        ResultObject: JsonObject;
        ResultsLog: List of [Text];
    begin
        Initialize();
        MockProvider.EnqueueAnswer(StrSubstNo(ToolCallTok, '{"id":"e1","name":"get_records","arguments":{"tableName":"Currency","format":"table"}}'));
        MockProvider.EnqueueAnswer(StrSubstNo(ReplyTok, 'unknown'));
        LoopErrorTests.SetToolMode('cast');
        BindSubscription(LoopErrorTests);

        ResponseJson := Execute(Request('{"question":"Q"}'), LanguageId);
        UnbindSubscription(LoopErrorTests);

        Assert.AreEqual('Success', ResponseJson.GetText('status'), Describe(ResponseJson));
        Assert.AreEqual('completed', ResponseJson.GetText('stopReason'), Describe(ResponseJson));
        Assert.AreEqual(1, ResponseJson.GetInteger('toolErrors'), Describe(ResponseJson));
        Assert.AreEqual(0, ResponseJson.GetInteger('deniedToolCalls'), 'not a policy denial');
        ResultsLog := MockProvider.GetToolResultsLog();
        ToolResults.ReadFrom(ResultsLog.Get(1));
        ToolResults.Get(0, ResultToken);
        Assert.IsTrue(ResultObject.ReadFrom(ResultToken.AsObject().GetText('result')), ResultsLog.Get(1));
        Assert.IsTrue(ResultObject.GetText('error').StartsWith('the tool get_records failed: '), ResultsLog.Get(1));
    end;

    local procedure VerifyProviderFailureAfterRound(LanguageId: Integer)
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ResponseJson: JsonObject;
    begin
        Initialize();
        MockProvider.EnqueueAnswer('{"type":"tool_calls","toolCalls":[{"id":"p1","name":"who_am_i","arguments":{}}],"conversationState":"{\"messages\":[]}","usage":{"input_tokens":2147483000,"cost_in_usd_ticks":1000000000}}');
        MockProvider.EnqueueAnswer('{"error":"Could not reach the LLM API.","providerStatus":503}');

        ResponseJson := Execute(Request('{"question":"Q"}'), LanguageId);

        Assert.AreEqual('Error', ResponseJson.GetText('status'), Describe(ResponseJson));
        Assert.AreEqual('Retryable', ResponseJson.GetText('code'), Describe(ResponseJson));
        Assert.AreEqual('providerError', ResponseJson.GetText('stopReason'), Describe(ResponseJson));
        Assert.AreEqual(2, ResponseJson.GetInteger('rounds'), Describe(ResponseJson));
        Assert.AreEqual(1, ResponseJson.GetInteger('toolCalls'), Describe(ResponseJson));
        Assert.AreEqual(2147483000.0, ResponseJson.GetObject('usage').GetDecimal('input_tokens'), Describe(ResponseJson));
    end;

    /// <summary>
    /// Sets how the bound instance answers tool calls: cast, array, string or number.
    /// </summary>
    procedure SetToolMode(Mode: Text)
    begin
        ToolMode := Mode;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LLM Ask Tool Call ori", 'OnBeforeCallTool', '', false, false)]
    local procedure AnswerToolCall(CallToolName: Text; CallArguments: JsonObject; var CallResultText: Text; var CallIsError: Boolean; var Handled: Boolean)
    var
        Token: JsonToken;
        NotAnObject: JsonObject;
    begin
        Handled := true;
        case ToolMode of
            'cast':
                begin
                    // The same runtime error as production: a JSON array read as an object.
                    Token.ReadFrom('[{"a":1}]');
                    NotAnObject := Token.AsObject();
                    CallResultText := Format(NotAnObject.Keys().Count(), 0, 9);
                end;
            'array':
                CallResultText := '[1,2,3]';
            'string':
                CallResultText := '"plain"';
            'number':
                CallResultText := '42';
        end;
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
