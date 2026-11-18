namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;
using System.Utilities;

/// <summary>Issue 156: Custom LLM Ask sends staged text inline, refuses a type it cannot take before the call, and keeps a redacted provider failure.</summary>
codeunit 96082 "LLM 156 Custom Ask Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        FakeKeyTok: Label 'custom156-fixture-key', Locked = true;
        MarkerTok: Label 'Z9Q7lm156', Locked = true;
        PdfBase64Tok: Label 'JVBERi0xLjQK', Locked = true;
        PngBase64Tok: Label 'iVBORw0KGgo=', Locked = true;
        HtmlReplyTok: Label '{"choices":[{"finish_reason":"stop","message":{"role":"assistant","content":"<html><body>OK</body></html>"}}]}', Locked = true;

    /// <summary>AC01/AC04: a staged text note is a text content part, in both locales, never a file part.</summary>
    [Test]
    procedure Ask_StagedText_SentInline()
    var
        Result: JsonObject;
        Response: JsonObject;
        Body: Text;
        Locale: Integer;
        Index: Integer;
    begin
        // [GIVEN] A Custom LLM card and a staged text/plain note. [WHEN] Ask runs. [THEN] The request holds the note text as a text part.
        for Index := 1 to 2 do begin
            Locale := 1033;
            if Index = 2 then
                Locale := 1039;
            Result := RunAsk(InlineFile('', '', ''), true, 'note.txt', 'text/plain', false, Locale, 200, ChatReply());
            Response := Result.GetObject('response');
            Assert.AreEqual('Success', Response.GetText('status'), Describe(Response));
            Assert.AreEqual('OK', Response.GetText('answer'), 'Ask answer.');
            Body := Result.GetText('request');
            Assert.IsTrue(Result.GetText('url').Contains('/chat/completions'), 'Chat completions.');
            Assert.IsTrue(Body.Contains('Attached file note.txt:'), 'The note is a text part named by its file.');
            Assert.IsTrue(Body.Contains('hello custom 156'), 'The decoded note text is sent.');
            Assert.IsFalse(Body.Contains('file_data'), 'No OpenAI file part.');
            Assert.AreEqual(1, Result.GetInteger('calls'), 'One provider call.');
            Assert.IsTrue(Result.GetBoolean('cleanedUp'), 'Owned fixtures removed.');
        end;
    end;

    /// <summary>AC04: a staged text note together with outputFormat html is inline text too.</summary>
    [Test]
    procedure Ask_StagedTextWithHtml_SentInline()
    var
        Result: JsonObject;
        Response: JsonObject;
        Body: Text;
    begin
        // [GIVEN] A staged text note. [WHEN] Ask runs with outputFormat html. [THEN] The note is inline and the html answer returns.
        Result := RunAsk(InlineFile('', '', ''), true, 'note.txt', 'text/plain', true, 1033, 200, HtmlReplyTok);
        Response := Result.GetObject('response');
        Assert.AreEqual('Success', Response.GetText('status'), Describe(Response));
        Assert.AreEqual('<html><body>OK</body></html>', Response.GetText('html'), 'HTML document.');
        Body := Result.GetText('request');
        Assert.IsTrue(Body.Contains('hello custom 156'), 'The decoded note text is sent.');
        Assert.IsFalse(Body.Contains('file_data'), 'No OpenAI file part.');
    end;

    /// <summary>A PNG stays an image part.</summary>
    [Test]
    procedure Ask_Png_StaysImagePart()
    var
        Result: JsonObject;
        Body: Text;
    begin
        // [GIVEN] A PNG. [WHEN] Ask runs. [THEN] The request has an image_url part.
        Result := RunAsk(InlineFile('note.png', 'image/png', PngBase64Tok), false, '', '', false, 1033, 200, ChatReply());
        Body := Result.GetText('request');
        Assert.AreEqual('Success', Result.GetObject('response').GetText('status'), Describe(Result.GetObject('response')));
        Assert.IsTrue(Body.Contains('image_url'), 'PNG is an image part.');
        Assert.IsTrue(Body.Contains('data:image/png;base64,' + PngBase64Tok), 'The data URI is unchanged.');
    end;

    /// <summary>AC02: a PDF is refused before the call with a coded error that names the provider and the file, in both locales.</summary>
    [Test]
    procedure Ask_Pdf_RefusedBeforeCall()
    var
        Result: JsonObject;
        Response: JsonObject;
        Body: Text;
        Locale: Integer;
        Index: Integer;
    begin
        // [GIVEN] A PDF on a Custom LLM card. [WHEN] Ask runs. [THEN] InvalidParameter, no HTTP call, provider and file named.
        for Index := 1 to 2 do begin
            Locale := 1033;
            if Index = 2 then
                Locale := 1039;
            Result := RunAsk(InlineFile('note.pdf', 'application/pdf', PdfBase64Tok), false, '', '', false, Locale, 200, ChatReply());
            Response := Result.GetObject('response');
            Response.WriteTo(Body);
            Assert.AreEqual('Error', Response.GetText('status'), Body);
            Assert.AreEqual('InvalidParameter', Response.GetText('code'), Body);
            Assert.IsTrue(Response.GetText('error').Contains('Custom LLM'), 'The provider is named.');
            Assert.IsTrue(Response.GetText('error').Contains('note.pdf'), 'The attachment is named.');
            Assert.AreEqual('application/pdf', Response.GetText('received'), 'The type is reported.');
            Assert.AreEqual(0, Result.GetInteger('calls'), 'No provider call.');
            Assert.IsFalse(Response.GetText('error').Contains('could not complete'), 'Not the generic message.');
        end;
    end;

    /// <summary>AC03: a 400 keeps the status and a redacted reason, in both locales.</summary>
    [Test]
    procedure Ask_Provider400_ReturnsStatusAndRedactedReason()
    var
        Result: JsonObject;
        Response: JsonObject;
        Body: Text;
        Locale: Integer;
        Index: Integer;
    begin
        // [GIVEN] The endpoint returns 400. [WHEN] Ask runs. [THEN] The caller sees the status and a redacted reason.
        for Index := 1 to 2 do begin
            Locale := 1033;
            if Index = 2 then
                Locale := 1039;
            Result := RunAsk(InlineFile('', '', ''), true, 'note.txt', 'text/plain', false, Locale, 400, ProviderError('Request contains an invalid argument. ' + MarkerTok));
            Response := Result.GetObject('response');
            Response.WriteTo(Body);
            Assert.AreEqual('Error', Response.GetText('status'), Body);
            Assert.AreEqual('PreconditionFailed', Response.GetText('code'), Body);
            Assert.IsTrue(Response.GetText('received').StartsWith('400'), Body);
            Assert.IsTrue(Body.Contains('invalid'), 'A diagnostic word is kept.');
            Assert.IsTrue(Body.Contains('[redacted]'), 'Other tokens are redacted.');
            Assert.IsFalse(Body.Contains(MarkerTok), 'The marker is not returned.');
            if Locale = 1039 then
                Assert.IsTrue(Response.GetText('error').Contains('Ástæða veitanda'), 'The reason follows Icelandic.')
            else
                Assert.IsTrue(Response.GetText('error').Contains('Provider reason'), 'The reason follows English.');
        end;
    end;

    /// <summary>A 401 keeps its body private.</summary>
    [Test]
    procedure Ask_Provider401_KeepsBodyPrivate()
    var
        Result: JsonObject;
        Response: JsonObject;
        Body: Text;
    begin
        // [GIVEN] The endpoint returns 401. [WHEN] Ask runs. [THEN] The body is not copied.
        Result := RunAsk(InlineFile('', '', ''), false, '', '', false, 1033, 401, ProviderError('API key ' + MarkerTok + ' is invalid'));
        Response := Result.GetObject('response');
        Response.WriteTo(Body);
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), Body);
        Assert.IsTrue(Response.GetText('received').StartsWith('401'), 'Status first.');
        Assert.IsFalse(Body.Contains(MarkerTok), 'The marker is not returned.');
        Assert.IsFalse(Body.Contains('is invalid'), 'The authentication sentence is not returned.');
    end;

    local procedure RunAsk(InlineValue: JsonObject; Staged: Boolean; FileName: Text; FileMime: Text; HtmlMode: Boolean; Locale: Integer; HttpStatus: Integer; ProviderBody: Text) Result: JsonObject
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
        Model.Code := CopyStr('C156-' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(Model.Code));
        Model.Validate("Chat Provider", Enum::"Bifrost LangModel Prov. ori"::"Custom LLM");
        Model.Model := 'fixture-model';
        Model."Base URL" := 'https://custom156.invalid';
        Model.Insert(true);
        KeyValue := FakeKey();
        Secrets.SetUserKey(Model.Code, KeyValue);
        Request.Add('roleCode', Model.Code);
        Request.Add('question', 'Return OK');
        if HtmlMode then
            Request.Add('outputFormat', 'html');
        if HasInline then
            Request.Add('file', InlineValue);
        if Staged then begin
            Blob.CreateOutStream(Output, TextEncoding::UTF8);
            Output.WriteText('hello custom 156');
            Blob.CreateInStream(Input);
            StagingId := Staging.Create(Input, FileName, FileMime, 'LM156 owned fixture');
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

    local procedure ProviderError(Message: Text): Text
    begin
        exit('{"error":{"message":"' + Message + '","type":"invalid_request_error"}}');
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
