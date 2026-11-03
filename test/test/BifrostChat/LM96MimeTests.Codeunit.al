namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue 96: the shared file check trims a MIME type, ignores letter case and parameters, and sends that type.
/// </summary>
codeunit 96041 "LM 96 MIME Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        IsInitialized: Boolean;
        FakeKeyTok: Label 'xlm96-fake-key-Z9Q7', Locked = true;

    [Test]
    procedure Scenario_AC01_PaddedUpperParameterised_ClassifiesMime()
    var
        FileHandling: Codeunit "LangModel File Handling ori";
    begin
        // Story #96, AC01 | Time: none | Risk: None
        // [SCENARIO] The shared check trims, ignores case and drops parameters before the image decision
        Initialize();

        // [THEN] PNG and JPEG stay inline after padding, case and parameters
        Assert.AreEqual('image/png', FileHandling.NormalizeMimeType(' image/PNG '), 'Padded PNG is image/png.');
        Assert.AreEqual('image/jpeg', FileHandling.NormalizeMimeType('image/jpeg; charset=binary'), 'Parameters are dropped.');
        Assert.AreEqual('image/jpeg', FileHandling.NormalizeMimeType(' Image/JPEG ; charset=binary '), 'Case, space and parameters normalise.');
        Assert.IsTrue(FileHandling.IsInlineImageMime(' image/PNG '), 'Padded PNG stays inline.');
        Assert.IsTrue(FileHandling.IsInlineImageMime('IMAGE/JPEG'), 'Upper JPEG stays inline.');
        Assert.IsTrue(FileHandling.IsInlineImageMime('image/jpeg; charset=binary'), 'Parameterised JPEG stays inline.');
        Assert.IsFalse(FileHandling.IsRefusedImageMime(' image/PNG '), 'Padded PNG is not refused.');

        // [THEN] GIF, WebP and image/jpg stay refused after the same normalisation
        Assert.AreEqual('image/gif', FileHandling.NormalizeMimeType(' image/GIF '), 'Padded GIF is image/gif.');
        Assert.AreEqual('image/webp', FileHandling.NormalizeMimeType('IMAGE/WEBP; charset=binary'), 'Parameterised WebP is image/webp.');
        Assert.IsTrue(FileHandling.IsRefusedImageMime(' image/GIF '), 'Padded GIF is refused.');
        Assert.IsTrue(FileHandling.IsRefusedImageMime('IMAGE/WEBP'), 'Upper WebP is refused.');
        Assert.IsTrue(FileHandling.IsRefusedImageMime('image/webp; charset=binary'), 'Parameterised WebP is refused.');
        Assert.IsTrue(FileHandling.IsRefusedImageMime(' Image/JPG '), 'image/jpg is still refused.');
        Assert.IsFalse(FileHandling.IsInlineImageMime(' Image/JPG '), 'image/jpg is not treated as JPEG.');
        Assert.IsFalse(FileHandling.IsRefusedImageMime(' Application/PDF; charset=binary '), 'A parameterised PDF is not an image refusal.');
    end;

    [Test]
    procedure Scenario_AC02_xAI_PaddedJpeg_SendsDataUri()
    begin
        // Story #96, AC02 | Time: none | Risk: None
        Initialize();
        AssertSentMime("Bifrost LangModel Prov. ori"::xAI, ' image/JPEG ', 'data:image/jpeg;base64,/9j/4AAQ=', '/9j/4AAQ=', false);
    end;

    [Test]
    procedure Scenario_AC02_OpenAI_UpperPng_SendsDataUri()
    begin
        // Story #96, AC02 | Time: none | Risk: None
        Initialize();
        AssertSentMime("Bifrost LangModel Prov. ori"::OpenAI, 'IMAGE/PNG', 'data:image/png;base64,iVBORw0KGgo=', 'iVBORw0KGgo=', false);
    end;

    [Test]
    procedure Scenario_AC02_Azure_ParameterisedJpeg_SendsDataUri()
    begin
        // Story #96, AC02 | Time: none | Risk: None
        Initialize();
        AssertSentMime("Bifrost LangModel Prov. ori"::"Azure OpenAI", 'image/jpeg; charset=binary', 'data:image/jpeg;base64,/9j/4AAQ=', '/9j/4AAQ=', false);
    end;

    [Test]
    procedure Scenario_AC02_Custom_PaddedPng_SendsDataUri()
    begin
        // Story #96, AC02 | Time: none | Risk: None
        Initialize();
        AssertSentMime("Bifrost LangModel Prov. ori"::"Custom LLM", ' image/png ', 'data:image/png;base64,iVBORw0KGgo=', 'iVBORw0KGgo=', false);
    end;

    [Test]
    procedure Scenario_AC02_Anthropic_ParameterisedJpeg_SendsMediaType()
    begin
        // Story #96, AC02 | Time: none | Risk: None
        Initialize();
        AssertSentMime("Bifrost LangModel Prov. ori"::Anthropic, 'Image/JPEG; charset=binary', 'image/jpeg', '/9j/4AAQ=', false);
    end;

    [Test]
    procedure Scenario_AC02_Google_UpperPng_SendsMimeType()
    begin
        // Story #96, AC02 | Time: none | Risk: None
        Initialize();
        AssertSentMime("Bifrost LangModel Prov. ori"::Google, ' IMAGE/PNG ', 'image/png', 'iVBORw0KGgo=', false);
    end;

    [Test]
    procedure Scenario_AC02_xAI_ParameterisedPdf_UploadsPdf()
    begin
        // Story #96, AC02 | Time: none | Risk: None
        Initialize();
        AssertSentMime("Bifrost LangModel Prov. ori"::xAI, ' Application/PDF; charset=binary ', 'application/pdf', 'aGVsbG8=', true);
    end;

    [Test]
    procedure Scenario_AC03_SpacedGifAndWebp_RefusedOnEveryProvider()
    begin
        // Story #96, AC03 | Time: none | Risk: None
        // [SCENARIO] GIF and WebP stay refused on every file-accepting provider
        Initialize();
        AssertRefused("Bifrost LangModel Prov. ori"::OpenAI, ' image/GIF ', 'image/gif');
        AssertRefused("Bifrost LangModel Prov. ori"::"Azure OpenAI", 'IMAGE/WEBP; charset=binary', 'image/webp');
        AssertRefused("Bifrost LangModel Prov. ori"::"Custom LLM", ' image/WEBP ', 'image/webp');
        AssertRefused("Bifrost LangModel Prov. ori"::Anthropic, 'Image/Gif; charset=binary', 'image/gif');
        AssertRefused("Bifrost LangModel Prov. ori"::Google, ' IMAGE/GIF ', 'image/gif');
        AssertRefused("Bifrost LangModel Prov. ori"::xAI, 'IMAGE/WEBP', 'image/webp');
    end;

    local procedure Initialize()
    begin
        if IsInitialized then
            exit;
        IsInitialized := true;
    end;

    local procedure AssertSentMime(ProviderType: Enum "Bifrost LangModel Prov. ori"; MimeType: Text; ExpectedFragment: Text; FileData: Text; ExpectUpload: Boolean)
    var
        Model: Record "Bifrost Language Model ori";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        Response: JsonObject;
        RequestBody: Text;
    begin
        // [GIVEN] A file-accepting model and a MIME type that needs normalisation
        CreateModel(Model, ProviderType);
        HttpMock.Configure(200, SuccessBody(ProviderType, true), false, false);
        BindSubscription(HttpMock);

        // [WHEN] LLM.Prompt.Complete sends the file
        Response := Execute(RequestText(Model.Code, MimeType, FileData));
        UnbindSubscription(HttpMock);

        // [THEN] The provider receives the normalized type and not the raw padding or parameters
        Assert.AreEqual('Success', Response.GetText('status'), 'Normalised file is accepted.');
        RequestBody := HttpMock.GetRequestBody();
        Assert.IsFalse(RequestBody.Contains('charset=binary'), 'MIME parameters are not sent.');
        Assert.AreEqual(0, StrPos(RequestBody, MimeType), 'The raw MIME type is not sent.');
        if ExpectUpload then begin
            Assert.AreEqual(ExpectedFragment, HttpMock.GetUploadMime(), 'The upload uses the normalized MIME type.');
            Assert.AreEqual(1, HttpMock.GetUploadCount(), 'The document is uploaded once.');
            Assert.IsTrue(RequestBody.Contains('file_llm65'), 'The prompt references the uploaded file.');
            Assert.IsFalse(RequestBody.Contains(FileData), 'Document bytes stay out of the prompt.');
        end else begin
            Assert.IsTrue(RequestBody.Contains(ExpectedFragment), 'The normalized MIME type is sent.');
            if ProviderType = "Bifrost LangModel Prov. ori"::Anthropic then
                Assert.IsTrue(RequestBody.Contains('media_type'), 'Anthropic sends media_type.');
            if ProviderType = "Bifrost LangModel Prov. ori"::Google then
                Assert.IsTrue(RequestBody.Contains('mime_type'), 'Google sends mime_type.');
            Assert.AreEqual(0, HttpMock.GetUploadCount(), 'An inline image is not uploaded.');
        end;
        Model.Delete(true);
    end;

    local procedure AssertRefused(ProviderType: Enum "Bifrost LangModel Prov. ori"; MimeType: Text; ExpectedReceived: Text)
    var
        Model: Record "Bifrost Language Model ori";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        Response: JsonObject;
    begin
        // [GIVEN] A file-accepting model and a GIF or WebP type with odd case or spacing
        CreateModel(Model, ProviderType);
        HttpMock.Configure(200, SuccessBody(ProviderType, true), false, false);
        BindSubscription(HttpMock);

        // [WHEN] LLM.Prompt.Complete is called
        Response := Execute(RequestText(Model.Code, MimeType, 'R0lG'));
        UnbindSubscription(HttpMock);

        // [THEN] The call is refused before HTTP and the received type is normalized
        Assert.AreEqual(0, HttpMock.GetCallCount(), 'No prompt is sent.');
        Assert.AreEqual(0, HttpMock.GetUploadCount(), 'No upload is sent.');
        Assert.AreEqual('Error', Response.GetText('status'), 'Refusal status.');
        Assert.AreEqual('InvalidParameter', Response.GetText('code'), 'Refusal code.');
        Assert.AreEqual('mimeType', Response.GetText('parameter'), 'The refusal names mimeType.');
        Assert.AreEqual(ExpectedReceived, Response.GetText('received'), 'The refused type is normalized.');
        Model.Delete(true);
    end;

    local procedure CreateModel(var Model: Record "Bifrost Language Model ori"; ProviderType: Enum "Bifrost LangModel Prov. ori")
    var
        Secrets: Codeunit "LangModel Secrets ori";
        KeyValue: SecretText;
    begin
        Model.Init();
        Model.Code := CopyStr('XLM96' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, MaxStrLen(Model.Code));
        Model.Validate("Chat Provider", ProviderType);
        Model.Model := 'test-model';
        Model."Base URL" := 'https://xlm96.invalid';
        Model.Insert(true);
        KeyValue := Format(FakeKeyTok);
        Secrets.SetUserKey(Model.Code, KeyValue);
    end;

    local procedure RequestText(ModelCode: Code[20]; MimeType: Text; FileData: Text) Result: Text
    var
        RequestJson: JsonObject;
        FileJson: JsonObject;
    begin
        RequestJson.Add('prompt', 'Hello from issue 96');
        RequestJson.Add('roleCode', ModelCode);
        FileJson.Add('fileName', 'issue96.bin');
        FileJson.Add('mimeType', MimeType);
        FileJson.Add('data', FileData);
        RequestJson.Add('file', FileJson);
        RequestJson.WriteTo(Result);
    end;

    local procedure SuccessBody(ProviderType: Enum "Bifrost LangModel Prov. ori"; WithFile: Boolean): Text
    begin
        if ProviderType = "Bifrost LangModel Prov. ori"::Anthropic then
            exit('{"content":[{"type":"text","text":"A safe answer"}]}');
        if WithFile then
            case ProviderType of
                "Bifrost LangModel Prov. ori"::Google:
                    exit('{"candidates":[{"content":{"parts":[{"text":"A safe answer"}]}}]}');
                "Bifrost LangModel Prov. ori"::xAI:
                    exit('{"output":[{"type":"message","content":[{"type":"output_text","text":"A safe answer"}]}]}');
            end;
        exit('{"choices":[{"message":{"content":"A safe answer"}}]}');
    end;

    local procedure Execute(RequestBody: Text) ResponseJson: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[100];
        ResponseText: Text;
    begin
        RequestContent.AddText(RequestBody);
        Dispatcher.Execute("Message Type ori"::"LLM.Prompt.Complete", "Message Version ori"::"1.0", '', '', 'text/json', RequestContent, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        Assert.IsTrue(ResponseJson.ReadFrom(ResponseText), 'Response must be JSON.');
    end;
}
