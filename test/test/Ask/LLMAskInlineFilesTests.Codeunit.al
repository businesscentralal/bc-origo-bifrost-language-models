namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;
using System.Utilities;

/// <summary>Issue 127: inline file and files on LLM.Prompt.Ask. Mock providers and HTTP mocks only; no credentials.</summary>
codeunit 96075 "LLM Ask Inline Files Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        ModelCodeTok: Label 'LM127-MOCK', Locked = true;
        FakeKeyTok: Label 'lm127-fixture-Q4', Locked = true;
        PdfBase64Tok: Label 'JVBERi0xLjQK', Locked = true;
        PngBase64Tok: Label 'iVBORw0KGgo=', Locked = true;

    [Test]
    procedure Scenario_AC01_AskFile_SentInBothLocales()
    var
        Locale: Integer;
        Index: Integer;
    begin
        // [GIVEN] A mock model. [WHEN] Ask gets one inline file. [THEN] The provider payload carries it, in 1033 and 1039.
        for Index := 1 to 2 do begin
            Locale := 1033;
            if Index = 2 then
                Locale := 1039;
            Initialize();
            VerifyFiles(ExecuteFile(InlineFile('a.pdf', 'application/pdf', PdfBase64Tok), Locale), 1);
        end;
    end;

    [Test]
    procedure Scenario_AC01_AskFiles_KeepOrder()
    var
        Files: JsonArray;
        Payload: JsonObject;
        Token: JsonToken;
    begin
        Initialize();
        Files.Add(InlineFile('first.pdf', 'application/pdf', PdfBase64Tok));
        Files.Add(InlineFile('second.png', ' IMAGE/PNG; x=y ', PngBase64Tok));
        VerifyFiles(ExecuteFiles(Files, 1033), 2);
        Payload := LastPayload();
        Payload.GetArray('files').Get(1, Token);
        Assert.AreEqual('second.png', Token.AsObject().GetText('fileName'), 'second name');
        Assert.AreEqual('image/png', Token.AsObject().GetText('mimeType'), 'normalized type');
    end;

    [Test]
    procedure Scenario_AC01_FileWinsOverFiles()
    var
        Data: JsonObject;
        Files: JsonArray;
    begin
        Initialize();
        Data := AskData();
        Data.Add('file', InlineFile('one.pdf', 'application/pdf', PdfBase64Tok));
        Files.Add(InlineFile('x.pdf', 'application/pdf', PdfBase64Tok));
        Files.Add(InlineFile('y.pdf', 'application/pdf', PdfBase64Tok));
        Data.Add('files', Files);
        VerifyFiles(Run(Data, 1033), 1);
    end;

    [Test]
    procedure Scenario_AC01_StagedAndInline_Combined()
    var
        Data: JsonObject;
        Payload: JsonObject;
        Token: JsonToken;
    begin
        Initialize();
        Data := AskData();
        Data.Add('attachments', StagedItems(Upload('staged', 'staged.txt', 'text/plain')));
        Data.Add('file', InlineFile('inline.pdf', 'application/pdf', PdfBase64Tok));
        VerifyFiles(Run(Data, 1033), 2);
        Payload := LastPayload();
        Payload.GetArray('files').Get(0, Token);
        Assert.AreEqual('staged.txt', Token.AsObject().GetText('fileName'), 'staged first');
        Payload.GetArray('files').Get(1, Token);
        Assert.AreEqual('inline.pdf', Token.AsObject().GetText('fileName'), 'inline second');
    end;

    [Test]
    procedure Scenario_AC01_NoFile_NoFilesInPayload()
    var
        Payload: JsonObject;
    begin
        Initialize();
        Assert.AreEqual('Success', Run(AskData(), 1033).GetText('status'), 'success');
        Payload := LastPayload();
        Assert.IsFalse(Payload.Contains('files'), 'existing callers are unaffected');
    end;

    [Test]
    procedure Scenario_AC01_TooManyFiles_LimitExceeded()
    var
        Files: JsonArray;
        Index: Integer;
        Response: JsonObject;
    begin
        Initialize();
        for Index := 1 to 11 do
            Files.Add(InlineFile('f' + Format(Index) + '.pdf', 'application/pdf', PdfBase64Tok));
        Response := ExecuteFiles(Files, 1033);
        VerifyRefusal(Response, 'LimitExceeded', 'files');
        Assert.IsTrue(Response.GetText('expected').Contains('10'), 'names the limit');
    end;

    [Test]
    procedure Scenario_AC01_StagedPlusInline_CountCapped()
    var
        Data: JsonObject;
        Files: JsonArray;
        Index: Integer;
    begin
        Initialize();
        for Index := 1 to 10 do
            Files.Add(InlineFile('f' + Format(Index) + '.pdf', 'application/pdf', PdfBase64Tok));
        Data := AskData();
        Data.Add('attachments', StagedItems(Upload('staged', 'staged.txt', 'text/plain')));
        Data.Add('files', Files);
        VerifyRefusal(Run(Data, 1039), 'LimitExceeded', 'files');
    end;

    [Test]
    procedure Scenario_AC01_CombinedSize_LimitExceeded()
    var
        Model: Record "Bifrost Language Model ori";
        Data: JsonObject;
    begin
        Initialize();
        Model.Get(ModelCodeTok);
        Model."Attachment Limit Bytes" := 8;
        Model.Modify();
        Data := AskData();
        Data.Add('attachments', StagedItems(Upload('four', 'staged.txt', 'text/plain')));
        // Eight Base64 characters decode to six bytes, so four staged plus six inline bytes pass 8.
        Data.Add('file', InlineFile('big.txt', 'text/plain', 'QUJDREVG'));
        VerifyRefusal(Run(Data, 1033), 'LimitExceeded', 'files');
    end;

    [Test]
    procedure Scenario_AC02_UnsupportedType_Refused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteFile(InlineFile('a.zip', 'application/zip', PdfBase64Tok), 1039);
        VerifyRefusal(Response, 'InvalidParameter', 'file.mimeType');
        Assert.AreNotEqual('', Response.GetText('nextStep'), 'next step given');
    end;

    [Test]
    procedure Scenario_AC02_UnsupportedImage_InFiles_Refused()
    var
        Files: JsonArray;
    begin
        Initialize();
        Files.Add(InlineFile('ok.pdf', 'application/pdf', PdfBase64Tok));
        Files.Add(InlineFile('a.gif', 'image/gif', PdfBase64Tok));
        VerifyRefusal(ExecuteFiles(Files, 1033), 'InvalidParameter', 'files[1].mimeType');
    end;

    [Test]
    procedure Scenario_AC02_MissingData_Refused()
    var
        Item: JsonObject;
    begin
        Initialize();
        Item.Add('mimeType', 'application/pdf');
        Item.Add('fileName', 'a.pdf');
        VerifyRefusal(ExecuteFile(Item, 1033), 'MissingParameter', 'file.data');
    end;

    [Test]
    procedure Scenario_AC02_WrongShapes_Refused()
    var
        Data: JsonObject;
    begin
        Initialize();
        Data := AskData();
        Data.Add('file', 'not an object');
        VerifyRefusal(Run(Data, 1033), 'InvalidParameterFormat', 'file');
        Clear(Data);
        Data := AskData();
        Data.Add('files', 'not an array');
        VerifyRefusal(Run(Data, 1033), 'InvalidParameterFormat', 'files');
    end;

    [Test]
    procedure Scenario_AC03_Xai_UploadsAndDeletes()
    var
        Result: JsonObject;
        Locale: Integer;
        Index: Integer;
    begin
        for Index := 1 to 2 do begin
            Locale := 1033;
            if Index = 2 then
                Locale := 1039;
            Result := RunProvider(Enum::"Bifrost LangModel Prov. ori"::xAI, 'https://xai127.invalid/v1', Locale, 200,
                '{"output":[{"type":"message","content":[{"type":"output_text","text":"OK"}]}]}');
            Assert.AreEqual('Success', Result.GetObject('response').GetText('status'), Describe(Result.GetObject('response')));
            Assert.AreEqual(1, Result.GetInteger('uploads'), 'one upload for the inline PDF');
            Assert.AreEqual(1, Result.GetInteger('deletes'), 'upload removed after success');
            Assert.IsTrue(Result.GetText('request').Contains('file_llm65'), 'file id sent');
        end;
    end;

    [Test]
    procedure Scenario_AC03_Xai_FailureStillDeletes()
    var
        Result: JsonObject;
    begin
        Result := RunProvider(Enum::"Bifrost LangModel Prov. ori"::xAI, 'https://xai127.invalid/v1', 1033, 500, '{"error":{"message":"boom"}}');
        Assert.AreNotEqual('Success', Result.GetObject('response').GetText('status'), 'provider failure');
        Assert.AreEqual(Result.GetInteger('uploads'), Result.GetInteger('deletes'), 'every upload removed after failure');
    end;

    [Test]
    procedure Scenario_AC02_Anthropic_PdfDocumentBlock()
    var
        Result: JsonObject;
    begin
        Result := RunProvider(Enum::"Bifrost LangModel Prov. ori"::Anthropic, 'https://anthropic127.invalid', 1033, 200,
            '{"content":[{"type":"text","text":"OK"}],"stop_reason":"end_turn","usage":{"input_tokens":1,"output_tokens":1}}');
        Assert.AreEqual('Success', Result.GetObject('response').GetText('status'), Describe(Result.GetObject('response')));
        Assert.IsTrue(Result.GetText('request').Contains('"document"'), 'document block');
        Assert.IsTrue(Result.GetText('request').Contains('application/pdf'), 'PDF media type');
        Assert.IsTrue(Result.GetText('request').Contains(PdfBase64Tok), 'inline bytes');
    end;

    [Test]
    procedure Scenario_AC04_Contract_ShowsInlineParameters()
    var
        AskImpl: Codeunit "LLM Prompt Ask Impl ori";
        Parameters: JsonArray;
        Errors: JsonArray;
        Notes: Text;
        ParametersText: Text;
        ErrorsText: Text;
    begin
        AskImpl.GetParameters(Parameters);
        AskImpl.GetErrors(Errors);
        AskImpl.GetNotes(Notes);
        Parameters.WriteTo(ParametersText);
        Errors.WriteTo(ErrorsText);
        Assert.IsTrue(ParametersText.Contains('"name":"file"'), 'file documented');
        Assert.IsTrue(ParametersText.Contains('"name":"files"'), 'files documented');
        Assert.IsTrue(ParametersText.Contains('"name":"attachments"'), 'attachments still documented');
        Assert.IsTrue(ErrorsText.Contains('LimitExceeded'), 'limit refusal documented');
        Assert.IsTrue(Notes.Contains('Inline file'), 'notes mention inline files');
    end;

    local procedure RunProvider(Provider: Enum "Bifrost LangModel Prov. ori"; BaseUrl: Text; Locale: Integer; HttpStatus: Integer; ProviderBody: Text) Result: JsonObject
    var
        Model: Record "Bifrost Language Model ori";
        Secrets: Codeunit "LangModel Secrets ori";
        Mock65: Codeunit "LLM 65 HTTP Mock";
        Mock100: Codeunit "LLM 100 HTTP Mock";
        Data: JsonObject;
        Response: JsonObject;
        MessageId: Guid;
        KeyValue: SecretText;
        KeyText: Text;
        RequestBody: Text;
    begin
        Model.Code := CopyStr('X127-' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(Model.Code));
        Model.Validate("Chat Provider", Provider);
        Model.Model := 'fixture-model';
        Model."Base URL" := CopyStr(BaseUrl, 1, MaxStrLen(Model."Base URL"));
        Model.Insert(true);
        KeyText := FakeKeyTok;
        KeyValue := KeyText;
        Secrets.SetUserKey(Model.Code, KeyValue);
        Data.Add('roleCode', Model.Code);
        Data.Add('question', 'Summarise the file');
        Data.Add('file', InlineFile('inline.pdf', 'application/pdf', PdfBase64Tok));
        Commit();
        if Provider = Enum::"Bifrost LangModel Prov. ori"::Anthropic then begin
            Mock100.ConfigureStatus(HttpStatus, ProviderBody);
            BindSubscription(Mock100);
        end else begin
            Mock65.Configure(HttpStatus, ProviderBody, false, false);
            BindSubscription(Mock65);
        end;
        Dispatch(Data, Locale, Response, MessageId);
        if Provider = Enum::"Bifrost LangModel Prov. ori"::Anthropic then begin
            UnbindSubscription(Mock100);
            RequestBody := Mock100.GetBody(1);
        end else begin
            UnbindSubscription(Mock65);
            RequestBody := Mock65.GetRequestBody();
            Result.Add('uploads', Mock65.GetUploadCount());
            Result.Add('deletes', Mock65.GetDeleteCount());
        end;
        Model.Delete(true);
        Result.Add('response', Response);
        Result.Add('request', RequestBody);
    end;

    local procedure ExecuteFile(InlineValue: JsonObject; Locale: Integer): JsonObject
    var
        Data: JsonObject;
    begin
        Data := AskData();
        Data.Add('file', InlineValue);
        exit(Run(Data, Locale));
    end;

    local procedure ExecuteFiles(Files: JsonArray; Locale: Integer): JsonObject
    var
        Data: JsonObject;
    begin
        Data := AskData();
        Data.Add('files', Files);
        exit(Run(Data, Locale));
    end;

    local procedure Run(Data: JsonObject; Locale: Integer) Response: JsonObject
    var
        MessageId: Guid;
    begin
        Dispatch(Data, Locale, Response, MessageId);
    end;

    local procedure Dispatch(Data: JsonObject; Locale: Integer; var Response: JsonObject; var MessageId: Guid)
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        EmptyId: Guid;
        ResponseTime: Duration;
        ContentType: Text[100];
        TextValue: Text;
    begin
        Data.WriteTo(TextValue);
        RequestContent.AddText(TextValue);
        Dispatcher.EnqueueAndProcess(Enum::"Message Type ori"::"LLM.Prompt.Ask", Enum::"Message Version ori"::"1.0", '', '', 'text/json', RequestContent, EmptyId, Locale, MessageId, ResponseContent, ContentType, ResponseTime);
        ResponseContent.GetSubText(TextValue, 1);
        Assert.IsTrue(Response.ReadFrom(TextValue), TextValue);
    end;

    local procedure VerifyFiles(Response: JsonObject; Expected: Integer)
    var
        Payload: JsonObject;
    begin
        Assert.AreEqual('Success', Response.GetText('status'), Describe(Response));
        Payload := LastPayload();
        Assert.AreEqual(Expected, Payload.GetArray('files').Count(), 'files in the provider payload');
    end;

    local procedure VerifyRefusal(Response: JsonObject; ErrorCode: Text; ParameterName: Text)
    var
        Mock: Codeunit "Mock Bifrost Chat Provider";
    begin
        Assert.AreEqual(ErrorCode, Response.GetText('code'), Describe(Response));
        Assert.AreEqual(ParameterName, Response.GetText('parameter'), Describe(Response));
        Assert.IsFalse(Mock.WasSendChatMessageCalled(), 'refused before any provider request');
    end;

    local procedure LastPayload() Payload: JsonObject
    var
        Mock: Codeunit "Mock Bifrost Chat Provider";
    begin
        Payload.ReadFrom(Mock.GetLastSendPayload());
    end;

    local procedure AskData() Data: JsonObject
    begin
        Data.Add('roleCode', ModelCodeTok);
        Data.Add('question', 'Read this file');
    end;

    local procedure InlineFile(FileName: Text; MimeType: Text; Base64: Text) FileObject: JsonObject
    begin
        FileObject.Add('data', Base64);
        FileObject.Add('mimeType', MimeType);
        FileObject.Add('fileName', FileName);
    end;

    local procedure StagedItems(StagingId: Guid) Items: JsonArray
    var
        Item: JsonObject;
    begin
        Item.Add('stagingId', Format(StagingId, 0, 4));
        Items.Add(Item);
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
        exit(Staging.Create(Input, FileName, MimeType, 'LM127 test'));
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
