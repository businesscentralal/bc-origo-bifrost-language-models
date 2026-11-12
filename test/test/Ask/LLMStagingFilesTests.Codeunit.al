namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;
using System.Utilities;

/// <summary>Issue 116: staged prompt attachments, mock provider only, each scenario creates its own uploads.</summary>
codeunit 96068 "LLM Staging Files Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        ModelCodeTok: Label 'LM116-MOCK', Locked = true;

    [Test]
    procedure Scenario_AC01_AskText_ConsumedAndSent()
    begin
        VerifyText(Enum::"Message Type ori"::"LLM.Prompt.Ask");
    end;

    [Test]
    procedure Scenario_AC02_CompleteText_ConsumedAndSent()
    begin
        VerifyText(Enum::"Message Type ori"::"LLM.Prompt.Complete");
    end;

    [Test]
    procedure Scenario_AC03_MultipleFiles_Ordered()
    var
        Mock: Codeunit "Mock Bifrost Chat Provider";
        Payload: JsonObject;
        Response: JsonObject;
        Files: JsonArray;
        Token: JsonToken;
        FirstId: Guid;
        SecondId: Guid;
    begin
        // [GIVEN] Two caller-owned files with distinct names and bytes.
        Initialize();
        FirstId := Upload('first', 'first.txt', 'text/plain');
        SecondId := Upload('second', 'second.pdf', 'application/pdf');
        // [WHEN] Complete is called with the first upload before the second.
        Response := Execute(Enum::"Message Type ori"::"LLM.Prompt.Complete", Request(FirstId, SecondId));
        // [THEN] Provider files preserve input order and metadata.
        Assert.AreEqual('Success', Response.GetText('status'), Describe(Response));
        Payload.ReadFrom(Mock.GetLastCompletePayload());
        Files := Payload.GetArray('files');
        Assert.AreEqual(2, Files.Count(), 'two files');
        Files.Get(0, Token);
        Assert.AreEqual('first.txt', Token.AsObject().GetText('fileName'), 'first file');
        Files.Get(1, Token);
        Assert.AreEqual('second.pdf', Token.AsObject().GetText('fileName'), 'second file');
    end;

    [Test]
    procedure Scenario_AC04_UnknownId_NoProviderCall()
    begin
        Initialize();
        VerifyRefused(Request(CreateGuid(), CreateGuid()), 'RecordNotFound', 'attachments[1].stagingId');
    end;

    [Test]
    procedure Scenario_AC04_ConsumedId_NoProviderCall()
    var
        Staging: Codeunit "Blob Staging ori";
        Blob: Codeunit "Temp Blob";
        StagingId: Guid;
        EmptyId: Guid;
    begin
        Initialize();
        StagingId := Upload('used', 'used.txt', 'text/plain');
        Assert.IsTrue(Staging.Take(StagingId, Blob), 'own test upload consumed');
        VerifyRefused(Request(StagingId, EmptyId), 'RecordNotFound', 'attachments[1].stagingId');
    end;

    [Test]
    procedure Scenario_AC04_DuplicateId_NoProviderCall()
    var
        Staging: Codeunit "Blob Staging ori";
        StagingId: Guid;
    begin
        Initialize();
        StagingId := Upload('duplicate', 'duplicate.txt', 'text/plain');
        VerifyRefused(Request(StagingId, StagingId), 'RecordNotFound', 'attachments[2].stagingId');
        Assert.IsTrue(Staging.Exists(StagingId), 'entry validation finishes before consumption');
    end;

    [Test]
    procedure Scenario_AC05_UnsupportedMime_NoProviderCall()
    var
        StagingId: Guid;
        EmptyId: Guid;
    begin
        Initialize();
        StagingId := Upload('zip', 'archive.zip', 'application/zip');
        VerifyRefused(Request(StagingId, EmptyId), 'InvalidParameter', 'attachments[1].stagingId');
    end;

    [Test]
    procedure Scenario_AC05_TotalOverLimit_NoProviderCall()
    var
        Model: Record "Bifrost Language Model ori";
        StagingId: Guid;
    begin
        Initialize();
        Model.Get(ModelCodeTok);
        Model."Attachment Limit Bytes" := 5;
        Model.Modify();
        StagingId := Upload('four', 'first.txt', 'text/plain');
        VerifyRefused(Request(StagingId, Upload('four', 'second.txt', 'text/plain')), 'LimitExceeded', 'attachments');
    end;

    [Test]
    procedure Scenario_AC05_NormalizedMime_Accepted()
    var
        Response: JsonObject;
        EmptyId: Guid;
    begin
        Initialize();
        Response := Execute(Enum::"Message Type ori"::"LLM.Prompt.Complete", Request(Upload('text', 'mime.txt', ' Text/Plain; charset=utf-8 '), EmptyId));
        Assert.AreEqual('Success', Response.GetText('status'), Describe(Response));
    end;

    [Test]
    procedure Scenario_AC06_ExtraKey_UnknownParameter()
    var
        Staging: Codeunit "Blob Staging ori";
        Data: JsonObject;
        Items: JsonArray;
        Item: JsonObject;
        StagingId: Guid;
    begin
        Initialize();
        StagingId := Upload('safe', 'extra.txt', 'text/plain');
        Item.Add('stagingId', Format(StagingId, 0, 4));
        Item.Add('data', 'not allowed');
        Items.Add(Item);
        Data.Add('attachments', Items);
        VerifyRefused(Data, 'UnknownParameter', 'attachments[1].data');
        Assert.IsTrue(Staging.Exists(StagingId), 'invalid shape must not consume a file');
    end;

    [Test]
    procedure Scenario_AC06_NonArray_InvalidFormat()
    var
        Data: JsonObject;
    begin
        Initialize();
        Data.Add('attachments', 'wrong');
        VerifyRefused(Data, 'InvalidParameterFormat', 'attachments');
    end;

    [Test]
    procedure Scenario_AC07_UnregisteredStorage_NotAdvertised()
    var
        StagingFiles: Codeunit "LLM Staging Files ori";
        Related: JsonArray;
        Names: List of [Text];
    begin
        Initialize();
        StagingFiles.AddRelatedFromTypes(Related, Names);
        Assert.AreEqual(0, Related.Count(), 'no storage type advertised without an installed registration');
    end;

    [Test]
    procedure Scenario_AC07_RegisteredStorage_Advertised()
    var
        Contract: Interface "Msg Contract ori";
        Related: JsonArray;
        TextValue: Text;
    begin
        Initialize();
        Contract := Enum::"Message Type ori"::"LLM.Prompt.Complete";
        Contract.GetRelated(Related);
        Related.WriteTo(TextValue);
        Assert.IsTrue(TextValue.Contains('Storage.Upload.CommitToStaging'), 'installed stand-in path is discoverable');
    end;

    [Test]
    procedure Scenario_AC01_ProviderBuilders_ReceiveFileBytes()
    var
        Builder: Integer;
    begin
        Initialize();
        Commit(); // Bootstrap uses Codeunit.Run; fixture writes must be visible first.
        for Builder := 1 to 3 do
            VerifyProviderBuilder(Builder);
    end;

    local procedure VerifyProviderBuilder(Builder: Integer)
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        ChatProxy: Codeunit "LangModel Chat Proxy ori";
        AnthropicProxy: Codeunit "Anthropic LangModel Proxy ori";
        Mock: Codeunit "LLM 100 HTTP Mock";
        Payload: JsonObject;
        MessageObject: JsonObject;
        FileObject: JsonObject;
        Messages: JsonArray;
        Files: JsonArray;
        Extras: JsonObject;
        PayloadText: Text;
        ResultText: Text;
        KeyValue: SecretText;
        KeyText: Text;
    begin
        // [GIVEN] A mock HTTP boundary and the actual provider's input file format.
        TempArgument.Init();
        TempArgument."Base URL" := 'https://example.invalid';
        TempArgument.Model := 'fixture-model';
        KeyText := 'fixture-only';
        KeyValue := KeyText;
        TempArgument.SetApiKey(KeyValue);
        MessageObject.Add('role', 'user');
        MessageObject.Add('content', 'Read the file');
        Messages.Add(MessageObject);
        Payload.Add('messages', Messages);
        FileObject.Add('data', 'c3RhZ2VkIGZpbGU=');
        FileObject.Add('fileName', 'fixture.pdf');
        FileObject.Add('mimeType', 'application/pdf');
        Files.Add(FileObject);
        Payload.Add('files', Files);
        Payload.WriteTo(PayloadText);
        case Builder of
            1:
                Mock.Configure('{"choices":[{"message":{"role":"assistant","content":"done"}}]}');
            2:
                Mock.Configure('{"output":[{"type":"message","content":[{"type":"output_text","text":"done"}]}]}');
            3:
                Mock.Configure('{"stop_reason":"end_turn","content":[{"type":"text","text":"done"}]}');
        end;
        BindSubscription(Mock);
        // [WHEN] Each real request builder runs against the intercepted HTTP boundary.
        case Builder of
            1:
                ResultText := ChatProxy.SendChatMessage(TempArgument, PayloadText, 'Authorization');
            2:
                ResultText := ChatProxy.SendChatMessageResponses(TempArgument, PayloadText, 'Authorization', Extras);
            3:
                ResultText := AnthropicProxy.SendChatMessage(TempArgument, PayloadText);
        end;
        UnbindSubscription(Mock);
        // [THEN] The outgoing body carries file bytes, not only the text question.
        Assert.AreEqual(1, Mock.GetCallCount(), ResultText);
        Assert.IsTrue(Mock.GetBody(1).Contains('c3RhZ2VkIGZpbGU='), 'provider request retains attachment bytes');
        Assert.IsTrue(Mock.GetBody(1).Contains('application/pdf'), 'provider request retains MIME type');
    end;

    [Test]
    procedure Scenario_AC04_ForeignId_BothTypesRefusedWithoutLeak()
    var
        Mock: Codeunit "Mock Bifrost Chat Provider";
        Rows: RecordRef;
        FixtureField: FieldRef;
        Data: JsonObject;
        Response: JsonObject;
        UnknownResponse: JsonObject;
        EmptyId: Guid;
        ForeignId: Guid;
        MessageType: Enum "Message Type ori";
        MessageTypes: List of [Enum "Message Type ori"];
    begin
        // [GIVEN] The test installer created an owned test fixture with a synthetic different creator, not a new BC user.
        Initialize();
        Rows.Open(10078382);
        Rows.ReadIsolation := IsolationLevel::ReadCommitted;
        FixtureField := Rows.Field(6);
        FixtureField.SetRange('LM116 synthetic foreign fixture');
        Assert.IsTrue(Rows.FindFirst(), 'Test installation must seed the foreign fixture');
        FixtureField := Rows.Field(Rows.SystemCreatedByNo());
        Assert.AreNotEqual(UserSecurityId(), FixtureField.Value(), 'The persisted creator must be foreign');
        FixtureField := Rows.Field(Rows.SystemIdNo());
        ForeignId := FixtureField.Value();
        Rows.Close();
        MessageTypes.Add(Enum::"Message Type ori"::"LLM.Prompt.Ask");
        MessageTypes.Add(Enum::"Message Type ori"::"LLM.Prompt.Complete");
        foreach MessageType in MessageTypes do begin
            Mock.Reset();
            Mock.SetIsConfigured(true);
            // [WHEN] The real dispatcher receives the foreign ID, then an unknown ID.
            Data := Request(ForeignId, EmptyId);
            Response := Execute(MessageType, Data);
            Data := Request(CreateGuid(), EmptyId);
            UnknownResponse := Execute(MessageType, Data);
            // [THEN] Both are indistinguishable refusals, without provider calls or file-content disclosure.
            Assert.AreEqual('RecordNotFound', Response.GetText('code'), Describe(Response));
            Assert.AreEqual('attachments[1].stagingId', Response.GetText('parameter'), Describe(Response));
            Assert.AreEqual(UnknownResponse.GetText('error'), Response.GetText('error'), 'same error as an unknown ID');
            Assert.AreEqual(UnknownResponse.GetText('expected'), Response.GetText('expected'), 'same expected value');
            Assert.AreEqual(UnknownResponse.GetText('nextStep'), Response.GetText('nextStep'), 'same upload-again guidance');
            Assert.IsFalse(Describe(Response).Contains('LM116-PRIVATE-FOREIGN'), 'no file name leaked');
            Assert.IsFalse(Describe(Response).Contains('private foreign content'), 'no file bytes leaked');
            Assert.IsFalse(Mock.WasSendChatMessageCalled(), 'no billable Ask request');
            Assert.IsFalse(Mock.WasCompletePromptCalled(), 'no billable Complete request');
        end;
        Rows.Open(10078382);
        Assert.IsTrue(Rows.GetBySystemId(ForeignId), 'refusal must preserve the foreign fixture');
        Rows.Close();
    end;

    local procedure VerifyText(MessageType: Enum "Message Type ori")
    var
        Staging: Codeunit "Blob Staging ori";
        Mock: Codeunit "Mock Bifrost Chat Provider";
        Payload: JsonObject;
        Response: JsonObject;
        Files: JsonArray;
        Token: JsonToken;
        StagingId: Guid;
        EmptyId: Guid;
    begin
        // [GIVEN] This test owns a fresh text upload and mock model.
        Initialize();
        StagingId := Upload('hello staged world', 'hello.txt', 'text/plain');
        // [WHEN] The message is dispatched through Foundation.
        Response := Execute(MessageType, Request(StagingId, EmptyId));
        // [THEN] Provider receives bytes and metadata; no live HTTP or credential is needed.
        Assert.AreEqual('Success', Response.GetText('status'), Describe(Response));
        Assert.IsFalse(Staging.Exists(StagingId), 'staging row consumed');
        if MessageType = Enum::"Message Type ori"::"LLM.Prompt.Ask" then
            Payload.ReadFrom(Mock.GetLastSendPayload())
        else
            Payload.ReadFrom(Mock.GetLastCompletePayload());
        Files := Payload.GetArray('files');
        Files.Get(0, Token);
        Assert.AreEqual('aGVsbG8gc3RhZ2VkIHdvcmxk', Token.AsObject().GetText('data'), 'exact uploaded content');
        Assert.AreEqual('hello.txt', Token.AsObject().GetText('fileName'), 'stored name');
        Assert.AreEqual('text/plain', Token.AsObject().GetText('mimeType'), 'stored MIME');
    end;

    local procedure VerifyRefused(Data: JsonObject; ErrorCode: Text; ParameterName: Text)
    var
        Mock: Codeunit "Mock Bifrost Chat Provider";
        Response: JsonObject;
    begin
        Response := Execute(Enum::"Message Type ori"::"LLM.Prompt.Complete", Data);
        Assert.AreEqual(ErrorCode, Response.GetText('code'), Describe(Response));
        Assert.AreEqual(ParameterName, Response.GetText('parameter'), Describe(Response));
        Assert.IsFalse(Mock.WasCompletePromptCalled(), 'refused before any billable provider request');
        Assert.IsFalse(Mock.WasSendChatMessageCalled(), 'no chat provider request');
    end;

    local procedure Upload(Content: Text; FileName: Text; MimeType: Text): Guid
    var
        Staging: Codeunit "Blob Staging ori";
        Blob: Codeunit "Temp Blob";
        Output: OutStream;
        Input: InStream;
    begin
        Blob.CreateOutStream(Output, TextEncoding::UTF8);
        Output.WriteText(Content);
        Blob.CreateInStream(Input);
        exit(Staging.Create(Input, FileName, MimeType, 'LM116 test'));
    end;

    local procedure Request(FirstId: Guid; SecondId: Guid) Data: JsonObject
    var
        Item: JsonObject;
        Items: JsonArray;
    begin
        Item.Add('stagingId', Format(FirstId, 0, 4));
        Items.Add(Item);
        if not IsNullGuid(SecondId) then begin
            Clear(Item);
            Item.Add('stagingId', Format(SecondId, 0, 4));
            Items.Add(Item);
        end;
        Data.Add('attachments', Items);
    end;

    local procedure Execute(MessageType: Enum "Message Type ori"; Data: JsonObject) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        MessageId: Guid;
        EmptyId: Guid;
        ResponseTime: Duration;
        ContentType: Text[100];
        TextValue: Text;
    begin
        Data.Add('roleCode', ModelCodeTok);
        if MessageType = Enum::"Message Type ori"::"LLM.Prompt.Ask" then
            Data.Add('question', 'Read this file')
        else
            Data.Add('prompt', 'Read this file');
        Data.WriteTo(TextValue);
        RequestContent.AddText(TextValue);
        Dispatcher.EnqueueAndProcess(MessageType, Enum::"Message Version ori"::"1.0", '', '', 'text/json', RequestContent, EmptyId, 1033, MessageId, ResponseContent, ContentType, ResponseTime);
        ResponseContent.GetSubText(TextValue, 1);
        Assert.IsTrue(Response.ReadFrom(TextValue), TextValue);
    end;

    local procedure Describe(Response: JsonObject) TextValue: Text
    begin
        Response.WriteTo(TextValue);
    end;

    local procedure Initialize()
    var
        Model: Record "Bifrost Language Model ori";
        Mock: Codeunit "Mock Bifrost Chat Provider";
    begin
        Mock.Reset();
        Mock.SetIsConfigured(true);
        Mock.SetSendResponse('{"type":"reply","reply":"ok"}');
        Mock.SetCompleteResponse('{"reply":"ok"}');
        if Model.Get(ModelCodeTok) then
            Model.Delete(true);
        Model.Init();
        Model.Code := ModelCodeTok;
        Model."Chat Provider" := Enum::"Bifrost LangModel Prov. ori"::Mock;
        Model.Insert(true);
    end;
}
