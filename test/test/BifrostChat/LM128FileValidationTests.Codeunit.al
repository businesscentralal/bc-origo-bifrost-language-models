namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue 128: inline files are validated before any provider call. Data that is not Base64, and content that
/// does not match a declared PDF, PNG or JPEG type, is a typed refusal about the file, never a model-setup hint.
/// Mock provider only; no credentials and no live calls.
/// </summary>
codeunit 96074 "LM 128 File Validation Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        FakeKeyTok: Label 'xlm128-fake-key-K4T8', Locked = true;
        PdfTok: Label 'JVBERi0xLjQK', Locked = true;
        PngTok: Label 'iVBORw0KGgoA', Locked = true;
        JpegTok: Label '/9j/4A==', Locked = true;
        HelloTok: Label 'aGVsbG8=', Locked = true;

    [Test]
    procedure Scenario_AC01_AC02_NotBase64_RefusedBeforeProvider_1033()
    begin
        // Story #128, AC01 AC02 AC03 | Time: none | Risk: None
        VerifyNotBase64('not-base64!!', 1033);
    end;

    [Test]
    procedure Scenario_AC01_AC02_NotBase64_RefusedBeforeProvider_1039()
    begin
        // Story #128, AC01 AC02 AC03 | Time: none | Risk: None
        VerifyNotBase64('not-base64!!', 1039);
    end;

    [Test]
    procedure Scenario_AC01_BadPadding_RefusedBeforeProvider_1033()
    begin
        // Story #128, AC01 AC03 edge: padding in the middle and a length not divisible by four
        VerifyNotBase64('JVBE=Ri0xLjQ', 1033);
        VerifyNotBase64('JVBERi0xLj', 1033);
    end;

    [Test]
    procedure Scenario_AC01_EmptyData_RefusedBeforeProvider_1039()
    begin
        // Story #128, AC01 AC03 edge: empty data
        VerifyNotBase64('', 1039);
    end;

    [Test]
    procedure Scenario_AC01_AC02_TextLabelledPdf_WrongType_1033()
    begin
        // Story #128, AC01 AC02 AC03
        VerifyWrongType(HelloTok, 'application/pdf', 1033);
    end;

    [Test]
    procedure Scenario_AC01_AC02_TextLabelledPdf_WrongType_1039()
    begin
        // Story #128, AC01 AC02 AC03
        VerifyWrongType(HelloTok, 'application/pdf', 1039);
    end;

    [Test]
    procedure Scenario_AC01_PdfLabelledPng_WrongType_1033()
    begin
        // Story #128, AC01 AC03: a real PDF declared as PNG, with a padded upper-case type
        VerifyWrongType(PdfTok, ' IMAGE/PNG ', 1033);
    end;

    [Test]
    procedure Scenario_AC01_PngLabelledJpeg_WrongType_1039()
    begin
        // Story #128, AC01 AC03
        VerifyWrongType(PngTok, 'image/jpeg', 1039);
    end;

    [Test]
    procedure Scenario_AC02_SecondFile_NamesFilesIndex_1033()
    begin
        // Story #128, AC02 AC03: with two files the parameter names the offending index
        VerifyIndexed(1033);
    end;

    [Test]
    procedure Scenario_AC02_SecondFile_NamesFilesIndex_1039()
    begin
        // Story #128, AC02 AC03
        VerifyIndexed(1039);
    end;

    [Test]
    procedure Scenario_AC03_ValidPdfPngJpeg_StillSent_Anthropic()
    begin
        // Story #128, AC03: valid files and an undeclared document type are unchanged
        VerifyValidSent("Bifrost LangModel Prov. ori"::Anthropic, PdfTok, 'application/pdf');
        VerifyValidSent("Bifrost LangModel Prov. ori"::Anthropic, PngTok, 'image/png');
        VerifyValidSent("Bifrost LangModel Prov. ori"::Anthropic, JpegTok, 'image/jpeg');
        VerifyValidSent("Bifrost LangModel Prov. ori"::Anthropic, HelloTok, 'text/plain');
    end;

    [Test]
    procedure Scenario_AC03_ValidPdf_StillUploaded_xAI()
    begin
        // Story #128, AC03
        VerifyValidSent("Bifrost LangModel Prov. ori"::xAI, PdfTok, ' Application/PDF; charset=binary ');
    end;

    [Test]
    procedure Scenario_AC01_EveryFileProvider_RefusesBeforeHttp()
    begin
        // Story #128, AC01: the gate is shared by every file-accepting provider
        VerifyProviderRefuses("Bifrost LangModel Prov. ori"::OpenAI);
        VerifyProviderRefuses("Bifrost LangModel Prov. ori"::"Azure OpenAI");
        VerifyProviderRefuses("Bifrost LangModel Prov. ori"::"Custom LLM");
        VerifyProviderRefuses("Bifrost LangModel Prov. ori"::Anthropic);
        VerifyProviderRefuses("Bifrost LangModel Prov. ori"::Google);
        VerifyProviderRefuses("Bifrost LangModel Prov. ori"::xAI);
    end;

    local procedure VerifyNotBase64(Data: Text; LanguageId: Integer)
    var
        Model: Record "Bifrost Language Model ori";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        Response: JsonObject;
    begin
        CreateModel(Model, "Bifrost LangModel Prov. ori"::Anthropic);
        HttpMock.Configure(200, SuccessBody("Bifrost LangModel Prov. ori"::Anthropic), false, false);
        BindSubscription(HttpMock);
        Response := Execute(RequestText(Model.Code, Data, 'application/pdf'), LanguageId);
        UnbindSubscription(HttpMock);
        AssertNoProviderCall(HttpMock);
        AssertFileRefusal(Response, 'file', 'not base64', LanguageId);
        Model.Delete(true);
    end;

    local procedure VerifyWrongType(Data: Text; MimeType: Text; LanguageId: Integer)
    var
        Model: Record "Bifrost Language Model ori";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        FileHandling: Codeunit "LangModel File Handling ori";
        Response: JsonObject;
    begin
        CreateModel(Model, "Bifrost LangModel Prov. ori"::Anthropic);
        HttpMock.Configure(200, SuccessBody("Bifrost LangModel Prov. ori"::Anthropic), false, false);
        BindSubscription(HttpMock);
        Response := Execute(RequestText(Model.Code, Data, MimeType), LanguageId);
        UnbindSubscription(HttpMock);
        AssertNoProviderCall(HttpMock);
        AssertFileRefusal(Response, 'file', 'content is not ' + FileHandling.NormalizeMimeType(MimeType), LanguageId);
        Model.Delete(true);
    end;

    local procedure VerifyIndexed(LanguageId: Integer)
    var
        Model: Record "Bifrost Language Model ori";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        RequestJson: JsonObject;
        Files: JsonArray;
        Response: JsonObject;
        RequestBody: Text;
    begin
        CreateModel(Model, "Bifrost LangModel Prov. ori"::Anthropic);
        HttpMock.Configure(200, SuccessBody("Bifrost LangModel Prov. ori"::Anthropic), false, false);
        BindSubscription(HttpMock);
        RequestJson.Add('prompt', 'Hello from issue 128');
        RequestJson.Add('roleCode', Model.Code);
        Files.Add(FileObject(PdfTok, 'application/pdf'));
        Files.Add(FileObject('not-base64!!', 'application/pdf'));
        RequestJson.Add('files', Files);
        RequestJson.WriteTo(RequestBody);
        Response := Execute(RequestBody, LanguageId);
        UnbindSubscription(HttpMock);
        AssertNoProviderCall(HttpMock);
        AssertFileRefusal(Response, 'files[1]', 'not base64', LanguageId);
        Model.Delete(true);
    end;

    local procedure VerifyValidSent(ProviderType: Enum "Bifrost LangModel Prov. ori"; Data: Text; MimeType: Text)
    var
        Model: Record "Bifrost Language Model ori";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        Response: JsonObject;
    begin
        CreateModel(Model, ProviderType);
        HttpMock.Configure(200, SuccessBody(ProviderType), false, false);
        BindSubscription(HttpMock);
        Response := Execute(RequestText(Model.Code, Data, MimeType), 1033);
        UnbindSubscription(HttpMock);
        Assert.AreEqual('Success', Response.GetText('status'), 'A valid file is accepted (' + MimeType + ').');
        Assert.IsTrue(HttpMock.GetCallCount() > 0, 'The provider is called for a valid file.');
        Model.Delete(true);
    end;

    local procedure VerifyProviderRefuses(ProviderType: Enum "Bifrost LangModel Prov. ori")
    var
        Model: Record "Bifrost Language Model ori";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        Response: JsonObject;
    begin
        CreateModel(Model, ProviderType);
        HttpMock.Configure(200, SuccessBody(ProviderType), false, false);
        BindSubscription(HttpMock);
        Response := Execute(RequestText(Model.Code, HelloTok, 'application/pdf'), 1033);
        UnbindSubscription(HttpMock);
        AssertNoProviderCall(HttpMock);
        Assert.AreEqual('InvalidParameter', Response.GetText('code'), 'Refusal code for ' + Format(ProviderType));
        Assert.AreEqual('file', Response.GetText('parameter'), 'Refusal parameter for ' + Format(ProviderType));
        Model.Delete(true);
    end;

    local procedure AssertNoProviderCall(var HttpMock: Codeunit "LLM 65 HTTP Mock")
    begin
        Assert.AreEqual(0, HttpMock.GetCallCount(), 'No prompt is sent for an invalid file.');
        Assert.AreEqual(0, HttpMock.GetUploadCount(), 'No upload is sent for an invalid file.');
        Assert.AreEqual('', HttpMock.GetOperationSequence(), 'An invalid file makes no HTTP call.');
    end;

    local procedure AssertFileRefusal(Response: JsonObject; ExpectedParameter: Text; ExpectedReceived: Text; LanguageId: Integer)
    var
        NextStep: Text;
        ResponseText: Text;
    begin
        Assert.AreEqual('Error', Response.GetText('status'), 'Refusal status.');
        Assert.AreEqual('InvalidParameter', Response.GetText('code'), 'The refusal is typed InvalidParameter, not PreconditionFailed.');
        Assert.AreEqual(ExpectedParameter, Response.GetText('parameter'), 'The refusal names the file.');
        Assert.AreEqual(ExpectedReceived, Response.GetText('received'), 'The refusal names the problem.');
        NextStep := Response.GetText('nextStep');
        Assert.AreNotEqual('', NextStep, 'A next step is given.');
        Assert.AreEqual(0, StrPos(NextStep, 'Base URL'), 'The next step is not about the model setup.');
        Assert.AreEqual(0, StrPos(NextStep, 'API key'), 'The next step does not mention the API key.');
        Assert.AreEqual(0, StrPos(NextStep, 'API-lykil'), 'The next step does not mention the API key (is-IS).');
        Assert.IsTrue(NextStep.Contains('No request was sent.') or NextStep.Contains('Engin beiðni var send.'), 'The next step says no request was sent.');
        if LanguageId = 1039 then
            Assert.IsTrue(NextStep.Contains('Engin beiðni var send.'), 'The next step is Icelandic in 1039.')
        else
            Assert.IsTrue(NextStep.Contains('No request was sent.'), 'The next step is English in 1033.');
        Assert.AreEqual(0, StrPos(Response.GetText('error'), 'Check the Base URL'), 'The error is not the setup message.');
        Response.WriteTo(ResponseText);
        Assert.AreEqual(0, StrPos(ResponseText, FakeKeyTok), 'The secret is never returned.');
    end;

    local procedure FileObject(Data: Text; MimeType: Text) FileJson: JsonObject
    begin
        FileJson.Add('fileName', 'issue128.bin');
        FileJson.Add('mimeType', MimeType);
        FileJson.Add('data', Data);
    end;

    local procedure CreateModel(var Model: Record "Bifrost Language Model ori"; ProviderType: Enum "Bifrost LangModel Prov. ori")
    var
        Secrets: Codeunit "LangModel Secrets ori";
        KeyValue: SecretText;
    begin
        Model.Init();
        Model.Code := CopyStr('XLM128' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, MaxStrLen(Model.Code));
        Model.Validate("Chat Provider", ProviderType);
        Model.Model := 'test-model';
        Model."Base URL" := 'https://xlm128.invalid';
        Model.Insert(true);
        KeyValue := Format(FakeKeyTok);
        Secrets.SetUserKey(Model.Code, KeyValue);
    end;

    local procedure RequestText(ModelCode: Code[20]; Data: Text; MimeType: Text) Result: Text
    var
        RequestJson: JsonObject;
    begin
        RequestJson.Add('prompt', 'Hello from issue 128');
        RequestJson.Add('roleCode', ModelCode);
        RequestJson.Add('file', FileObject(Data, MimeType));
        RequestJson.WriteTo(Result);
    end;

    local procedure SuccessBody(ProviderType: Enum "Bifrost LangModel Prov. ori"): Text
    begin
        case ProviderType of
            "Bifrost LangModel Prov. ori"::Anthropic:
                exit('{"content":[{"type":"text","text":"A safe answer"}]}');
            "Bifrost LangModel Prov. ori"::Google:
                exit('{"candidates":[{"content":{"parts":[{"text":"A safe answer"}]}}]}');
            "Bifrost LangModel Prov. ori"::xAI:
                exit('{"output":[{"type":"message","content":[{"type":"output_text","text":"A safe answer"}]}]}');
        end;
        exit('{"choices":[{"message":{"content":"A safe answer"}}]}');
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
        Dispatcher.EnqueueAndProcess("Message Type ori"::"LLM.Prompt.Complete", "Message Version ori"::"1.0", '', '', 'text/json', RequestContent, EmptyTaskId, LanguageId, MessageId, ResponseContent, ResponseContentType, ResponseTime);
        ResponseContent.GetSubText(ResponseText, 1);
        Assert.IsTrue(ResponseJson.ReadFrom(ResponseText), 'Response must be JSON.');
    end;
}
