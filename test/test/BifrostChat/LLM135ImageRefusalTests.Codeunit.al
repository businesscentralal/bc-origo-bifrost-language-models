namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue 135: an image sent to a model that cannot read images (a provider 4xx such as KAPPI qwen3:8b
/// "Multimodal data provided, but model does not support multimodal requests.") is a coded InvalidParameter
/// that names the language model and suggests a roleCode that takes images. HTTP mocks only; no credentials.
/// </summary>
codeunit 96077 "LLM 135 Image Refusal Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;
    EventSubscriberInstance = Manual;

    var
        Assert: Codeunit "Library Assert";
        FakeKeyTok: Label 'xlm135-fake-key-Q7W2', Locked = true;
        PngTok: Label 'iVBORw0KGgoA', Locked = true;
        PdfTok: Label 'JVBERi0xLjQK', Locked = true;
        MultimodalBodyTok: Label '{"error":{"message":"{\"error\":{\"code\":400,\"message\":\"Multimodal data provided, but model does not support multimodal requests.\",\"type\":\"invalid_request_error\"}}","type":"invalid_request_error","param":null,"code":null}}', Locked = true;
        OpenAIImageBodyTok: Label '{"error":{"message":"Invalid content type. image_url is only supported by certain models.","type":"invalid_request_error","param":"messages.[0].content.[1].type","code":null}}', Locked = true;
        InvalidImageBodyTok: Label '{"error":{"message":"The image is not valid.","type":"invalid_request_error","param":null,"code":null}}', Locked = true;
        ImageFormatBodyTok: Label '{"error":{"message":"Unsupported image format.","type":"invalid_request_error","param":null,"code":null}}', Locked = true;
        ChatBody: Text;
        UnrelatedBodyTok: Label '{"error":{"message":"max_completion_tokens is too large for this model.","type":"invalid_request_error","param":null,"code":null}}', Locked = true;

    [Test]
    procedure Scenario_AC1_Complete_NonVisionImage_CodedRefusal_1033()
    begin
        // Story #135, AC1 | Time: none | Risk: None
        VerifyCompleteRefusal(1033, MultimodalBodyTok);
    end;

    [Test]
    procedure Scenario_AC1_Complete_NonVisionImage_CodedRefusal_1039()
    begin
        // Story #135, AC1
        VerifyCompleteRefusal(1039, MultimodalBodyTok);
    end;

    [Test]
    procedure Scenario_AC1_Complete_OpenAIImageUrlNotSupported_CodedRefusal()
    begin
        // Story #135, AC1: the OpenAI-style wording of the same refusal maps too
        VerifyCompleteRefusal(1033, OpenAIImageBodyTok);
    end;

    [Test]
    procedure Scenario_AC1_Ask_NonVisionImage_CodedRefusal_1033()
    begin
        // Story #135, AC1: LLM.Prompt.Ask uses the same mapping
        VerifyAskRefusal(1033);
    end;

    [Test]
    procedure Scenario_AC1_Ask_NonVisionImage_CodedRefusal_1039()
    begin
        // Story #135, AC1
        VerifyAskRefusal(1039);
    end;

    [Test]
    procedure Scenario_AC1_NoOtherImageModel_NamesProviders()
    var
        Model: Record "Bifrost Language Model ori";
        AllModels: Record "Bifrost Language Model ori";
        Response: JsonObject;
    begin
        // Story #135, AC1 edge: with no other language model that takes images, the next step names the providers
        AllModels.SetFilter("Chat Provider", '<>%1', AllModels."Chat Provider"::"Custom LLM");
        AllModels.DeleteAll(false);
        CreateModel(Model, "Bifrost LangModel Prov. ori"::"Custom LLM", 'qwen3:8b');
        Response := RunComplete(Model.Code, PngTok, 'image/png', 400, MultimodalBodyTok, 1033);
        Assert.AreEqual('InvalidParameter', Response.GetText('code'), Describe(Response));
        Assert.IsTrue(Response.GetText('nextStep').Contains('OpenAI, Azure OpenAI, Anthropic, Google or xAI'), Describe(Response));
        Model.Delete(true);
    end;

    [Test]
    procedure Scenario_AC1_Pdf_SameProviderText_StaysProviderError()
    var
        Model: Record "Bifrost Language Model ori";
        Response: JsonObject;
    begin
        // Story #135, AC1 invalid input: without an image the provider failure is unchanged
        CreateModel(Model, "Bifrost LangModel Prov. ori"::"Custom LLM", 'qwen3:8b');
        Response := RunComplete(Model.Code, PdfTok, 'application/pdf', 400, MultimodalBodyTok, 1033);
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), Describe(Response));
        Assert.AreEqual('provider', Response.GetText('parameter'), Describe(Response));
        Assert.IsTrue(Response.GetText('error').Contains('multimodal'), 'The redacted reason now keeps the diagnostic words: ' + Describe(Response));
        Model.Delete(true);
    end;

    [Test]
    procedure Scenario_AC1_Image_UnrelatedRefusal_StaysProviderError()
    var
        Model: Record "Bifrost Language Model ori";
        Response: JsonObject;
    begin
        // Story #135, AC1 invalid input: another 400 with an image is not mapped
        CreateModel(Model, "Bifrost LangModel Prov. ori"::"Custom LLM", 'qwen3:8b');
        Response := RunComplete(Model.Code, PngTok, 'image/png', 400, UnrelatedBodyTok, 1033);
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), Describe(Response));
        Assert.AreEqual('provider', Response.GetText('parameter'), Describe(Response));
        Model.Delete(true);
    end;

    [Test]
    procedure Scenario_AC1_Image_AuthFailure_StaysAuthError()
    var
        Model: Record "Bifrost Language Model ori";
        Response: JsonObject;
    begin
        // Story #135, AC1 edge: 401 is never read as an image refusal, even with the same body
        CreateModel(Model, "Bifrost LangModel Prov. ori"::"Custom LLM", 'qwen3:8b');
        Response := RunComplete(Model.Code, PngTok, 'image/png', 401, MultimodalBodyTok, 1033);
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), Describe(Response));
        Assert.AreNotEqual('roleCode', Response.GetText('parameter'), Describe(Response));
        Model.Delete(true);
    end;

    [Test]
    procedure Scenario_AC1_Detection_Units()
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        Files: JsonArray;
        FileJson: JsonObject;
    begin
        // Story #135, AC1: detection reads only status and redacted words
        Assert.IsTrue(ProviderBase.IsImageNotSupportedFailure(Failure(400, 'This model does not support vision input.')), 'vision');
        Assert.IsTrue(ProviderBase.IsImageNotSupportedFailure(Failure(422, 'Image input is unsupported for this model.')), 'unsupported image');
        Assert.IsFalse(ProviderBase.IsImageNotSupportedFailure(Failure(429, 'This model does not support vision input.')), 'rate limit');
        Assert.IsFalse(ProviderBase.IsImageNotSupportedFailure(Failure(500, 'This model does not support vision input.')), 'server error');
        Assert.IsFalse(ProviderBase.IsImageNotSupportedFailure(Failure(400, 'The image is too large.')), 'image without a negation');
        Assert.IsFalse(ProviderBase.IsImageNotSupportedFailure(Failure(400, 'The model does not exist.')), 'negation without image');
        Assert.IsFalse(ProviderBase.IsImageNotSupportedFailure(Failure(400, 'The image is not valid.')), 'invalid image data');
        Assert.IsFalse(ProviderBase.IsImageNotSupportedFailure(Failure(400, 'Unsupported image format.')), 'unsupported image format');
        Assert.IsFalse(ProviderBase.IsImageNotSupportedFailure(Failure(400, 'Image is not supported in this request.')), 'image refusal that does not name the model');
        Assert.IsTrue(ProviderBase.IsImageNotSupportedFailure(Failure(400, 'This model does not support image input.')), 'model image refusal');
        Assert.IsFalse(ProviderBase.IsImageNotSupportedFailure(ProviderBase.BuildUnsupportedImageRefusal('image/gif')), 'local image refusal keeps its own answer');
        Assert.IsFalse(ProviderBase.HasImageFile(Files), 'no files');
        FileJson.Add('mimeType', ' IMAGE/PNG ');
        Files.Add(FileJson);
        Assert.IsTrue(ProviderBase.HasImageFile(Files), 'normalised image mimeType');
    end;

    [Test]
    procedure Scenario_AC2_Help_DocumentsImageSupport_1033_1039()
    begin
        // Story #135, AC2: the contract of both message types says how image support is determined, in both languages
        VerifyHelp(1033, 'cannot read images', 'Image support is not stored on the language model card');
        VerifyHelp(1039, 'getur ekki lesið myndir', 'Myndstuðningur er ekki skráður á spjaldi mállíkansins');
    end;

    [Test]
    procedure Scenario_AC1_Complete_InvalidOrUnsupportedImage_StaysProviderError()
    var
        Model: Record "Bifrost Language Model ori";
        Response: JsonObject;
    begin
        // Story #135, AC1 invalid input (review AMEND 1): a refusal of the image itself is not model incapability
        CreateModel(Model, "Bifrost LangModel Prov. ori"::"Custom LLM", 'vision-model');
        Response := RunComplete(Model.Code, PngTok, 'image/png', 400, InvalidImageBodyTok, 1033);
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), Describe(Response));
        Assert.AreEqual('provider', Response.GetText('parameter'), Describe(Response));
        Response := RunComplete(Model.Code, PngTok, 'image/png', 400, ImageFormatBodyTok, 1039);
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), Describe(Response));
        Assert.AreEqual('provider', Response.GetText('parameter'), Describe(Response));
        Model.Delete(true);
    end;

    [Test]
    procedure Scenario_AC1_Ask_InvalidOrUnsupportedImage_StaysProviderError()
    begin
        // Story #135, AC1 invalid input (review AMEND 1): the Ask path does not map an image-data refusal either
        VerifyAskNotMapped(InvalidImageBodyTok, 1033);
        VerifyAskNotMapped(ImageFormatBodyTok, 1039);
    end;

    local procedure VerifyAskNotMapped(Body: Text; LanguageId: Integer)
    var
        Model: Record "Bifrost Language Model ori";
        ChatMock: Codeunit "LLM 135 Image Refusal Tests";
        Data: JsonObject;
        Response: JsonObject;
    begin
        CreateModel(Model, "Bifrost LangModel Prov. ori"::"Custom LLM", 'vision-model');
        Data.Add('roleCode', Model.Code);
        Data.Add('question', 'What is in the picture?');
        Data.Add('file', FileObject(PngTok, 'image/png'));
        Commit();
        ChatMock.SetChatBody(Body);
        BindSubscription(ChatMock);
        Response := Dispatch("Message Type ori"::"LLM.Prompt.Ask", Data, LanguageId);
        UnbindSubscription(ChatMock);
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), Describe(Response));
        Assert.IsFalse(Response.Contains('parameter'), 'The generic Ask provider failure is unchanged: ' + Describe(Response));
        Model.Delete(true);
    end;

    /// <summary>Sets the body the manual chat subscriber answers with; the default is the KAPPI multimodal refusal.</summary>
    procedure SetChatBody(NewBody: Text)
    begin
        ChatBody := NewBody;
    end;

    local procedure VerifyCompleteRefusal(LanguageId: Integer; ProviderBody: Text)
    var
        Model: Record "Bifrost Language Model ori";
        VisionModel: Record "Bifrost Language Model ori";
        Response: JsonObject;
    begin
        CreateModel(Model, "Bifrost LangModel Prov. ori"::"Custom LLM", 'qwen3:8b');
        CreateModel(VisionModel, "Bifrost LangModel Prov. ori"::Anthropic, 'vision-model');
        Response := RunComplete(Model.Code, PngTok, 'image/png', 400, ProviderBody, LanguageId);
        AssertRefusal(Response, Model, VisionModel, LanguageId);
        VisionModel.Delete(true);
        Model.Delete(true);
    end;

    local procedure VerifyAskRefusal(LanguageId: Integer)
    var
        Model: Record "Bifrost Language Model ori";
        VisionModel: Record "Bifrost Language Model ori";
        ChatMock: Codeunit "LLM 135 Image Refusal Tests";
        Data: JsonObject;
        Response: JsonObject;
    begin
        CreateModel(Model, "Bifrost LangModel Prov. ori"::"Custom LLM", 'qwen3:8b');
        CreateModel(VisionModel, "Bifrost LangModel Prov. ori"::OpenAI, 'vision-model');
        Data.Add('roleCode', Model.Code);
        Data.Add('question', 'What is in the picture?');
        Data.Add('file', FileObject(PngTok, 'image/png'));
        Commit();
        BindSubscription(ChatMock);
        Response := Dispatch("Message Type ori"::"LLM.Prompt.Ask", Data, LanguageId);
        UnbindSubscription(ChatMock);
        AssertRefusal(Response, Model, VisionModel, LanguageId);
        VisionModel.Delete(true);
        Model.Delete(true);
    end;

    local procedure AssertRefusal(Response: JsonObject; Model: Record "Bifrost Language Model ori"; VisionModel: Record "Bifrost Language Model ori"; LanguageId: Integer)
    var
        ResponseText: Text;
    begin
        ResponseText := Describe(Response);
        Assert.AreEqual('Error', Response.GetText('status'), ResponseText);
        Assert.AreEqual('InvalidParameter', Response.GetText('code'), ResponseText);
        Assert.AreEqual('roleCode', Response.GetText('parameter'), ResponseText);
        Assert.AreEqual(Model.Code, Response.GetText('received'), ResponseText);
        Assert.IsTrue(Response.GetText('error').Contains(Model.Code), 'The error names the language model: ' + ResponseText);
        Assert.IsTrue(Response.GetText('error').Contains('qwen3:8b'), 'The error names the model: ' + ResponseText);
        Assert.IsTrue(Response.GetText('nextStep').Contains(VisionModel.Code), 'The next step suggests a roleCode that takes images: ' + ResponseText);
        Assert.IsFalse(Response.GetText('nextStep').Contains(Model.Code), 'The refused model is not suggested: ' + ResponseText);
        if LanguageId = 1039 then begin
            Assert.IsTrue(Response.GetText('error').Contains('getur ekki lesið myndir'), 'Icelandic error: ' + ResponseText);
            Assert.IsTrue(Response.GetText('nextStep').Contains('Sendu roleCode'), 'Icelandic next step: ' + ResponseText);
        end else begin
            Assert.IsTrue(Response.GetText('error').Contains('cannot read images'), 'English error: ' + ResponseText);
            Assert.IsTrue(Response.GetText('nextStep').Contains('Send roleCode'), 'English next step: ' + ResponseText);
        end;
        Assert.AreEqual(0, StrPos(ResponseText, FakeKeyTok), 'The secret is never returned.');
        Assert.AreEqual(0, StrPos(ResponseText, 'Base URL'), 'Not the model-setup hint.');
    end;

    local procedure VerifyHelp(LanguageId: Integer; ExpectedError: Text; ExpectedWhen: Text)
    var
        ComplImpl: Codeunit "LLM Prompt Compl Impl ori";
        AskImpl: Codeunit "LLM Prompt Ask Impl ori";
        Errors: JsonArray;
        ErrorsText: Text;
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        ComplImpl.GetErrors(Errors);
        Errors.WriteTo(ErrorsText);
        Assert.IsTrue(ErrorsText.Contains(ExpectedError), 'LLM.Prompt.Complete documents the image refusal: ' + ErrorsText);
        Assert.IsTrue(ErrorsText.Contains(ExpectedWhen), 'LLM.Prompt.Complete says how image support is determined.');
        Clear(Errors);
        AskImpl.GetErrors(Errors);
        Errors.WriteTo(ErrorsText);
        GlobalLanguage(PreviousLanguage);
        Assert.IsTrue(ErrorsText.Contains(ExpectedError), 'LLM.Prompt.Ask documents the image refusal.');
        Assert.IsTrue(ErrorsText.Contains(ExpectedWhen), 'LLM.Prompt.Ask says how image support is determined.');
    end;

    local procedure Failure(HttpStatus: Integer; Reason: Text): JsonObject
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
    begin
        exit(ProviderBase.BuildPromptError(HttpStatus, false, 'invalid_request_error', Reason));
    end;

    local procedure RunComplete(ModelCode: Code[20]; Data: Text; MimeType: Text; HttpStatus: Integer; ProviderBody: Text; LanguageId: Integer) Response: JsonObject
    var
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        RequestJson: JsonObject;
    begin
        RequestJson.Add('prompt', 'What is in the picture?');
        RequestJson.Add('roleCode', ModelCode);
        RequestJson.Add('file', FileObject(Data, MimeType));
        HttpMock.Configure(HttpStatus, ProviderBody, false, false);
        BindSubscription(HttpMock);
        Response := Dispatch("Message Type ori"::"LLM.Prompt.Complete", RequestJson, LanguageId);
        UnbindSubscription(HttpMock);
        Assert.IsTrue(HttpMock.GetCallCount() > 0, 'The provider is called: the refusal comes from the provider answer.');
    end;

    local procedure CreateModel(var Model: Record "Bifrost Language Model ori"; ProviderType: Enum "Bifrost LangModel Prov. ori"; ModelName: Text[100])
    var
        Secrets: Codeunit "LangModel Secrets ori";
        KeyValue: SecretText;
    begin
        Model.Init();
        Model.Code := CopyStr('X135' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, MaxStrLen(Model.Code));
        Model.Validate("Chat Provider", ProviderType);
        Model.Model := ModelName;
        Model."Base URL" := 'https://xlm135.invalid';
        Model.Insert(true);
        KeyValue := Format(FakeKeyTok);
        Secrets.SetUserKey(Model.Code, KeyValue);
    end;

    local procedure FileObject(Data: Text; MimeType: Text) FileJson: JsonObject
    begin
        FileJson.Add('fileName', 'issue135.bin');
        FileJson.Add('mimeType', MimeType);
        FileJson.Add('data', Data);
    end;

    local procedure Dispatch(MessageType: Enum "Message Type ori"; Data: JsonObject; LanguageId: Integer) ResponseJson: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        EmptyTaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
        ResponseContentType: Text[100];
        RequestText: Text;
        ResponseText: Text;
    begin
        Data.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.EnqueueAndProcess(MessageType, "Message Version ori"::"1.0", '', '', 'text/json', RequestContent, EmptyTaskId, LanguageId, MessageId, ResponseContent, ResponseContentType, ResponseTime);
        ResponseContent.GetSubText(ResponseText, 1);
        Assert.IsTrue(ResponseJson.ReadFrom(ResponseText), 'Response must be JSON.');
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LangModel API Client ori", 'OnBeforeChatPostWithStatus', '', false, false)]
    local procedure AnswerChatWithMultimodalRefusal(Url: Text; RequestBody: JsonObject; var Handled: Boolean; var HttpStatus: Integer; var ResponseText: Text)
    begin
        Handled := true;
        HttpStatus := 400;
        ResponseText := ChatBody;
        if ResponseText = '' then
            ResponseText := MultimodalBodyTok;
    end;

    local procedure Describe(Response: JsonObject) Result: Text
    begin
        Response.WriteTo(Result);
    end;
}
