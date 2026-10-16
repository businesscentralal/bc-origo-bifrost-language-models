namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.Environment.Configuration;
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
        ResponseJson := Execute("Message Type ori"::"Test.LanguageModel.Chat", '{"code":"BIFT-MOCK","prompt":"Hello"}');

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

        ResponseJson := Execute("Message Type ori"::"Test.LanguageModel.Chat", '{"code":"BIFT-MOCK","prompt":"Hello"}');

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
        ResponseJson := Execute("Message Type ori"::"Test.LanguageModel.Chat", '{"code":"BIFT-MOCK","prompt":"Hello"}');
        ResponseJson.WriteTo(ResponseText);
        Assert.AreEqual('RecordNotFound', ResponseJson.GetText('code'), ResponseText);
        Assert.AreEqual('code', ResponseJson.GetText('parameter'), ResponseText);
    end;

    /// <summary>Fresh dispatcher fixtures create missing HTTP settings for both required apps.</summary>
    [Test]
    procedure HttpSetup_MissingRows_CreatesOnlyRequiredSettings()
    var
        NavAppSetting: Record "NAV App Setting";
        TestSetup: Codeunit "LangModel Test Setup Events";
        FoundationAppId: Guid;
        LanguageModelsAppId: Guid;
        OtherAppId: Guid;
    begin
        FoundationAppId := '{7505e808-6e52-4b96-a328-82573391297a}';
        LanguageModelsAppId := '{f1722684-0c24-4022-a2e0-0f63154aca76}';
        OtherAppId := CreateGuid();
        NavAppSetting.Init();
        NavAppSetting."App ID" := OtherAppId;
        NavAppSetting."Allow HttpClient Requests" := false;
        NavAppSetting.Insert();
        if NavAppSetting.Get(FoundationAppId) then
            NavAppSetting.Delete();
        if NavAppSetting.Get(LanguageModelsAppId) then
            NavAppSetting.Delete();

        TestSetup.EnableDispatcherHttp();

        Assert.IsTrue(NavAppSetting.Get(FoundationAppId), 'Foundation setting was created.');
        Assert.IsTrue(NavAppSetting."Allow HttpClient Requests", 'Foundation HTTP was enabled.');
        Assert.IsTrue(NavAppSetting.Get(LanguageModelsAppId), 'Language Models setting was created.');
        Assert.IsTrue(NavAppSetting."Allow HttpClient Requests", 'Language Models HTTP was enabled.');
        NavAppSetting.Get(OtherAppId);
        Assert.IsFalse(NavAppSetting."Allow HttpClient Requests", 'Other applications remain disabled.');
    end;

    /// <summary>Explicitly disabled HTTP settings are prepared before positive dispatcher assertions.</summary>
    [Test]
    procedure HttpSetup_DisabledRows_EnablesBothAndIsRepeatable()
    var
        NavAppSetting: Record "NAV App Setting";
        TestSetup: Codeunit "LangModel Test Setup Events";
        FoundationAppId: Guid;
        LanguageModelsAppId: Guid;
    begin
        FoundationAppId := '{7505e808-6e52-4b96-a328-82573391297a}';
        LanguageModelsAppId := '{f1722684-0c24-4022-a2e0-0f63154aca76}';
        TestSetup.EnableDispatcherHttp();
        NavAppSetting.Get(FoundationAppId);
        NavAppSetting."Allow HttpClient Requests" := false;
        NavAppSetting.Modify();
        NavAppSetting.Get(LanguageModelsAppId);
        NavAppSetting."Allow HttpClient Requests" := false;
        NavAppSetting.Modify();

        TestSetup.EnableDispatcherHttp();
        TestSetup.EnableDispatcherHttp();

        NavAppSetting.Get(FoundationAppId);
        Assert.IsTrue(NavAppSetting."Allow HttpClient Requests", 'Foundation HTTP was enabled.');
        NavAppSetting.Get(LanguageModelsAppId);
        Assert.IsTrue(NavAppSetting."Allow HttpClient Requests", 'Language Models HTTP was enabled.');
    end;

    local procedure Execute(MessageType: Enum "Message Type ori"; RequestBody: Text) ResponseJson: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        TestSetup: Codeunit "LangModel Test Setup Events";
        RequestContent: BigText;
        ResponseContent: BigText;
        MessageVersion: Enum "Message Version ori";
        ResponseContentType: Text[100];
        ResponseText: Text;
    begin
        TestSetup.EnableDispatcherHttp();
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
