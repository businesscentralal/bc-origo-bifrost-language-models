namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;
using System.Utilities;

/// <summary>Issue 134: Gemini Ask sends text and PDF through generateContent and keeps a redacted provider failure.</summary>
codeunit 96076 "LLM 134 Gemini Ask Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        FakeKeyTok: Label 'gemini134-fixture-key', Locked = true;
        MarkerTok: Label 'Z9Q7lm134', Locked = true;
        PdfBase64Tok: Label 'JVBERi0xLjQK', Locked = true;
        TextBase64Tok: Label 'aGVsbG8=', Locked = true;
        PngBase64Tok: Label 'iVBORw0KGgo=', Locked = true;
        SuccessBodyTok: Label '{"candidates":[{"content":{"role":"model","parts":[{"text":"OK"}]},"finishReason":"STOP"}]}', Locked = true;

    /// <summary>An inline text file is inline_data on generateContent, in both locales.</summary>
    [Test]
    procedure Ask_TextInline_UsesGenerateContent()
    var
        AskImpl: Codeunit "LLM Prompt Ask Impl ori";
        Result: JsonObject;
        Response: JsonObject;
        Notes: Text;
        Body: Text;
        Locale: Integer;
        Index: Integer;
    begin
        // [GIVEN] A Google model card. [WHEN] Ask gets inline text. [THEN] The request is generateContent inline_data.
        for Index := 1 to 2 do begin
            Locale := 1033;
            if Index = 2 then
                Locale := 1039;
            Result := RunAsk(InlineFile('note.txt', 'text/plain', TextBase64Tok), false, '', '', Locale, 200, SuccessBodyTok);
            Response := Result.GetObject('response');
            Assert.AreEqual('Success', Response.GetText('status'), Describe(Response));
            Assert.AreEqual('OK', Response.GetText('answer'), 'Ask answer.');
            Body := Result.GetText('request');
            Assert.IsTrue(Result.GetText('url').Contains(':generateContent'), 'Text uses generateContent.');
            Assert.IsTrue(Result.GetText('url').Contains('/models/fixture-model'), 'The model card names the model.');
            Assert.IsTrue(Body.Contains('inline_data'), 'Document bytes are inline_data.');
            Assert.IsTrue(Body.Contains('text/plain'), 'The text MIME type is kept.');
            Assert.IsTrue(Body.Contains(TextBase64Tok), 'The text bytes are sent.');
            Assert.IsFalse(Body.Contains('file_data'), 'OpenAI file parts are not sent.');
            Assert.AreEqual(1, Result.GetInteger('calls'), 'One provider call.');
            Assert.AreEqual(0, Result.GetInteger('uploads'), 'No upload.');
            Assert.IsTrue(Result.GetBoolean('cleanedUp'), 'Owned fixture removed.');
        end;
        AskImpl.GetNotes(Notes);
        Assert.IsTrue(Notes.Contains('generateContent'), 'Notes name the document path.');
        Assert.IsTrue(Notes.Contains('Inline file'), 'The inline-file note remains.');
    end;

    /// <summary>An inline PDF uses the same native document path.</summary>
    [Test]
    procedure Ask_PdfInline_UsesGenerateContent()
    var
        Result: JsonObject;
        Body: Text;
    begin
        // [GIVEN] A Google model card. [WHEN] Ask gets an inline PDF. [THEN] generateContent receives the PDF bytes.
        Result := RunAsk(InlineFile('note.pdf', 'application/pdf', PdfBase64Tok), false, '', '', 1033, 200, SuccessBodyTok);
        Assert.AreEqual('Success', Result.GetObject('response').GetText('status'), Describe(Result.GetObject('response')));
        Assert.AreEqual('OK', Result.GetObject('response').GetText('answer'), 'Ask answer.');
        Body := Result.GetText('request');
        Assert.IsTrue(Result.GetText('url').Contains(':generateContent'), 'PDF uses generateContent.');
        Assert.IsTrue(Body.Contains('application/pdf'), 'The PDF MIME type is kept.');
        Assert.IsTrue(Body.Contains(PdfBase64Tok), 'The PDF bytes are sent.');
        Assert.IsFalse(Body.Contains('file_data'), 'OpenAI file parts are not sent.');
        Assert.AreEqual(1, Result.GetInteger('calls'), 'One provider call.');
        Assert.AreEqual(0, Result.GetInteger('uploads'), 'No upload.');
    end;

    /// <summary>A staged text file takes the same path as an inline text file.</summary>
    [Test]
    procedure Ask_TextStaged_UsesGenerateContent()
    var
        Result: JsonObject;
        Body: Text;
    begin
        // [GIVEN] A caller-owned staged text file. [WHEN] Ask runs in Icelandic. [THEN] generateContent receives text/plain.
        Result := RunAsk(InlineFile('', '', ''), true, 'note.txt', 'text/plain', 1039, 200, SuccessBodyTok);
        Assert.AreEqual('Success', Result.GetObject('response').GetText('status'), Describe(Result.GetObject('response')));
        Assert.AreEqual('OK', Result.GetObject('response').GetText('answer'), 'Ask answer.');
        Body := Result.GetText('request');
        Assert.IsTrue(Result.GetText('url').Contains(':generateContent'), 'Staged text uses generateContent.');
        Assert.IsTrue(Body.Contains('text/plain'), 'The staged MIME type is kept.');
        Assert.IsTrue(Body.Contains('inline_data'), 'Staged bytes are inline_data.');
        Assert.IsFalse(Body.Contains('file_data'), 'OpenAI file parts are not sent.');
        Assert.IsTrue(Result.GetBoolean('cleanedUp'), 'Owned model and staging removed.');
    end;

    /// <summary>A PNG stays on the OpenAI-compatible chat endpoint. The short test fixture is not a full PNG signature.</summary>
    [Test]
    procedure Ask_Png_StaysOnChatCompletions()
    var
        Result: JsonObject;
        Body: Text;
    begin
        // [GIVEN] A PNG inline file. [WHEN] Ask runs. [THEN] The chat endpoint receives an image_url part.
        Result := RunAsk(InlineFile('note.png', 'image/png', PngBase64Tok), false, '', '', 1033, 200, ChatReply());
        Body := Result.GetText('request');
        Assert.AreEqual('Success', Result.GetObject('response').GetText('status'), Describe(Result.GetObject('response')));
        Assert.IsTrue(Result.GetText('url').Contains('/openai/'), 'PNG uses the OpenAI-compatible base.');
        Assert.IsTrue(Result.GetText('url').Contains('/chat/completions'), 'PNG uses chat completions.');
        Assert.IsFalse(Result.GetText('url').Contains(':generateContent'), 'PNG does not use generateContent.');
        Assert.IsTrue(Body.Contains('image_url'), 'PNG is an image part.');
        Assert.IsTrue(Body.Contains('data:image/png;base64,' + PngBase64Tok), 'The PNG data URI is unchanged.');
        Assert.IsFalse(Body.Contains('inline_data'), 'PNG is not rewritten as inline_data.');
    end;

    /// <summary>A PDF whose bytes are not a PDF is refused before any provider call.</summary>
    [Test]
    procedure Ask_PdfWrongSignature_RefusesBeforeHttp()
    var
        Result: JsonObject;
        Response: JsonObject;
        Locale: Integer;
        Index: Integer;
    begin
        // [GIVEN] Text bytes labelled as a PDF. [WHEN] Ask runs. [THEN] No HTTP call is made.
        for Index := 1 to 2 do begin
            Locale := 1033;
            if Index = 2 then
                Locale := 1039;
            Result := RunAsk(InlineFile('note.pdf', 'application/pdf', TextBase64Tok), false, '', '', Locale, 200, SuccessBodyTok);
            Response := Result.GetObject('response');
            Assert.AreEqual('Error', Response.GetText('status'), Describe(Response));
            Assert.AreEqual('InvalidParameter', Response.GetText('code'), 'Wrong type is invalid.');
            Assert.AreEqual('file', Response.GetText('parameter'), 'One file is parameter file.');
            Assert.IsTrue(Response.GetText('received').Contains('content is not application/pdf'), Describe(Response));
            Assert.AreEqual(0, Result.GetInteger('calls'), 'No provider call.');
        end;
    end;

    /// <summary>A Gemini 400 on a document Ask keeps the status and a redacted reason, in both locales.</summary>
    [Test]
    procedure Ask_Provider400_ReturnsStatusAndRedactedReason()
    var
        Result: JsonObject;
        Response: JsonObject;
        Body: Text;
        Locale: Integer;
        Index: Integer;
    begin
        // [GIVEN] generateContent returns 400 INVALID_ARGUMENT. [WHEN] Ask runs. [THEN] The caller sees the status and a redacted reason.
        for Index := 1 to 2 do begin
            Locale := 1033;
            if Index = 2 then
                Locale := 1039;
            Result := RunAsk(InlineFile('note.pdf', 'application/pdf', PdfBase64Tok), false, '', '', Locale, 400, ProviderError(400, 'INVALID_ARGUMENT', 'Request contains an invalid argument. ' + MarkerTok));
            Response := Result.GetObject('response');
            Response.WriteTo(Body);
            Assert.AreEqual('Error', Response.GetText('status'), Body);
            Assert.AreEqual('PreconditionFailed', Response.GetText('code'), 'Coded provider refusal.');
            Assert.AreEqual('400 invalid_argument', Response.GetText('received'), 'Status and Google status.');
            Assert.IsTrue(Body.Contains('invalid'), 'A diagnostic word is kept.');
            Assert.IsTrue(Body.Contains('[redacted]'), 'Other tokens are redacted.');
            Assert.IsFalse(Body.Contains(MarkerTok), 'The marker is not returned.');
            if Locale = 1039 then
                Assert.IsTrue(Response.GetText('error').Contains('Ástæða veitanda'), 'The reason follows Icelandic.')
            else
                Assert.IsTrue(Response.GetText('error').Contains('Provider reason'), 'The reason follows English.');
        end;
    end;

    /// <summary>A text-only Gemini 400 uses the same safe error, without a document.</summary>
    [Test]
    procedure Ask_Text400_ReturnsStatusAndRedactedReason()
    var
        Result: JsonObject;
        Body: Text;
    begin
        // [GIVEN] Chat completions returns 400. [WHEN] Ask has no file. [THEN] The status and redacted reason are kept.
        Result := RunAsk(InlineFile('', '', ''), false, '', '', 1033, 400, ProviderError(400, 'INVALID_ARGUMENT', 'Request contains an invalid argument. ' + MarkerTok));
        Result.GetObject('response').WriteTo(Body);
        Assert.AreEqual('400 invalid_argument', Result.GetObject('response').GetText('received'), Body);
        Assert.IsTrue(Result.GetText('url').Contains('/chat/completions'), 'Text-only stays on chat completions.');
        Assert.IsFalse(Body.Contains(MarkerTok), 'The marker is not returned.');
        Assert.AreEqual(1, Result.GetInteger('calls'), 'The provider was called.');
    end;

    /// <summary>Authentication bodies stay private.</summary>
    [Test]
    procedure Ask_Provider401_KeepsBodyPrivate()
    var
        Result: JsonObject;
        Response: JsonObject;
        Body: Text;
    begin
        // [GIVEN] Gemini returns 401. [WHEN] Ask runs. [THEN] The body is not copied and received is the status only.
        Result := RunAsk(InlineFile('', '', ''), false, '', '', 1033, 401, ProviderError(401, 'UNAUTHENTICATED', 'API key ' + MarkerTok + ' is invalid'));
        Response := Result.GetObject('response');
        Response.WriteTo(Body);
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), Body);
        Assert.AreEqual('401', Response.GetText('received'), 'No provider code and no reason.');
        Assert.IsFalse(Body.Contains(MarkerTok), 'The marker is not returned.');
        Assert.IsFalse(Body.Contains('API key'), 'The authentication body is not returned.');
    end;

    /// <summary>A document Ask can continue a tool round on generateContent.</summary>
    [Test]
    procedure Ask_PdfToolRound_StaysOnGenerateContent()
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Mock: Codeunit "LLM 65 HTTP Mock";
        Provider: Interface "Bifrost LangModel Provider ori";
        Response: JsonObject;
        State: Text;
        Body: Text;
    begin
        // [GIVEN] generateContent asks for a tool. [WHEN] The caller continues. [THEN] The next round is still generateContent.
        TempArgument."Base URL" := 'https://gemini134.invalid/v1beta';
        TempArgument.Model := 'fixture-model';
        TempArgument.SetApiKey(FakeKey());
        TempArgument.SetPayload('{"messages":[{"role":"user","content":"Read this"}],"files":[{"fileName":"fixture.pdf","mimeType":"application/pdf","data":"' + PdfBase64Tok + '"}],"allowedTools":["who_am_i"]}');
        TempArgument."Procedure Type" := TempArgument."Procedure Type"::SendChatMessage;
        Provider := Enum::"Bifrost LangModel Prov. ori"::Google;
        Mock.Configure(200, '{"candidates":[{"content":{"role":"model","parts":[{"functionCall":{"name":"who_am_i","args":{}}}]},"finishReason":"STOP"}]}', false, false);
        BindSubscription(Mock);
        Provider.Execute(TempArgument);
        UnbindSubscription(Mock);
        Response.ReadFrom(TempArgument.GetResultText());
        Assert.AreEqual('tool_calls', Response.GetText('type'), 'The document round can call a tool.');
        State := Response.GetText('conversationState');
        Assert.IsTrue(State.Contains('geminiDocuments'), 'Continuation stays on generateContent.');
        Assert.IsTrue(State.Contains(PdfBase64Tok), 'The local PDF bytes stay in the conversation.');
        TempArgument.SetConversationState(State);
        TempArgument.SetToolResults('[{"id":"call_1","result":"fixture identity"}]');
        TempArgument."Procedure Type" := TempArgument."Procedure Type"::ContinueWithToolResults;
        Mock.Configure(200, SuccessBodyTok, false, false);
        BindSubscription(Mock);
        Provider.Execute(TempArgument);
        UnbindSubscription(Mock);
        Response.ReadFrom(TempArgument.GetResultText());
        Assert.AreEqual('OK', Response.GetText('reply'), 'Continuation succeeds.');
        Body := Mock.GetRequestBody();
        Assert.IsTrue(Mock.GetRequestUrl().Contains(':generateContent'), 'The tool result stays on generateContent.');
        Assert.IsTrue(Body.Contains('functionResponse'), 'The tool result is a function response.');
        Assert.IsTrue(Body.Contains('who_am_i'), 'The tool name is kept.');
        Assert.IsTrue(Body.Contains(PdfBase64Tok), 'The PDF is sent again from local bytes.');
        Assert.IsFalse(Body.Contains('file_data'), 'The continuation is not an OpenAI file part.');
    end;

    local procedure RunAsk(InlineValue: JsonObject; Staged: Boolean; FileName: Text; FileMime: Text; Locale: Integer; HttpStatus: Integer; ProviderBody: Text) Result: JsonObject
    var
        Model: Record "Bifrost Language Model ori";
        Secrets: Codeunit "LangModel Secrets ori";
        Staging: Codeunit "Blob Staging ori";
        Blob: Codeunit "Temp Blob";
        Mock: Codeunit "LLM 65 HTTP Mock";
        Request: JsonObject;
        Response: JsonObject;
        Output: OutStream;
        Input: InStream;
        KeyValue: SecretText;
        StagingId: Guid;
        MessageId: Guid;
        HasInline: Boolean;
    begin
        HasInline := InlineValue.Contains('data');
        Model.Code := CopyStr('G134-' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(Model.Code));
        Model.Validate("Chat Provider", Enum::"Bifrost LangModel Prov. ori"::Google);
        Model.Model := 'fixture-model';
        Model."Base URL" := 'https://gemini134.invalid/v1beta';
        Model.Insert(true);
        KeyValue := FakeKey();
        Secrets.SetUserKey(Model.Code, KeyValue);
        Request.Add('roleCode', Model.Code);
        Request.Add('question', 'Return OK');
        if HasInline then
            Request.Add('file', InlineValue);
        if Staged then begin
            Blob.CreateOutStream(Output, TextEncoding::UTF8);
            Output.WriteText('hello gemini 134');
            Blob.CreateInStream(Input);
            StagingId := Staging.Create(Input, FileName, FileMime, 'LM134 owned fixture');
            Request.Add('attachments', StagedItems(StagingId));
        end;
        Commit();
        Mock.Configure(HttpStatus, ProviderBody, false, false);
        BindSubscription(Mock);
        Dispatch(Request, Locale, Response, MessageId);
        UnbindSubscription(Mock);
        Model.Delete(true);
        if Staged then
            if Staging.Exists(StagingId) then
                Staging.Take(StagingId, Blob);
        Result.Add('response', Response);
        Result.Add('request', Mock.GetRequestBody());
        Result.Add('url', Mock.GetRequestUrl());
        Result.Add('calls', Mock.GetCallCount());
        Result.Add('uploads', Mock.GetUploadCount());
        Result.Add('cleanedUp', OwnedFixturesRemoved(Model.Code, Staged, StagingId));
    end;

    local procedure Dispatch(Request: JsonObject; Locale: Integer; var Response: JsonObject; var MessageId: Guid)
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        RequestText: Text;
        ResponseText: Text;
        ResponseContentType: Text[100];
        EmptyTaskId: Guid;
        ResponseTime: Duration;
    begin
        Request.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.EnqueueAndProcess(Enum::"Message Type ori"::"LLM.Prompt.Ask", Enum::"Message Version ori"::"1.0", '', '', 'text/json', RequestContent, EmptyTaskId, Locale, MessageId, ResponseContent, ResponseContentType, ResponseTime);
        ResponseContent.GetSubText(ResponseText, 1);
        Assert.IsTrue(Response.ReadFrom(ResponseText), ResponseText);
    end;

    local procedure InlineFile(FileName: Text; MimeType: Text; Base64: Text) FileObject: JsonObject
    begin
        if Base64 = '' then
            exit;
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

    local procedure ProviderError(StatusCode: Integer; StatusName: Text; Message: Text): Text
    begin
        exit('{"error":{"code":' + Format(StatusCode, 0, 9) + ',"message":"' + Message + '","status":"' + StatusName + '"}}');
    end;

    local procedure ChatReply(): Text
    begin
        exit('{"choices":[{"finish_reason":"stop","message":{"role":"assistant","content":"OK"}}]}');
    end;

    local procedure FakeKey() Result: SecretText
    begin
        Result := Format(FakeKeyTok);
    end;

    local procedure Describe(Response: JsonObject) TextValue: Text
    begin
        Response.WriteTo(TextValue);
    end;

    local procedure OwnedFixturesRemoved(ModelCode: Code[20]; Staged: Boolean; StagingId: Guid): Boolean
    var
        Model: Record "Bifrost Language Model ori";
        Staging: Codeunit "Blob Staging ori";
    begin
        if Model.Get(ModelCode) then
            exit(false);
        if not Staged then
            exit(true);
        exit(not Staging.Exists(StagingId));
    end;
}
