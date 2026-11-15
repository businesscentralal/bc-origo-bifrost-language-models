namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;
using System.Utilities;

/// <summary>Issue 125 request-shape, error-redaction and cleanup regressions through the real xAI provider.</summary>
codeunit 96072 "LLM 125 xAI Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        FakeKeyTok: Label 'xai125-fixture-Z9Q7', Locked = true;
        DocumentTok: Label '<html><body>OK</body></html>', Locked = true;

    /// <summary>HTML alone changes prompt instructions, not the provider response format.</summary>
    [Test]
    procedure Scenario_AC02_AC04_AskHtml_ReturnsDocument()
    begin
        VerifySuccess(true, true, false);
    end;

    /// <summary>Ask documents use uploaded file ids on Responses.</summary>
    [Test]
    procedure Scenario_AC02_AC04_AskFile_UploadsAndDeletes()
    begin
        VerifySuccess(true, false, true);
    end;

    /// <summary>HTML and a staged file work together through Ask.</summary>
    [Test]
    procedure Scenario_AC02_AC04_AskHtmlFile_ReturnsDocument()
    begin
        VerifySuccess(true, true, true);
    end;

    /// <summary>Plain-text Ask keeps Chat Completions.</summary>
    [Test]
    procedure Scenario_AC02_AskText_KeepsChatCompletions()
    begin
        VerifySuccess(true, false, false);
    end;

    /// <summary>Complete has no outputFormat parameter; HTML is requested in its system prompt.</summary>
    [Test]
    procedure Scenario_AC02_AC04_CompleteHtml_PreservesReply()
    begin
        VerifySuccess(false, true, false);
    end;

    /// <summary>Complete documents preserve the upload and cleanup policy.</summary>
    [Test]
    procedure Scenario_AC02_AC04_CompleteFile_UploadsAndDeletes()
    begin
        VerifySuccess(false, false, true);
    end;

    /// <summary>Complete can return HTML with a staged document.</summary>
    [Test]
    procedure Scenario_AC02_AC04_CompleteHtmlFile_PreservesReply()
    begin
        VerifySuccess(false, true, true);
    end;

    /// <summary>A configured base URL ending in v1 is joined only once.</summary>
    [Test]
    procedure Scenario_AC02_CompleteText_JoinsBaseUrlOnce()
    begin
        VerifySuccess(false, false, false);
    end;

    /// <summary>Both real message types expose a useful redacted 4xx reason in both locales.</summary>
    [Test]
    procedure Scenario_AC03_InvalidField_ReturnsRedactedReason()
    var
        IsAsk: Boolean;
        Locale: Integer;
        Result: JsonObject;
        Response: JsonObject;
        Body: Text;
        Index: Integer;
    begin
        // Story #125 AC03 | Time: no clock-dependent assertions | Risk: shared provider failures.
        for Index := 0 to 3 do begin
            IsAsk := Index < 2;
            Locale := 1033;
            if (Index mod 2) = 1 then
                Locale := 1039;
            Result := RunScenario(IsAsk, true, true, Locale, 400,
                '{"error":{"code":"invalid_request","message":"Unsupported field file_data. Use file_id instead. xai125-fixture-Z9Q7 Z9Q7 private-customer@example.invalid"}}');
            Response := Result.GetObject('response');
            Assert.AreEqual('Error', Response.GetText('status'), 'Failure status.');
            Assert.AreEqual('PreconditionFailed', Response.GetText('code'), 'Coded provider refusal.');
            Response.WriteTo(Body);
            Assert.IsTrue(Body.Contains('unsupported field file_data'), 'Retains diagnostic reason.');
            Assert.IsTrue(Body.Contains('file_id instead'), 'Retains actionable field name.');
            Assert.IsTrue(Body.Contains('400 invalid_request'), 'Retains status and safe code.');
            if Locale = 1039 then
                Assert.IsTrue(Response.GetText('error').Contains('Ástæða veitanda'), 'The outer error follows Icelandic LCID.')
            else
                Assert.IsTrue(Response.GetText('error').Contains('Provider reason'), 'The outer error follows English LCID.');
            Assert.IsFalse(Body.Contains('Z9Q7'), 'No credential fragments.');
            Assert.IsFalse(Body.Contains('private-customer'), 'No customer text.');
            Assert.IsTrue(Result.GetBoolean('cleanedUp'), 'Own fixtures removed.');
            Assert.AreEqual(1, Result.GetInteger('deletes'), 'Uploaded file removed on 4xx.');
        end;
    end;

    /// <summary>Authentication diagnostics remain private even when they look like field errors.</summary>
    [Test]
    procedure Scenario_AC03_Authentication_DoesNotReflectReason()
    var
        Result: JsonObject;
        Body: Text;
    begin
        // Story #125 AC03 | Time: none | Risk: authentication diagnostics can include credentials.
        Result := RunScenario(true, false, false, 1033, 401,
            '{"error":{"message":"Invalid file_id xai125-fixture-Z9Q7"}}');
        Result.GetObject('response').WriteTo(Body);
        Assert.IsFalse(Body.Contains('file_id'), 'Authentication body discarded entirely.');
        Assert.IsFalse(Body.Contains('Z9Q7'), 'No credential suffix.');
    end;

    /// <summary>Unknown provider prose and non-JSON errors fail closed.</summary>
    [Test]
    procedure Scenario_AC03_UnknownReason_DiscardsPrivateText()
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
    begin
        // Story #125 AC03 | Time: none | Risk: unknown response formats.
        Assert.AreEqual('', ProviderBase.ReadProviderReason('private-customer'), 'Non-JSON discarded.');
        Assert.AreEqual('', ProviderBase.ReadProviderReason('{"error":{"message":"private-customer Z9Q7"}}'), 'No useful diagnostic: discard.');
        Assert.AreEqual('', ProviderBase.ReadProviderReason('{"error":{"message":null}}'), 'Null is harmless.');
        Assert.AreEqual('', ProviderBase.RedactProviderReason(PadStr('invalid ', 8193, 'a')), 'Oversize reason discarded.');
        Assert.IsTrue(StrLen(ProviderBase.RedactProviderReason(PadStr('invalid ', 8192, 'a'))) <= 300, 'Output bounded.');
    end;

    /// <summary>A malformed diagnostic from an extension provider retains the coded generic failure.</summary>
    [Test]
    procedure Scenario_AC03_MalformedReason_ReturnsCodedFailure()
    var
        TempArgument: Record "Message Argument ori" temporary;
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        Failure: JsonObject;
        Response: JsonObject;
        InvalidReason: JsonArray;
    begin
        // Story #125 AC03 | Time: none | Risk: extensible provider response metadata.
        TempArgument.Init();
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        Failure := ProviderBase.BuildPromptError(400, false);
        Failure.Add('providerReason', InvalidReason);
        ProviderBase.RespondPromptError(TempArgument, Failure);
        Response.ReadFrom(TempArgument.GetResponseText());
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), 'Malformed diagnostic does not raise an exception.');
        Assert.AreEqual('400', Response.GetText('received'), 'Status remains available.');
    end;

    /// <summary>Every continuation reuploads local bytes instead of reusing an already deleted id.</summary>
    [Test]
    procedure Scenario_AC04_Continuation_ReuploadsAndCleansEachRound()
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Mock: Codeunit "LLM 65 HTTP Mock";
        Provider: Interface "Bifrost LangModel Provider ori";
        Response: JsonObject;
        State: Text;
    begin
        // Story #125 AC04 | Time: none | Risk: premature deletion across tool rounds.
        TempArgument."Base URL" := 'https://xai125.invalid/v1';
        TempArgument.Model := 'fixture-model';
        TempArgument.SetApiKey(FakeKey());
        TempArgument.SetPayload('{"messages":[{"role":"user","content":"Read this"}],"files":[{"fileName":"fixture.pdf","mimeType":"application/pdf","data":"JVBERi0xLjQgaGVsbG8="}],"allowedTools":["who_am_i"]}');
        TempArgument."Procedure Type" := TempArgument."Procedure Type"::SendChatMessage;
        Provider := Enum::"Bifrost LangModel Prov. ori"::xAI;
        Mock.Configure(200, '{"status":"completed","output":[{"type":"function_call","call_id":"call125","name":"who_am_i","arguments":"{}"}]}', false, false);
        BindSubscription(Mock);
        Provider.Execute(TempArgument);
        UnbindSubscription(Mock);
        Response.ReadFrom(TempArgument.GetResultText());
        Assert.AreEqual('tool_calls', Response.GetText('type'), 'The real xAI builder returns a continuation.');
        State := Response.GetText('conversationState');
        Assert.IsFalse(State.Contains('file_llm65'), 'Deleted ids never enter the next round.');
        Assert.IsTrue(State.Contains('JVBERi0xLjQgaGVsbG8='), 'Owned input bytes remain available locally.');
        Assert.AreEqual(1, Mock.GetDeleteCount(), 'First round cleaned up.');
        TempArgument.SetConversationState(State);
        TempArgument.SetToolResults('[{"id":"call125","result":"fixture identity"}]');
        TempArgument."Procedure Type" := TempArgument."Procedure Type"::ContinueWithToolResults;
        Mock.Configure(200, ProviderReply(false, true), false, false);
        Mock.ConfigureUpload(200, '{"id":"file_round_two"}');
        BindSubscription(Mock);
        Provider.Execute(TempArgument);
        UnbindSubscription(Mock);
        Response.ReadFrom(TempArgument.GetResultText());
        Assert.AreEqual('OK', Response.GetText('reply'), 'Continuation succeeds.');
        Assert.IsTrue(Mock.GetRequestBody().Contains('file_round_two'), 'A fresh uploaded id is sent.');
        Assert.IsFalse(Mock.GetRequestBody().Contains('file_data'), 'No inline document reaches xAI.');
        Assert.IsTrue(Mock.GetRequestBody().Contains('function_call_output'), 'Tool result reaches xAI.');
        Assert.AreEqual('upload;prompt;delete;', Mock.GetOperationSequence(), 'Second round cleaned up.');
    end;

    /// <summary>An unsupported image is refused without any provider request.</summary>
    [Test]
    procedure Scenario_AC04_UnsupportedImage_RefusesBeforeHttp()
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Mock: Codeunit "LLM 65 HTTP Mock";
        Provider: Interface "Bifrost LangModel Provider ori";
        Response: JsonObject;
    begin
        // Story #125 AC04 | Time: none | Risk: bypassing shared file policy in Ask.
        TempArgument."Base URL" := 'https://xai125.invalid';
        TempArgument.SetApiKey(FakeKey());
        TempArgument.SetPayload('{"messages":[{"role":"user","content":"Read this"}],"files":[{"fileName":"fixture.gif","mimeType":"IMAGE/GIF","data":"aGVsbG8="}]}');
        TempArgument."Procedure Type" := TempArgument."Procedure Type"::SendChatMessage;
        Provider := Enum::"Bifrost LangModel Prov. ori"::xAI;
        Mock.Configure(200, ProviderReply(false, true), false, false);
        BindSubscription(Mock);
        Provider.Execute(TempArgument);
        UnbindSubscription(Mock);
        Response.ReadFrom(TempArgument.GetResultText());
        Assert.AreEqual('unsupportedImage', Response.GetText('refusalKind'), 'Shared image policy.');
        Assert.AreEqual(0, Mock.GetCallCount(), 'No prompt request.');
        Assert.AreEqual(0, Mock.GetUploadCount(), 'No file upload.');
    end;

    /// <summary>A transport exception still deletes a document uploaded for the round.</summary>
    [Test]
    procedure Scenario_AC04_TransportFailure_DeletesUploadedFile()
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Mock: Codeunit "LLM 65 HTTP Mock";
        Provider: Interface "Bifrost LangModel Provider ori";
        Response: JsonObject;
    begin
        // Story #125 AC04 | Time: none | Risk: cleanup after caught exceptions.
        TempArgument."Base URL" := 'https://xai125.invalid';
        TempArgument.Model := 'fixture-model';
        TempArgument.SetApiKey(FakeKey());
        TempArgument.SetPayload('{"messages":[{"role":"user","content":"Read this"}],"files":[{"fileName":"fixture.pdf","mimeType":"application/pdf","data":"JVBERi0xLjQgaGVsbG8="}]}');
        TempArgument."Procedure Type" := TempArgument."Procedure Type"::SendChatMessage;
        Provider := Enum::"Bifrost LangModel Prov. ori"::xAI;
        Mock.Configure(0, '', false, true);
        BindSubscription(Mock);
        Provider.Execute(TempArgument);
        UnbindSubscription(Mock);
        Response.ReadFrom(TempArgument.GetResultText());
        Assert.AreEqual(0, Response.GetInteger('providerStatus'), 'Safe transport failure.');
        Assert.IsFalse(TempArgument.GetResultText().Contains('Z9Q7'), 'Exception text discarded.');
        Assert.AreEqual('upload;prompt;delete;', Mock.GetOperationSequence(), 'Cleanup runs after exception.');
    end;

    /// <summary>The accepted image path stays inline and MIME types are normalized.</summary>
    [Test]
    procedure Scenario_AC04_PaddedPng_StaysInline()
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Mock: Codeunit "LLM 65 HTTP Mock";
        Provider: Interface "Bifrost LangModel Provider ori";
        Response: JsonObject;
    begin
        // Story #125 AC04 | Time: none | Risk: shared MIME normalization.
        TempArgument."Base URL" := 'https://xai125.invalid';
        TempArgument.Model := 'fixture-model';
        TempArgument.SetApiKey(FakeKey());
        TempArgument.SetPayload('{"messages":[{"role":"user","content":"Read this"}],"files":[{"fileName":"fixture.png","mimeType":" Image/PNG; charset=binary ","data":"iVBORw0KGgo="}]}');
        TempArgument."Procedure Type" := TempArgument."Procedure Type"::SendChatMessage;
        Provider := Enum::"Bifrost LangModel Prov. ori"::xAI;
        Mock.Configure(200, ProviderReply(false, true), false, false);
        BindSubscription(Mock);
        Provider.Execute(TempArgument);
        UnbindSubscription(Mock);
        Response.ReadFrom(TempArgument.GetResultText());
        Assert.AreEqual('OK', Response.GetText('reply'), 'Accepted PNG.');
        Assert.IsTrue(Mock.GetRequestBody().Contains('data:image/png;base64,iVBORw0KGgo='), 'Normalized inline image.');
        Assert.AreEqual(0, Mock.GetUploadCount(), 'Images are never uploaded.');
    end;

    local procedure FakeKey() Result: SecretText
    begin
        Result := Format(FakeKeyTok);
    end;

    /// <summary>A text attachment is sent inline as input_text on Responses: no provider file upload, in both message types and both locales.</summary>
    [Test]
    procedure Scenario_AC02_TextAttachment_SentInlineWithoutUpload()
    var
        Result: JsonObject;
        Response: JsonObject;
        Body: Text;
        Index: Integer;
        IsAsk: Boolean;
        Locale: Integer;
    begin
        // Story #125 AC02 | Time: none | Risk: xAI Files API refusing text uploads.
        for Index := 0 to 3 do begin
            IsAsk := Index < 2;
            Locale := 1033;
            if (Index mod 2) = 1 then
                Locale := 1039;
            Result := RunFileScenario(IsAsk, true, true, Locale, 200, ProviderReply(true, true), 'fixture.txt', 'text/plain', 'hello inline note');
            Response := Result.GetObject('response');
            Response.WriteTo(Body);
            Assert.AreEqual('Success', Response.GetText('status'), Body);
            Body := Result.GetText('request');
            Assert.IsTrue(Result.GetText('url').EndsWith('/v1/responses'), 'Files use Responses.');
            Assert.IsTrue(Body.Contains('input_text'), 'Text is an input_text block.');
            Assert.IsTrue(Body.Contains('hello inline note'), 'Decoded text is sent.');
            Assert.IsTrue(Body.Contains('fixture.txt'), 'File name labels the text.');
            Assert.IsFalse(Body.Contains('input_file'), 'No file reference.');
            Assert.IsFalse(Body.Contains('file_data'), 'No inline document.');
            Assert.AreEqual(0, Result.GetInteger('uploads'), 'No provider upload.');
            Assert.AreEqual(0, Result.GetInteger('deletes'), 'Nothing to clean up.');
            Assert.IsTrue(Result.GetBoolean('cleanedUp'), 'Owned fixtures removed.');
        end;
    end;

    /// <summary>A failed document upload says it came from the file upload and keeps the redacted reason.</summary>
    [Test]
    procedure Scenario_AC03_UploadRefusal_NamesUploadStage()
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Mock: Codeunit "LLM 65 HTTP Mock";
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        Provider: Interface "Bifrost LangModel Provider ori";
        Response: JsonObject;
    begin
        // Story #125 AC03 | Time: none | Risk: generic failure hides which hop was rejected.
        TempArgument."Base URL" := 'https://xai125.invalid/v1';
        TempArgument.Model := 'fixture-model';
        TempArgument.SetApiKey(FakeKey());
        TempArgument.SetPayload('{"messages":[{"role":"user","content":"Read this"}],"files":[{"fileName":"fixture.pdf","mimeType":"application/pdf","data":"JVBERi0xLjQgaGVsbG8="}]}');
        TempArgument."Procedure Type" := TempArgument."Procedure Type"::SendChatMessage;
        Provider := Enum::"Bifrost LangModel Prov. ori"::xAI;
        Mock.Configure(200, ProviderReply(false, true), false, false);
        Mock.ConfigureUpload(400, '{"error":{"code":"invalid_request","message":"Unsupported purpose value. xai125-fixture-Z9Q7"}}');
        BindSubscription(Mock);
        Provider.Execute(TempArgument);
        UnbindSubscription(Mock);
        Response.ReadFrom(TempArgument.GetResultText());
        Assert.AreEqual('upload', Response.GetText('providerStage'), 'Failure is marked as the upload hop.');
        Assert.AreEqual(400, Response.GetInteger('providerStatus'), 'Status kept.');
        Assert.IsTrue(Response.GetText('providerReason').Contains('unsupported purpose'), 'Redacted reason kept.');
        Assert.IsFalse(TempArgument.GetResultText().Contains('Z9Q7'), 'No credential fragments.');
        Assert.AreEqual(0, Mock.GetCallCount(), 'No prompt request after a refused upload.');
        Assert.IsTrue(ProviderBase.RedactProviderReason('Unsupported purpose value') <> '', 'Vocabulary covers purpose.');
    end;

    /// <summary>A staged text attachment, alone and with html, succeeds when the Responses body carries "error": null as xAI and OpenAI return on success (#125 AC05 b/c).</summary>
    [Test]
    procedure Scenario_AC02_StagedTextNullError_AskSucceeds()
    var
        Result: JsonObject;
        Response: JsonObject;
        Body: Text;
        Expected: Text;
        Index: Integer;
        HtmlMode: Boolean;
        Locale: Integer;
    begin
        // Story #125 AC02/AC04 | Time: none | Risk: a successful Responses body read as a failure because error is present but null.
        for Index := 0 to 3 do begin
            HtmlMode := Index >= 2;
            Locale := 1033;
            if (Index mod 2) = 1 then
                Locale := 1039;
            Result := RunFileScenario(true, HtmlMode, true, Locale, 200, NullErrorReply(HtmlMode), 'note.txt', 'text/plain', 'staged inline note');
            Response := Result.GetObject('response');
            Response.WriteTo(Body);
            Assert.AreEqual('Success', Response.GetText('status'), Body);
            Expected := 'OK';
            if HtmlMode then begin
                Expected := DocumentTok;
                Assert.AreEqual(DocumentTok, Response.GetText('html'), 'HTML document.');
            end;
            Assert.AreEqual(Expected, Response.GetText('answer'), 'Ask answer.');
            Assert.AreEqual('completed', Response.GetText('stopReason'), 'Completed.');
            Body := Result.GetText('request');
            Assert.IsTrue(Result.GetText('url').EndsWith('/v1/responses'), 'Files use Responses.');
            Assert.IsTrue(Body.Contains('input_text'), 'Text is an input_text block.');
            Assert.IsTrue(Body.Contains('staged inline note'), 'Decoded text is sent.');
            Assert.IsFalse(Body.Contains('file_data'), 'No inline document.');
            Assert.AreEqual(0, Result.GetInteger('uploads'), 'No provider upload.');
            Assert.IsTrue(Result.GetBoolean('cleanedUp'), 'Owned fixtures removed.');
        end;
    end;

    /// <summary>Complete with a staged text attachment also reads "error": null as success.</summary>
    [Test]
    procedure Scenario_AC02_StagedTextNullError_CompleteSucceeds()
    var
        Result: JsonObject;
        Response: JsonObject;
        Body: Text;
    begin
        // Story #125 AC02/AC04 | Time: none | Risk: the Complete Responses path shares the null-error check.
        Result := RunFileScenario(false, false, true, 1033, 200, NullErrorReply(false), 'note.txt', 'text/plain', 'staged inline note');
        Response := Result.GetObject('response');
        Response.WriteTo(Body);
        Assert.AreEqual('Success', Response.GetText('status'), Body);
        Assert.AreEqual('OK', Response.GetText('reply'), 'Complete reply.');
        Assert.AreEqual(0, Result.GetInteger('uploads'), 'No provider upload.');
        Assert.IsTrue(Result.GetBoolean('cleanedUp'), 'Owned fixtures removed.');
    end;

    /// <summary>A refused Responses request names the responses hop with the provider status, safe code and redacted reason, in both locales.</summary>
    [Test]
    procedure Scenario_AC03_ResponsesRefusal_NamesResponsesStage()
    var
        Result: JsonObject;
        Response: JsonObject;
        Body: Text;
        Index: Integer;
        Locale: Integer;
    begin
        // Story #125 AC03 | Time: none | Risk: the caller cannot tell the upload hop from the responses hop.
        for Index := 0 to 1 do begin
            Locale := 1033;
            if Index = 1 then
                Locale := 1039;
            Result := RunFileScenario(true, false, true, Locale, 400,
                '{"error":{"code":"invalid_request","message":"Unsupported field input_text. xai125-fixture-Z9Q7"}}', 'note.txt', 'text/plain', 'staged inline note');
            Response := Result.GetObject('response');
            Response.WriteTo(Body);
            Assert.AreEqual('PreconditionFailed', Response.GetText('code'), Body);
            Assert.AreEqual('provider', Response.GetText('parameter'), 'Provider parameter.');
            if Locale = 1039 then
                Assert.AreEqual('svarbeiðni 400 invalid_request', Response.GetText('received'), 'Icelandic hop, status and code.')
            else
                Assert.AreEqual('responses request 400 invalid_request', Response.GetText('received'), 'Hop, status and code.');
            Assert.IsTrue(Body.Contains('unsupported field input_text'), 'Redacted reason kept.');
            Assert.IsFalse(Body.Contains('Z9Q7'), 'No credential fragments.');
            Assert.AreEqual(0, Result.GetInteger('uploads'), 'Text was not uploaded.');
            Assert.IsTrue(Result.GetBoolean('cleanedUp'), 'Owned fixtures removed.');
        end;
    end;

    /// <summary>A 2xx body with a real (non-null) error object still fails, and the status is visible.</summary>
    [Test]
    procedure Scenario_AC03_InBodyError_FailsWithStatus()
    var
        Result: JsonObject;
        Response: JsonObject;
        Body: Text;
    begin
        // Story #125 AC03 | Time: none | Risk: the null-error fix must not accept a real in-body error.
        Result := RunFileScenario(true, false, true, 1033, 200,
            '{"status":"failed","error":{"code":"server_error","message":"private-customer Z9Q7"},"output":[]}', 'note.txt', 'text/plain', 'staged inline note');
        Response := Result.GetObject('response');
        Response.WriteTo(Body);
        Assert.AreEqual('Error', Response.GetText('status'), Body);
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), 'Coded refusal.');
        Assert.AreEqual('responses request 200 server_error', Response.GetText('received'), 'Hop, status and safe code.');
        Assert.IsFalse(Body.Contains('private-customer'), 'No provider prose.');
        Assert.IsFalse(Body.Contains('Z9Q7'), 'No credential fragments.');
        Assert.IsTrue(Result.GetBoolean('cleanedUp'), 'Owned fixtures removed.');
    end;

    /// <summary>The shared null-error rule: absent and null are no error; an object or text is an error. A file upload with "error": null keeps its id.</summary>
    [Test]
    procedure Scenario_AC02_NullErrorRule_SharedHelpers()
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        ApiClient: Codeunit "LangModel API Client ori";
        Mock: Codeunit "LLM 65 HTTP Mock";
        Sample: JsonObject;
        Upload: JsonObject;
    begin
        // Story #125 AC02/AC04 | Time: none | Risk: shared providers misread a null error.
        Sample.ReadFrom('{"status":"completed"}');
        Assert.IsFalse(ProviderBase.HasProviderError(Sample), 'Absent error.');
        Sample.ReadFrom('{"error":null}');
        Assert.IsFalse(ProviderBase.HasProviderError(Sample), 'Null error is success.');
        ProviderBase.RemoveNullError(Sample);
        Assert.IsFalse(Sample.Contains('error'), 'Null error removed.');
        Sample.ReadFrom('{"error":{"message":"x"}}');
        Assert.IsTrue(ProviderBase.HasProviderError(Sample), 'Object error.');
        ProviderBase.RemoveNullError(Sample);
        Assert.IsTrue(Sample.Contains('error'), 'Real error kept.');
        Sample.ReadFrom('{"error":"bad"}');
        Assert.IsTrue(ProviderBase.HasProviderError(Sample), 'Text error.');

        Mock.Configure(200, NullErrorReply(false), false, false);
        Mock.ConfigureUpload(200, '{"id":"file_llm65","object":"file","error":null}');
        BindSubscription(Mock);
        Upload := ApiClient.UploadProviderFile('https://xai125.invalid/v1/files', 'Authorization', FakeKey(), 1000, 'fixture.pdf', 'application/pdf', 'JVBERi0xLjQgaGVsbG8=');
        UnbindSubscription(Mock);
        Assert.IsFalse(Upload.Contains('error'), 'Upload with null error succeeds.');
        Assert.AreEqual('file_llm65', Upload.GetText('id'), 'File id read.');
    end;

    /// <summary>A Responses success body in the real wire shape, including "error": null and "incomplete_details": null.</summary>
    local procedure NullErrorReply(HtmlMode: Boolean): Text
    var
        Reply: Text;
    begin
        Reply := 'OK';
        if HtmlMode then
            Reply := DocumentTok;
        exit('{"id":"resp_lm125","object":"response","status":"completed","error":null,"incomplete_details":null,"output":[{"type":"message","role":"assistant","status":"completed","content":[{"type":"output_text","text":"' + Reply + '","annotations":[]}]}],"usage":{"input_tokens":5,"output_tokens":1,"total_tokens":6}}');
    end;

    local procedure VerifySuccess(IsAsk: Boolean; HtmlMode: Boolean; WithFile: Boolean)
    var
        Result: JsonObject;
        Response: JsonObject;
        Locale: Integer;
        Index: Integer;
        Expected: Text;
        Body: Text;
    begin
        // Story #125 AC02/AC04 | Time: SESSION TIME presence only | Risk: provider shape differs by API.
        for Index := 1 to 2 do begin
            Locale := 1033;
            if Index = 2 then
                Locale := 1039;
            Result := RunScenario(IsAsk, HtmlMode, WithFile, Locale, 200, ProviderReply(HtmlMode, WithFile));
            Response := Result.GetObject('response');
            Response.WriteTo(Body);
            Assert.AreEqual('Success', Response.GetText('status'), Body);
            Expected := 'OK';
            if HtmlMode then
                Expected := DocumentTok;
            if IsAsk then begin
                Assert.AreEqual(Expected, Response.GetText('answer'), 'Ask answer.');
                if HtmlMode then
                    Assert.AreEqual(Expected, Response.GetText('html'), 'HTML document.');
            end else
                Assert.AreEqual(Expected, Response.GetText('reply'), 'Complete reply.');
            Body := Result.GetText('request');
            Assert.IsFalse(Body.Contains('response_format'), 'HTML is an instruction, not an unsupported wire format.');
            Assert.IsFalse(Result.GetText('url').Contains('/v1/v1/'), 'Base URL joined once.');
            if WithFile then begin
                Assert.IsTrue(Result.GetText('url').EndsWith('/v1/responses'), 'Files use Responses.');
                Assert.IsTrue(Body.Contains('file_llm65'), 'Uploaded id is sent.');
                Assert.IsFalse(Body.Contains('file_data'), 'No inline document sent.');
                Assert.IsFalse(Body.Contains('JVBERi0xLjQgaGVsbG8='), 'No document bytes in prompt.');
                Assert.AreEqual(1, Result.GetInteger('uploads'), 'One upload.');
                Assert.AreEqual(1, Result.GetInteger('deletes'), 'One cleanup.');
            end else
                Assert.IsTrue(Result.GetText('url').EndsWith('/v1/chat/completions'), 'Text uses Chat Completions.');
            Assert.IsTrue(Result.GetBoolean('cleanedUp'), 'Owned fixture removed.');
        end;
    end;

    /// <summary>Runs an owned mock-only fixture through the actual message dispatcher; also used by the MCP probe.</summary>
    procedure RunScenario(IsAsk: Boolean; HtmlMode: Boolean; WithFile: Boolean; Locale: Integer; HttpStatus: Integer; ProviderBody: Text) Result: JsonObject
    begin
        Result := RunFileScenario(IsAsk, HtmlMode, WithFile, Locale, HttpStatus, ProviderBody, 'fixture.pdf', 'application/pdf', '%PDF-1.4 hello');
    end;

    /// <summary>Same as RunScenario with the staged file name, MIME type and content chosen by the caller.</summary>
    procedure RunFileScenario(IsAsk: Boolean; HtmlMode: Boolean; WithFile: Boolean; Locale: Integer; HttpStatus: Integer; ProviderBody: Text; FileName: Text; FileMime: Text; FileContent: Text) Result: JsonObject
    var
        Model: Record "Bifrost Language Model ori";
        Secrets: Codeunit "LangModel Secrets ori";
        Staging: Codeunit "Blob Staging ori";
        Blob: Codeunit "Temp Blob";
        Mock: Codeunit "LLM 65 HTTP Mock";
        Request: JsonObject;
        Attachment: JsonObject;
        Attachments: JsonArray;
        Response: JsonObject;
        MessageType: Enum "Message Type ori";
        StagingId: Guid;
        MessageId: Guid;
        Output: OutStream;
        Input: InStream;
        KeyValue: SecretText;
    begin
        Model.Code := CopyStr('X125-' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(Model.Code));
        Model.Validate("Chat Provider", Enum::"Bifrost LangModel Prov. ori"::xAI);
        Model.Model := 'fixture-model';
        Model."Base URL" := 'https://xai125.invalid/v1';
        Model.Insert(true);
        KeyValue := FakeKey();
        Secrets.SetUserKey(Model.Code, KeyValue);
        Request.Add('roleCode', Model.Code);
        MessageType := Enum::"Message Type ori"::"LLM.Prompt.Complete";
        if IsAsk then begin
            MessageType := Enum::"Message Type ori"::"LLM.Prompt.Ask";
            Request.Add('question', 'Return OK');
            if HtmlMode then
                Request.Add('outputFormat', 'html');
        end else begin
            Request.Add('prompt', 'Return OK');
            if HtmlMode then
                Request.Add('system', 'Return one complete HTML document.');
        end;
        if WithFile then begin
            Blob.CreateOutStream(Output, TextEncoding::UTF8);
            Output.WriteText(FileContent);
            Blob.CreateInStream(Input);
            StagingId := Staging.Create(Input, FileName, FileMime, 'LM125 owned fixture');
            Attachment.Add('stagingId', Format(StagingId, 0, 4));
            Attachments.Add(Attachment);
            Request.Add('attachments', Attachments);
        end;
        Mock.Configure(HttpStatus, ProviderBody, false, false);
        BindSubscription(Mock);
        Dispatch(MessageType, Request, Locale, Response, MessageId);
        UnbindSubscription(Mock);
        Model.Delete(true);
        if WithFile then
            if Staging.Exists(StagingId) then
                Staging.Take(StagingId, Blob);
        Result.Add('response', Response);
        Result.Add('messageId', Format(MessageId, 0, 4));
        Result.Add('request', Mock.GetRequestBody());
        Result.Add('url', Mock.GetRequestUrl());
        Result.Add('uploads', Mock.GetUploadCount());
        Result.Add('deletes', Mock.GetDeleteCount());
        Result.Add('calls', Mock.GetCallCount());
        Result.Add('cleanedUp', not Model.Get(Model.Code) and not Staging.Exists(StagingId));
    end;

    local procedure Dispatch(MessageType: Enum "Message Type ori"; Request: JsonObject; Locale: Integer; var Response: JsonObject; var MessageId: Guid)
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
        Dispatcher.EnqueueAndProcess(MessageType, Enum::"Message Version ori"::"1.0", '', '', 'text/json', RequestContent, EmptyTaskId, Locale, MessageId, ResponseContent, ResponseContentType, ResponseTime);
        ResponseContent.GetSubText(ResponseText, 1);
        Assert.IsTrue(Response.ReadFrom(ResponseText), 'Dispatcher response JSON.');
    end;

    /// <summary>Creates a synthetic response in the actual provider wire format.</summary>
    procedure ProviderReply(HtmlMode: Boolean; WithFile: Boolean): Text
    var
        Reply: Text;
    begin
        Reply := 'OK';
        if HtmlMode then
            Reply := DocumentTok;
        if WithFile then
            exit('{"status":"completed","output":[{"type":"message","content":[{"type":"output_text","text":"' + Reply + '"}]}]}');
        exit('{"choices":[{"finish_reason":"stop","message":{"role":"assistant","content":"' + Reply + '"}}]}');
    end;
}
