namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;
using System.Text;
using System.Utilities;

/// <summary>
/// Issue 133: LLM.Prompt.Complete sends text as a chat-completions text part, never as a file part.
/// Ask keeps its current wire format.
/// </summary>
codeunit 96078 "LLM 133 Text File Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        FakeKeyTok: Label 'xlm133-fake-key-Z9Q7', Locked = true;
        NoteTok: Label 'hello note', Locked = true;
        NoteFileTok: Label 'note.txt', Locked = true;
        PdfDataTok: Label 'JVBERi0xLjQK', Locked = true;
        StoredUrl: Text;

    [Test]
    procedure Scenario_AC01_InlineText_SendsTextPart()
    begin
        // Story #133, AC01 | Time: none | Risk: None
        // [SCENARIO] An inline text/plain file on OpenAI-shaped chat completions is a text part
        VerifyCompleteText("Bifrost LangModel Prov. ori"::OpenAI, false, 1033);
        VerifyCompleteText("Bifrost LangModel Prov. ori"::OpenAI, false, 1039);
        VerifyCompleteText("Bifrost LangModel Prov. ori"::"Azure OpenAI", false, 1033);
        VerifyCompleteText("Bifrost LangModel Prov. ori"::"Azure OpenAI", false, 1039);
        VerifyCompleteText("Bifrost LangModel Prov. ori"::"Custom LLM", false, 1033);
        VerifyCompleteText("Bifrost LangModel Prov. ori"::"Custom LLM", false, 1039);
    end;

    [Test]
    procedure Scenario_AC01_StagedText_SendsTextPart()
    begin
        // Story #133, AC01 | Time: none | Risk: None
        // [SCENARIO] A staged text/plain attachment takes the same text part
        VerifyCompleteText("Bifrost LangModel Prov. ori"::OpenAI, true, 1033);
        VerifyCompleteText("Bifrost LangModel Prov. ori"::OpenAI, true, 1039);
        VerifyCompleteText("Bifrost LangModel Prov. ori"::"Azure OpenAI", true, 1033);
        VerifyCompleteText("Bifrost LangModel Prov. ori"::"Azure OpenAI", true, 1039);
        VerifyCompleteText("Bifrost LangModel Prov. ori"::"Custom LLM", true, 1033);
        VerifyCompleteText("Bifrost LangModel Prov. ori"::"Custom LLM", true, 1039);
    end;

    [Test]
    procedure Scenario_AC01_OneCharacter_SendsTextPart()
    begin
        // Story #133, AC01 | Time: none | Risk: None
        // [SCENARIO] A one-character text file is still inlined, not sent as a file
        VerifyCompleteBody("Bifrost LangModel Prov. ori"::OpenAI, false, 1033, 'a.txt', 'text/plain', Encode('a'), 'a', false);
    end;

    [Test]
    procedure Scenario_AC02_NonPdf_NeverFilePart()
    begin
        // Story #133, AC02 | Time: none | Risk: None
        // [SCENARIO] A mime type chat completions cannot take as a file is never a file part
        VerifyCompleteBody("Bifrost LangModel Prov. ori"::OpenAI, false, 1033, 'data.json', 'application/json', Encode('{"k":1}'), '{"k":1}', false);
        VerifyCompleteBody("Bifrost LangModel Prov. ori"::"Custom LLM", false, 1039, 'page.html', 'text/html', Encode('<p>x</p>'), '<p>x</p>', false);
        VerifyCompleteBody("Bifrost LangModel Prov. ori"::"Azure OpenAI", false, 1033, 'doc.xml', 'application/xml', Encode('<a/>'), '<a/>', false);
        VerifyCompleteBody("Bifrost LangModel Prov. ori"::OpenAI, false, 1039, 'blob.bin', 'application/octet-stream', Encode('bin'), 'bin', false);
    end;

    [Test]
    procedure Scenario_AC02_Pdf_StaysFilePart()
    begin
        // Story #133, AC02 | Time: none | Risk: None
        // [SCENARIO] A PDF is still a file part
        VerifyCompleteBody("Bifrost LangModel Prov. ori"::OpenAI, false, 1033, 'invoice.pdf', 'application/pdf', PdfDataTok, '', true);
        VerifyCompleteBody("Bifrost LangModel Prov. ori"::"Custom LLM", false, 1039, 'invoice.pdf', 'application/pdf', PdfDataTok, '', true);
    end;

    [Test]
    procedure Scenario_AC02_TextBesidePdf_OnlyPdfIsFile()
    var
        Files: JsonArray;
        Body: Text;
    begin
        // Story #133, AC02 | Time: none | Risk: None
        // [SCENARIO] Text beside a PDF is a text part; only the PDF is a file part
        Files.Add(FileObject(NoteFileTok, 'text/plain', Encode(NoteTok)));
        Files.Add(FileObject('invoice.pdf', 'application/pdf', PdfDataTok));
        Body := RunComplete("Bifrost LangModel Prov. ori"::OpenAI, 1033, Files, NullStagingId());
        Assert.IsTrue(Body.Contains(NoteTok), 'Decoded text is in the prompt.');
        Assert.IsTrue(Body.Contains('"type":"file"'), 'The PDF stays a file part.');
        Assert.IsTrue(Body.Contains(PdfDataTok), 'The PDF bytes stay in the file part.');
        Assert.IsFalse(Body.Contains(Encode(NoteTok)), 'The text file is not sent as Base64.');
    end;

    [Test]
    procedure Scenario_AC02_Charset_InlinesWithoutParameter()
    var
        Body: Text;
    begin
        // Story #133, AC02 | Time: none | Risk: None
        // [SCENARIO] Letter case and a charset parameter do not produce a file part
        Body := RunComplete("Bifrost LangModel Prov. ori"::"Custom LLM", 1039, OneFile(NoteFileTok, ' TEXT/PLAIN; charset=utf-8 ', Encode(NoteTok)), NullStagingId());
        Assert.IsTrue(Body.Contains(NoteTok), 'Decoded text is sent.');
        Assert.IsFalse(Body.Contains('charset'), 'The charset parameter is not sent.');
        Assert.IsFalse(Body.Contains('file_data'), 'No file part.');
        Assert.IsFalse(Body.Contains('"type":"file"'), 'No file content part.');
    end;

    [Test]
    procedure Scenario_AC02_NotBase64_RefusedBeforeHttp()
    begin
        // Story #133, AC02 | Time: none | Risk: None
        // [SCENARIO] Text that is not Base64 is refused before any provider call
        VerifyRefused(1033);
        VerifyRefused(1039);
    end;

    [Test]
    procedure Scenario_AC03_AskResponses_TextStaysInputFile()
    begin
        // Story #133, AC03 | Time: none | Risk: None
        // [SCENARIO] Ask on a reasoning model still sends text as a Responses input_file
        VerifyAsk('gpt-6.1', 1033, true);
        VerifyAsk('gpt-6.1', 1039, true);
    end;

    [Test]
    procedure Scenario_AC03_AskChat_TextStaysFilePart()
    begin
        // Story #133, AC03 | Time: none | Risk: None
        // [SCENARIO] Ask on chat completions still sends text as a file part
        VerifyAsk('gpt-4o-mini', 1033, false);
        VerifyAsk('gpt-4o-mini', 1039, false);
    end;

    local procedure VerifyCompleteText(ProviderType: Enum "Bifrost LangModel Prov. ori"; Staged: Boolean; Locale: Integer)
    begin
        VerifyCompleteBody(ProviderType, Staged, Locale, NoteFileTok, 'text/plain', Encode(NoteTok), NoteTok, false);
    end;

    local procedure VerifyCompleteBody(ProviderType: Enum "Bifrost LangModel Prov. ori"; Staged: Boolean; Locale: Integer; FileName: Text; MimeType: Text; Data: Text; ExpectedText: Text; ExpectFilePart: Boolean)
    var
        Files: JsonArray;
        Body: Text;
        Url: Text;
    begin
        if Staged then
            Body := RunComplete(ProviderType, Locale, Files, Stage(FileName, MimeType, Data))
        else
            Body := RunComplete(ProviderType, Locale, OneFile(FileName, MimeType, Data), NullStagingId());
        Url := LastUrl();
        Assert.IsTrue(Url.Contains('chat/completions'), 'Complete uses chat completions.');
        AssertParts(Body, FileName, ExpectedText, ExpectFilePart, Data);
    end;

    local procedure AssertParts(Body: Text; FileName: Text; ExpectedText: Text; ExpectFilePart: Boolean; RawData: Text)
    var
        Root: JsonObject;
        Messages: JsonToken;
        Message: JsonToken;
        Content: JsonToken;
        Part: JsonToken;
        PartObject: JsonObject;
        NestedFile: JsonToken;
        Texts: Text;
        HasFile: Boolean;
        HasFileData: Boolean;
    begin
        Assert.IsTrue(Root.ReadFrom(Body), 'Prompt body is JSON.');
        Assert.IsTrue(Root.Get('messages', Messages), 'Prompt has messages.');
        foreach Message in Messages.AsArray() do begin
            if not Message.AsObject().Get('content', Content) then
                continue;
            if not Content.IsArray() then
                continue;
            foreach Part in Content.AsArray() do begin
                PartObject := Part.AsObject();
                if PartObject.GetText('type') = 'text' then
                    Texts += PartObject.GetText('text');
                if PartObject.GetText('type') = 'file' then begin
                    HasFile := true;
                    if PartObject.Get('file', NestedFile) then
                        HasFileData := NestedFile.AsObject().Contains('file_data');
                end;
            end;
        end;
        Assert.AreEqual(ExpectFilePart, HasFile, 'A file part is only for PDF.');
        Assert.AreEqual(ExpectFilePart, HasFileData, 'file_data is only for PDF.');
        if ExpectFilePart then
            Assert.IsTrue(Texts.Contains(PdfDataTok) or Body.Contains(PdfDataTok), 'PDF bytes stay on the file part.')
        else begin
            Assert.IsTrue(Texts.Contains('Attached file ' + FileName + ':'), 'The text part names the file.');
            Assert.IsTrue(Texts.Contains(ExpectedText), 'Decoded text reaches the provider.');
            Assert.IsFalse(Body.Contains(RawData), 'The Base64 payload is not sent.');
        end;
    end;

    local procedure VerifyRefused(Locale: Integer)
    var
        Model: Record "Bifrost Language Model ori";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        Response: JsonObject;
    begin
        CreateModel(Model, "Bifrost LangModel Prov. ori"::OpenAI, 'fixture-model');
        HttpMock.Configure(200, CompleteReply(), false, false);
        BindSubscription(HttpMock);
        Response := Dispatch("Message Type ori"::"LLM.Prompt.Complete", CompleteRequest(Model.Code, OneFile(NoteFileTok, 'text/plain', '!!!!'), NullStagingId()), Locale);
        UnbindSubscription(HttpMock);
        Assert.AreEqual(0, HttpMock.GetCallCount(), 'No prompt is sent.');
        Assert.AreEqual('Error', Response.GetText('status'), 'Refusal status.');
        Assert.AreEqual('InvalidParameter', Response.GetText('code'), 'Refusal code.');
        Assert.AreEqual('file', Response.GetText('parameter'), 'The refusal names file.');
        Assert.AreEqual('not base64', Response.GetText('received'), 'The refusal names the bad data.');
        Model.Delete(true);
    end;

    local procedure VerifyAsk(ModelName: Text; Locale: Integer; Responses: Boolean)
    var
        Model: Record "Bifrost Language Model ori";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        Data: JsonObject;
        Response: JsonObject;
        Body: Text;
        Url: Text;
    begin
        CreateModel(Model, "Bifrost LangModel Prov. ori"::OpenAI, ModelName);
        if Responses then
            HttpMock.Configure(200, ResponsesReply(), false, false)
        else
            HttpMock.Configure(200, ChatReply(), false, false);
        BindSubscription(HttpMock);
        Data.Add('roleCode', Model.Code);
        Data.Add('question', 'Read the note');
        Data.Add('file', FileObject(NoteFileTok, 'text/plain', Encode(NoteTok)));
        Response := Dispatch("Message Type ori"::"LLM.Prompt.Ask", Data, Locale);
        Body := HttpMock.GetRequestBody();
        Url := HttpMock.GetRequestUrl();
        UnbindSubscription(HttpMock);
        Assert.AreEqual('Success', Response.GetText('status'), 'Ask still succeeds.');
        if Responses then begin
            Assert.IsTrue(Url.EndsWith('/v1/responses'), 'Reasoning Ask stays on Responses.');
            Assert.IsTrue(Body.Contains('"type":"input_file"'), 'Text stays an input_file.');
            Assert.IsTrue(Body.Contains('file_data'), 'Responses still carries file_data.');
            Assert.IsTrue(Body.Contains('data:text/plain;base64,'), 'The text mime stays on the data URI.');
        end else begin
            Assert.IsTrue(Url.EndsWith('/v1/chat/completions'), 'Non-reasoning Ask stays on chat completions.');
            Assert.IsTrue(Body.Contains('"type":"file"'), 'Ask chat completions still use a file part.');
            Assert.IsTrue(Body.Contains('file_data'), 'Ask chat completions still send file_data.');
            Assert.IsTrue(Body.Contains('data:text/plain;base64,'), 'Ask still sends the text mime.');
        end;
        Model.Delete(true);
    end;

    local procedure RunComplete(ProviderType: Enum "Bifrost LangModel Prov. ori"; Locale: Integer; Files: JsonArray; StagingId: Guid) Body: Text
    var
        Model: Record "Bifrost Language Model ori";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        Response: JsonObject;
    begin
        CreateModel(Model, ProviderType, 'fixture-model');
        HttpMock.Configure(200, CompleteReply(), false, false);
        BindSubscription(HttpMock);
        Response := Dispatch("Message Type ori"::"LLM.Prompt.Complete", CompleteRequest(Model.Code, Files, StagingId), Locale);
        Body := HttpMock.GetRequestBody();
        LastUrl(HttpMock.GetRequestUrl());
        UnbindSubscription(HttpMock);
        Assert.AreEqual('Success', Response.GetText('status'), 'Complete succeeds.');
        Assert.AreEqual(1, HttpMock.GetCallCount(), 'One prompt.');
        Assert.AreEqual(0, HttpMock.GetUploadCount(), 'Chat completions do not upload the file.');
        Model.Delete(true);
    end;

    local procedure CompleteRequest(ModelCode: Code[20]; Files: JsonArray; StagingId: Guid) Request: JsonObject
    var
        Attachment: JsonObject;
        Attachments: JsonArray;
    begin
        Request.Add('roleCode', ModelCode);
        Request.Add('prompt', 'Read the file');
        if Files.Count() = 1 then
            Request.Add('file', FirstObject(Files))
        else
            if Files.Count() > 1 then
                Request.Add('files', Files);
        if not IsNullGuid(StagingId) then begin
            Attachment.Add('stagingId', Format(StagingId, 0, 4));
            Attachments.Add(Attachment);
            Request.Add('attachments', Attachments);
        end;
    end;

    local procedure Dispatch(MessageType: Enum "Message Type ori"; Request: JsonObject; Locale: Integer) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        RequestText: Text;
        ResponseText: Text;
        ResponseContentType: Text[100];
        MessageId: Guid;
        EmptyTaskId: Guid;
        ResponseTime: Duration;
    begin
        Request.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.EnqueueAndProcess(MessageType, "Message Version ori"::"1.0", '', '', 'text/json', RequestContent, EmptyTaskId, Locale, MessageId, ResponseContent, ResponseContentType, ResponseTime);
        ResponseContent.GetSubText(ResponseText, 1);
        Assert.IsTrue(Response.ReadFrom(ResponseText), 'Dispatcher response is JSON.');
    end;

    local procedure CreateModel(var Model: Record "Bifrost Language Model ori"; ProviderType: Enum "Bifrost LangModel Prov. ori"; ModelName: Text)
    var
        Secrets: Codeunit "LangModel Secrets ori";
        KeyValue: SecretText;
    begin
        Model.Init();
        Model.Code := CopyStr('X133' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(Model.Code));
        Model.Validate("Chat Provider", ProviderType);
        Model.Model := CopyStr(ModelName, 1, MaxStrLen(Model.Model));
        Model."Base URL" := 'https://xlm133.invalid';
        Model.Insert(true);
        KeyValue := Format(FakeKeyTok);
        Secrets.SetUserKey(Model.Code, KeyValue);
    end;

    local procedure NullStagingId(): Guid
    var
        EmptyId: Guid;
    begin
        exit(EmptyId);
    end;

    local procedure Stage(FileName: Text; MimeType: Text; Data: Text): Guid
    var
        Staging: Codeunit "Blob Staging ori";
        Base64Convert: Codeunit "Base64 Convert";
        Blob: Codeunit "Temp Blob";
        Output: OutStream;
        Input: InStream;
    begin
        Blob.CreateOutStream(Output);
        Base64Convert.FromBase64(Data, Output);
        Blob.CreateInStream(Input);
        exit(Staging.Create(Input, FileName, MimeType, 'LM133 owned fixture'));
    end;

    local procedure FirstObject(Files: JsonArray): JsonObject
    var
        Token: JsonToken;
    begin
        Files.Get(0, Token);
        exit(Token.AsObject());
    end;

    local procedure OneFile(FileName: Text; MimeType: Text; Data: Text) Files: JsonArray
    begin
        Files.Add(FileObject(FileName, MimeType, Data));
    end;

    local procedure FileObject(FileName: Text; MimeType: Text; Data: Text) FileJson: JsonObject
    begin
        FileJson.Add('fileName', FileName);
        FileJson.Add('mimeType', MimeType);
        FileJson.Add('data', Data);
    end;

    local procedure Encode(Value: Text): Text
    var
        Base64Convert: Codeunit "Base64 Convert";
        TempBlob: Codeunit "Temp Blob";
        Output: OutStream;
        Input: InStream;
    begin
        TempBlob.CreateOutStream(Output, TextEncoding::UTF8);
        Output.WriteText(Value);
        TempBlob.CreateInStream(Input);
        exit(Base64Convert.ToBase64(Input));
    end;

    local procedure CompleteReply(): Text
    begin
        exit('{"choices":[{"message":{"content":"A safe answer"}}]}');
    end;

    local procedure ChatReply(): Text
    begin
        exit('{"choices":[{"finish_reason":"stop","message":{"role":"assistant","content":"ok note"}}]}');
    end;

    local procedure ResponsesReply(): Text
    begin
        exit('{"status":"completed","output":[{"type":"message","content":[{"type":"output_text","text":"ok note"}]}]}');
    end;

    local procedure LastUrl(NewUrl: Text)
    begin
        StoredUrl := NewUrl;
    end;

    local procedure LastUrl(): Text
    begin
        exit(StoredUrl);
    end;
}
