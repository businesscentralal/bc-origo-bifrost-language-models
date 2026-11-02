namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests of the test-only message types Test.LanguageModel.Set, Test.LanguageModel.Delete and Test.LanguageModel.Chat,
/// run through Foundation's public Dispatcher ori. The chat test uses the Mock provider, so no network is needed.
/// </summary>
codeunit 96028 "LangModel Test Tools Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ModelCodeTok: Label 'BIFT-MOCK', Locked = true;

    /// <summary>
    /// Verifies that Test.LanguageModel.Set creates a language model with its settings and both keys.
    /// </summary>
    [Test]
    procedure Set_CreatesModelAndStoresKeysWithoutAnsweringThem()
    var
        LanguageModel: Record "Bifrost Language Model ori";
        ResponseJson: JsonObject;
        ResponseText: Text;
    begin
        // [SCENARIO] Test.LanguageModel.Set creates a language model with its settings and both keys
        Cleanup();

        // [WHEN] a model is set with a provider, endpoint, context size and two keys
        ResponseJson := Execute("Message Type ori"::"Test.LanguageModel.Set",
            '{"models":[{"code":"bift-mock","chatProvider":"Mock","description":"Mock model","baseUrl":"https://mock.invalid","model":"mock-1","contextTokens":64000,"sharedApiKey":"BIFT-SHARED-VALUE","personalApiKey":"BIFT-PERSONAL-VALUE"}]}');

        // [THEN] the model exists with the values sent, both keys are stored and no key value is answered
        ResponseJson.WriteTo(ResponseText);
        Assert.AreEqual('Success', ResponseJson.GetText('status'), ResponseText);
        Assert.IsTrue(LanguageModel.Get(ModelCodeTok), 'The model is created with an upper-case code.');
        Assert.AreEqual('mock-1', LanguageModel.Model, 'Model');
        Assert.AreEqual(64000, LanguageModel."Context Tokens", 'Context Tokens');
        Assert.IsTrue(ResponseText.Contains('"sharedKeyStored":true'), 'Shared key stored: ' + ResponseText);
        Assert.IsTrue(ResponseText.Contains('"personalKeyStored":true'), 'Personal key stored: ' + ResponseText);
        Assert.IsFalse(ResponseText.Contains('BIFT-SHARED-VALUE'), 'The shared key is never answered.');
        Assert.IsFalse(ResponseText.Contains('BIFT-PERSONAL-VALUE'), 'The personal key is never answered.');
        Cleanup();
    end;

    /// <summary>
    /// Verifies that bad entries are reported together and nothing is created.
    /// </summary>
    [Test]
    procedure Set_UnknownProviderAndMissingCode_AreReportedTogether()
    var
        ResponseJson: JsonObject;
        ResponseText: Text;
    begin
        // [SCENARIO] bad entries are reported together and nothing is created
        Cleanup();
        ResponseJson := Execute("Message Type ori"::"Test.LanguageModel.Set", '{"models":[{"code":"BIFT-MOCK","chatProvider":"NoSuchProvider"},{"chatProvider":"Mock"}]}');
        ResponseJson.WriteTo(ResponseText);
        Assert.AreEqual('Error', ResponseJson.GetText('status'), ResponseText);
        Assert.IsTrue(ResponseText.Contains('models[0].chatProvider'), 'The unknown provider is named: ' + ResponseText);
        Assert.IsTrue(ResponseText.Contains('models[1].code'), 'The missing code is named: ' + ResponseText);
        Assert.IsFalse(ModelExists(), 'Nothing is created.');
    end;

    /// <summary>
    /// Verifies that Test.LanguageModel.Delete deletes a model and lists the codes it did not find.
    /// </summary>
    [Test]
    procedure Delete_RemovesTheModelAndReportsUnknownCodes()
    var
        ResponseJson: JsonObject;
        ResponseText: Text;
    begin
        // [SCENARIO] Test.LanguageModel.Delete deletes a model and lists the codes it did not find
        Cleanup();
        Execute("Message Type ori"::"Test.LanguageModel.Set", '{"code":"BIFT-MOCK","chatProvider":"Mock"}');

        ResponseJson := Execute("Message Type ori"::"Test.LanguageModel.Delete", '{"codes":["BIFT-MOCK","BIFT-NONE"]}');

        ResponseJson.WriteTo(ResponseText);
        Assert.AreEqual('Success', ResponseJson.GetText('status'), ResponseText);
        Assert.IsTrue(ResponseText.Contains('"deleted":["BIFT-MOCK"]'), ResponseText);
        Assert.IsTrue(ResponseText.Contains('"notFound":["BIFT-NONE"]'), ResponseText);
        Assert.IsFalse(ModelExists(), 'The model is deleted.');
    end;

    /// <summary>
    /// Verifies that Test.LanguageModel.Chat runs the provider's tool calls through the MCP Tool Server and continues.
    /// </summary>
    [Test]
    procedure Chat_RunsToolCallsAndReturnsTheReply()
    var
        ResponseJson: JsonObject;
        ResponseText: Text;
    begin
        // [SCENARIO] Test.LanguageModel.Chat runs the provider's tool calls through the MCP Tool Server and continues
        Cleanup();
        Execute("Message Type ori"::"Test.LanguageModel.Set", '{"code":"BIFT-MOCK","chatProvider":"Mock"}');
        MockProvider.Reset();
        MockProvider.SetSendResponse('{"type":"tool_calls","toolCalls":[{"id":"call_1","name":"bift_no_such_tool","arguments":{}}],"conversationState":"{\"step\":1}"}');
        MockProvider.SetContinueResponse('{"type":"reply","reply":"Done."}');

        // [WHEN] a chat turn runs against the mock model
        ResponseJson := ExecuteChat('{"code":"BIFT-MOCK","prompt":"Hello"}');

        // [THEN] the tool was called, its result went back to the provider and the reply is answered
        ResponseJson.WriteTo(ResponseText);
        Assert.AreEqual('Success', ResponseJson.GetText('status'), ResponseText);
        Assert.AreEqual('Done.', ResponseJson.GetText('reply'), ResponseText);
        Assert.AreEqual(1, ResponseJson.GetInteger('rounds'), ResponseText);
        Assert.IsTrue(ResponseText.Contains('"name":"bift_no_such_tool"'), 'The tool call is traced: ' + ResponseText);
        Assert.IsTrue(MockProvider.WasContinueWithToolResultsCalled(), 'The tool results went back to the provider.');
        Assert.IsTrue(MockProvider.GetLastToolResultsJson().Contains('"id":"call_1"'), 'The result carries the call id.');
        Assert.AreEqual('{"step":1}', MockProvider.GetLastConversationState(), 'The conversation state is passed on.');
        Assert.IsTrue(MockProvider.GetLastSendPayload().Contains('Hello'), 'The prompt is sent.');
        Cleanup();
    end;

    /// <summary>
    /// Verifies that a provider error is answered as an error naming the provider's text.
    /// </summary>
    [Test]
    procedure Chat_ProviderError_IsPreconditionFailed()
    var
        ResponseJson: JsonObject;
        ResponseText: Text;
    begin
        // [SCENARIO] a provider error is answered as an error naming the provider's text
        Cleanup();
        Execute("Message Type ori"::"Test.LanguageModel.Set", '{"code":"BIFT-MOCK","chatProvider":"Mock"}');
        MockProvider.Reset();
        MockProvider.SetSendResponse('{"error":"BIFT bad key"}');

        ResponseJson := ExecuteChat('{"code":"BIFT-MOCK","prompt":"Hello"}');

        ResponseJson.WriteTo(ResponseText);
        Assert.AreEqual('Error', ResponseJson.GetText('status'), ResponseText);
        Assert.AreEqual('PreconditionFailed', ResponseJson.GetText('code'), ResponseText);
        Assert.IsTrue(ResponseText.Contains('BIFT bad key'), ResponseText);
        Cleanup();
    end;

    /// <summary>
    /// Verifies that an unknown code is RecordNotFound on code.
    /// </summary>
    [Test]
    procedure Chat_UnknownModel_IsRecordNotFound()
    var
        ResponseJson: JsonObject;
        ResponseText: Text;
    begin
        // [SCENARIO] an unknown code is RecordNotFound on code
        Cleanup();
        ResponseJson := ExecuteChat('{"code":"BIFT-MOCK","prompt":"Hello"}');
        ResponseJson.WriteTo(ResponseText);
        Assert.AreEqual('RecordNotFound', ResponseJson.GetText('code'), ResponseText);
        Assert.AreEqual('code', ResponseJson.GetText('parameter'), ResponseText);
    end;

    /// <summary>
    /// Verifies the enum mappings expose request declarations and honest effects for all three tools.
    /// </summary>
    [Test]
    procedure Contracts_DeclareParametersAndEffects()
    var
        Contract: Interface "Msg Contract ori";
        Parameters: JsonArray;
        Effect: JsonObject;
        ModelsParameter: JsonToken;
        Children: JsonToken;
        CodeParameter: JsonToken;
        MessageImplementation: Interface "Msg Interface ori";
    begin
        // [SCENARIO] Foundation resolves each test enum value to its real contract, including batch model fields.
        Contract := "Message Type ori"::"Test.LanguageModel.Set";
        MessageImplementation := "Message Type ori"::"Test.LanguageModel.Set";
        Assert.AreEqual("Msg Direction ori"::Inbound, MessageImplementation.GetMessageDirection(), 'The Set direction matches its effect.');
        Assert.IsTrue(Contract.GetParameters(Parameters), 'Set has a parameter contract.');
        Assert.AreEqual(15, Parameters.Count(), 'Set declares 14 model fields and the batch wrapper.');
        Parameters.Get(0, CodeParameter);
        Assert.IsFalse(CodeParameter.AsObject().GetBoolean('required'), 'Top-level code is optional when models is supplied.');
        Parameters.Get(14, ModelsParameter);
        Assert.AreEqual('models', ModelsParameter.AsObject().GetText('name'), 'The batch wrapper is declared.');
        ModelsParameter.AsObject().Get('children', Children);
        Assert.AreEqual(14, Children.AsArray().Count(), 'Batch entries declare the same model fields.');
        Children.AsArray().Get(0, CodeParameter);
        Assert.IsTrue(CodeParameter.AsObject().GetBoolean('required'), 'Each batch model requires its own code.');
        Assert.IsTrue(Contract.GetEffect(Effect), 'Set has an effect.');
        Assert.AreEqual('write', Effect.GetText('effect'), 'Set writes settings and keys.');

        Clear(Parameters);
        Clear(Effect);
        Contract := "Message Type ori"::"Test.LanguageModel.Delete";
        MessageImplementation := "Message Type ori"::"Test.LanguageModel.Delete";
        Assert.AreEqual("Msg Direction ori"::Inbound, MessageImplementation.GetMessageDirection(), 'The Delete direction matches its effect.');
        Assert.IsTrue(Contract.GetParameters(Parameters), 'Delete has a parameter contract.');
        Assert.AreEqual(1, Parameters.Count(), 'Delete declares codes.');
        Assert.IsTrue(Contract.GetEffect(Effect), 'Delete has an effect.');
        Assert.AreEqual('write', Effect.GetText('effect'), 'Delete removes models and keys.');

        Clear(Parameters);
        Clear(Effect);
        Contract := "Message Type ori"::"Test.LanguageModel.Chat";
        MessageImplementation := "Message Type ori"::"Test.LanguageModel.Chat";
        Assert.AreEqual("Msg Direction ori"::Inbound, MessageImplementation.GetMessageDirection(), 'The Chat direction matches its effect.');
        Assert.IsTrue(Contract.GetParameters(Parameters), 'Chat has a parameter contract.');
        Assert.AreEqual(5, Parameters.Count(), 'Chat declares code, prompt, messages, recordContext and maxToolRounds.');
        Assert.IsTrue(Contract.GetEffect(Effect), 'Chat has an effect.');
        Assert.AreEqual('irreversible', Effect.GetText('effect'), 'Chat commits tool rounds and calls the provider.');
        Assert.IsFalse(Effect.GetBoolean('idempotent'), 'Chat cannot promise repeatable effects.');
    end;

    /// <summary>
    /// Verifies undeclared top-level keys refuse Set before creating a model.
    /// </summary>
    [Test]
    procedure Set_UnknownParameter_DoesNotCreateModel()
    var
        ResponseJson: JsonObject;
    begin
        // [SCENARIO] A typo cannot silently change the meaning of a write request.
        Cleanup();
        ResponseJson := Execute("Message Type ori"::"Test.LanguageModel.Set", '{"code":"BIFT-MOCK","chatProvider":"Mock","unrecognized":true}');
        Assert.AreEqual('UnknownParameter', ResponseJson.GetText('code'), 'The undeclared key is refused.');
        Assert.IsFalse(ModelExists(), 'Validation runs before creation.');
    end;

    /// <summary>
    /// Verifies the batch wrapper also validates model children before writes.
    /// </summary>
    [Test]
    procedure Set_UnknownModelChild_DoesNotCreateModel()
    var
        ResponseJson: JsonObject;
    begin
        // [SCENARIO] Nested unknown fields are refused using the batch child contract.
        Cleanup();
        ResponseJson := Execute("Message Type ori"::"Test.LanguageModel.Set", '{"models":[{"code":"BIFT-MOCK","chatProvider":"Mock","unrecognized":true}]}');
        Assert.AreEqual('UnknownParameter', ResponseJson.GetText('code'), 'The undeclared child is refused.');
        Assert.IsFalse(ModelExists(), 'Validation runs before batch creation.');
    end;

    /// <summary>
    /// Verifies Delete refuses unknown keys before deleting its target.
    /// </summary>
    [Test]
    procedure Delete_UnknownParameter_PreservesModel()
    var
        ResponseJson: JsonObject;
    begin
        // [SCENARIO] An invalid deletion request leaves the seeded model intact.
        Cleanup();
        Execute("Message Type ori"::"Test.LanguageModel.Set", '{"code":"BIFT-MOCK","chatProvider":"Mock"}');
        ResponseJson := Execute("Message Type ori"::"Test.LanguageModel.Delete", '{"codes":["BIFT-MOCK"],"unrecognized":true}');
        Assert.AreEqual('UnknownParameter', ResponseJson.GetText('code'), 'The undeclared key is refused.');
        Assert.IsTrue(ModelExists(), 'Validation runs before deletion.');
        Cleanup();
    end;

    /// <summary>
    /// Verifies Chat refuses unknown keys before calling its mock provider.
    /// </summary>
    [Test]
    procedure Chat_UnknownParameter_DoesNotCallProvider()
    var
        ResponseJson: JsonObject;
    begin
        // [SCENARIO] A request with undeclared keys cannot call providers or execute tools.
        Cleanup();
        Execute("Message Type ori"::"Test.LanguageModel.Set", '{"code":"BIFT-MOCK","chatProvider":"Mock"}');
        MockProvider.Reset();
        ResponseJson := Execute("Message Type ori"::"Test.LanguageModel.Chat", '{"code":"BIFT-MOCK","prompt":"Hello","unrecognized":true}');
        Assert.AreEqual('UnknownParameter', ResponseJson.GetText('code'), 'The undeclared key is refused.');
        Assert.IsFalse(MockProvider.WasSendChatMessageCalled(), 'Validation runs before the provider.');
        Cleanup();
    end;

    local procedure ExecuteChat(RequestBody: Text) ResponseJson: JsonObject
    var
        CodeToken: JsonToken;
    begin
        // Current Foundation returns ConfirmationRequired for irreversible Chat until expectedCount
        // matches the default count of 1. Older Foundation has no gate, so the first response stands.
        // Unknown-parameter refusals stay on the first call and are not confirmed.
        ResponseJson := Execute("Message Type ori"::"Test.LanguageModel.Chat", RequestBody);
        if not ResponseJson.Get('code', CodeToken) then
            exit;
        if not CodeToken.IsValue() then
            exit;
        if CodeToken.AsValue().AsText() <> 'ConfirmationRequired' then
            exit;
        ResponseJson := Execute("Message Type ori"::"Test.LanguageModel.Chat", WithExpectedCount(RequestBody));
    end;

    local procedure WithExpectedCount(RequestBody: Text) ConfirmedBody: Text
    var
        Request: JsonObject;
    begin
        Assert.IsTrue(Request.ReadFrom(RequestBody), RequestBody);
        if not Request.Contains('expectedCount') then
            Request.Add('expectedCount', 1);
        Request.WriteTo(ConfirmedBody);
    end;

    local procedure Execute(MessageType: Enum "Message Type ori"; RequestBody: Text) ResponseJson: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        MessageVersion: Enum "Message Version ori";
        ResponseContentType: Text[100];
        ResponseText: Text;
    begin
        RequestContent.AddText(RequestBody);
        Dispatcher.Execute(MessageType, MessageVersion::"1.0", '', '', 'text/json', RequestContent, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        Assert.IsTrue(ResponseJson.ReadFrom(ResponseText), ResponseText);
    end;

    local procedure ModelExists(): Boolean
    var
        LanguageModel: Record "Bifrost Language Model ori";
    begin
        exit(LanguageModel.Get(ModelCodeTok));
    end;

    local procedure Cleanup()
    var
        LanguageModel: Record "Bifrost Language Model ori";
        TestCtx: Codeunit "Bifrost LangModel Test Ctx ori";
    begin
        TestCtx.ClearLanguageModel();
        if LanguageModel.Get(ModelCodeTok) then
            LanguageModel.Delete(true);
    end;
}
