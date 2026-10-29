namespace Origo.Bifrost.LanguageModels.Test;

using Microsoft.EServices.EDocument;
using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>Issue 65 prompt dispatch regressions across six providers, failure classes, inputs and attachments.</summary>
codeunit 96034 "LLM 65 Prompt Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        FakeKeyTok: Label 'llm65-fake-key-Z9Q7', Locked = true;

    /// <summary>OpenAI: Auth401 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC1_AC4_OpenAI_Auth401()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::OpenAI, 401, false, false, 'PreconditionFailed', false);
    end;

    /// <summary>OpenAI: Auth403 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC1_AC4_OpenAI_Auth403()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::OpenAI, 403, false, false, 'PreconditionFailed', false);
    end;

    /// <summary>OpenAI: Rate429 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_OpenAI_Rate429()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::OpenAI, 429, false, false, 'Retryable', false);
    end;

    /// <summary>OpenAI: Server500 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_OpenAI_Server500()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::OpenAI, 500, false, false, 'Retryable', false);
    end;

    /// <summary>OpenAI: Server503 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_OpenAI_Server503()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::OpenAI, 503, false, false, 'Retryable', false);
    end;

    /// <summary>OpenAI: Timeout yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_OpenAI_Timeout()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::OpenAI, 0, false, false, 'Retryable', false);
    end;

    /// <summary>OpenAI: TransportThrows yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_OpenAI_TransportThrows()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::OpenAI, 0, false, true, 'Retryable', false);
    end;

    /// <summary>OpenAI: Blocked yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC3_AC4_OpenAI_Blocked()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::OpenAI, 0, true, false, 'PreconditionFailed', false);
    end;

    /// <summary>OpenAI: InvalidBody yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_OpenAI_InvalidBody()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::OpenAI, 200, false, false, 'PreconditionFailed', false);
    end;

    /// <summary>OpenAI: Plain preserves reply/text and the outgoing prompt payload.</summary>
    [Test]
    procedure AC6_OpenAI_Plain()
    begin
        VerifySuccess("Bifrost LangModel Prov. ori"::OpenAI, false, false);
    end;

    /// <summary>OpenAI: System preserves reply/text and the outgoing prompt payload.</summary>
    [Test]
    procedure AC6_OpenAI_System()
    begin
        VerifySuccess("Bifrost LangModel Prov. ori"::OpenAI, true, false);
    end;

    /// <summary>OpenAI: File preserves reply/text and the outgoing prompt payload.</summary>
    [Test]
    procedure AC6_OpenAI_File()
    begin
        VerifySuccess("Bifrost LangModel Prov. ori"::OpenAI, true, true);
    end;

    /// <summary>Azure: Auth401 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC1_AC4_Azure_Auth401()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::"Azure OpenAI", 401, false, false, 'PreconditionFailed', false);
    end;

    /// <summary>Azure: Auth403 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC1_AC4_Azure_Auth403()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::"Azure OpenAI", 403, false, false, 'PreconditionFailed', false);
    end;

    /// <summary>Azure: Rate429 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_Azure_Rate429()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::"Azure OpenAI", 429, false, false, 'Retryable', false);
    end;

    /// <summary>Azure: Server500 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_Azure_Server500()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::"Azure OpenAI", 500, false, false, 'Retryable', false);
    end;

    /// <summary>Azure: Server503 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_Azure_Server503()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::"Azure OpenAI", 503, false, false, 'Retryable', false);
    end;

    /// <summary>Azure: Timeout yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_Azure_Timeout()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::"Azure OpenAI", 0, false, false, 'Retryable', false);
    end;

    /// <summary>Azure: TransportThrows yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_Azure_TransportThrows()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::"Azure OpenAI", 0, false, true, 'Retryable', false);
    end;

    /// <summary>Azure: Blocked yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC3_AC4_Azure_Blocked()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::"Azure OpenAI", 0, true, false, 'PreconditionFailed', false);
    end;

    /// <summary>Azure: InvalidBody yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_Azure_InvalidBody()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::"Azure OpenAI", 200, false, false, 'PreconditionFailed', false);
    end;

    /// <summary>Azure: Plain preserves reply/text and the outgoing prompt payload.</summary>
    [Test]
    procedure AC6_Azure_Plain()
    begin
        VerifySuccess("Bifrost LangModel Prov. ori"::"Azure OpenAI", false, false);
    end;

    /// <summary>Azure: System preserves reply/text and the outgoing prompt payload.</summary>
    [Test]
    procedure AC6_Azure_System()
    begin
        VerifySuccess("Bifrost LangModel Prov. ori"::"Azure OpenAI", true, false);
    end;

    /// <summary>Azure: File preserves reply/text and the outgoing prompt payload.</summary>
    [Test]
    procedure AC6_Azure_File()
    begin
        VerifySuccess("Bifrost LangModel Prov. ori"::"Azure OpenAI", true, true);
    end;

    /// <summary>Custom: Auth401 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC1_AC4_Custom_Auth401()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::"Custom LLM", 401, false, false, 'PreconditionFailed', false);
    end;

    /// <summary>Custom: Auth403 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC1_AC4_Custom_Auth403()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::"Custom LLM", 403, false, false, 'PreconditionFailed', false);
    end;

    /// <summary>Custom: Rate429 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_Custom_Rate429()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::"Custom LLM", 429, false, false, 'Retryable', false);
    end;

    /// <summary>Custom: Server500 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_Custom_Server500()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::"Custom LLM", 500, false, false, 'Retryable', false);
    end;

    /// <summary>Custom: Server503 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_Custom_Server503()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::"Custom LLM", 503, false, false, 'Retryable', false);
    end;

    /// <summary>Custom: Timeout yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_Custom_Timeout()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::"Custom LLM", 0, false, false, 'Retryable', false);
    end;

    /// <summary>Custom: TransportThrows yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_Custom_TransportThrows()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::"Custom LLM", 0, false, true, 'Retryable', false);
    end;

    /// <summary>Custom: Blocked yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC3_AC4_Custom_Blocked()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::"Custom LLM", 0, true, false, 'PreconditionFailed', false);
    end;

    /// <summary>Custom: InvalidBody yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_Custom_InvalidBody()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::"Custom LLM", 200, false, false, 'PreconditionFailed', false);
    end;

    /// <summary>Custom: Plain preserves reply/text and the outgoing prompt payload.</summary>
    [Test]
    procedure AC6_Custom_Plain()
    begin
        VerifySuccess("Bifrost LangModel Prov. ori"::"Custom LLM", false, false);
    end;

    /// <summary>Custom: System preserves reply/text and the outgoing prompt payload.</summary>
    [Test]
    procedure AC6_Custom_System()
    begin
        VerifySuccess("Bifrost LangModel Prov. ori"::"Custom LLM", true, false);
    end;

    /// <summary>Custom: File preserves reply/text and the outgoing prompt payload.</summary>
    [Test]
    procedure AC6_Custom_File()
    begin
        VerifySuccess("Bifrost LangModel Prov. ori"::"Custom LLM", true, true);
    end;

    /// <summary>Anthropic: Auth401 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC1_AC4_Anthropic_Auth401()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::Anthropic, 401, false, false, 'PreconditionFailed', false);
    end;

    /// <summary>Anthropic: Auth403 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC1_AC4_Anthropic_Auth403()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::Anthropic, 403, false, false, 'PreconditionFailed', false);
    end;

    /// <summary>Anthropic: Rate429 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_Anthropic_Rate429()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::Anthropic, 429, false, false, 'Retryable', false);
    end;

    /// <summary>Anthropic: Server500 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_Anthropic_Server500()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::Anthropic, 500, false, false, 'Retryable', false);
    end;

    /// <summary>Anthropic: Server503 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_Anthropic_Server503()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::Anthropic, 503, false, false, 'Retryable', false);
    end;

    /// <summary>Anthropic: Timeout yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_Anthropic_Timeout()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::Anthropic, 0, false, false, 'Retryable', false);
    end;

    /// <summary>Anthropic: TransportThrows yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_Anthropic_TransportThrows()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::Anthropic, 0, false, true, 'Retryable', false);
    end;

    /// <summary>Anthropic: Blocked yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC3_AC4_Anthropic_Blocked()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::Anthropic, 0, true, false, 'PreconditionFailed', false);
    end;

    /// <summary>Anthropic: InvalidBody yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_Anthropic_InvalidBody()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::Anthropic, 200, false, false, 'PreconditionFailed', false);
    end;

    /// <summary>Anthropic: Plain preserves reply/text and the outgoing prompt payload.</summary>
    [Test]
    procedure AC6_Anthropic_Plain()
    begin
        VerifySuccess("Bifrost LangModel Prov. ori"::Anthropic, false, false);
    end;

    /// <summary>Anthropic: System preserves reply/text and the outgoing prompt payload.</summary>
    [Test]
    procedure AC6_Anthropic_System()
    begin
        VerifySuccess("Bifrost LangModel Prov. ori"::Anthropic, true, false);
    end;

    /// <summary>Anthropic: File preserves reply/text and the outgoing prompt payload.</summary>
    [Test]
    procedure AC6_Anthropic_File()
    begin
        VerifySuccess("Bifrost LangModel Prov. ori"::Anthropic, true, true);
    end;

    /// <summary>Gemini: Auth401 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC1_AC4_Gemini_Auth401()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::Google, 401, false, false, 'PreconditionFailed', false);
    end;

    /// <summary>Gemini: Auth403 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC1_AC4_Gemini_Auth403()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::Google, 403, false, false, 'PreconditionFailed', false);
    end;

    /// <summary>Gemini: Rate429 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_Gemini_Rate429()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::Google, 429, false, false, 'Retryable', false);
    end;

    /// <summary>Gemini: Server500 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_Gemini_Server500()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::Google, 500, false, false, 'Retryable', false);
    end;

    /// <summary>Gemini: Server503 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_Gemini_Server503()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::Google, 503, false, false, 'Retryable', false);
    end;

    /// <summary>Gemini: Timeout yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_Gemini_Timeout()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::Google, 0, false, false, 'Retryable', false);
    end;

    /// <summary>Gemini: TransportThrows yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_Gemini_TransportThrows()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::Google, 0, false, true, 'Retryable', false);
    end;

    /// <summary>Gemini: Blocked yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC3_AC4_Gemini_Blocked()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::Google, 0, true, false, 'PreconditionFailed', false);
    end;

    /// <summary>Gemini: InvalidBody yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_Gemini_InvalidBody()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::Google, 200, false, false, 'PreconditionFailed', false);
    end;

    /// <summary>Gemini: Plain preserves reply/text and the outgoing prompt payload.</summary>
    [Test]
    procedure AC6_Gemini_Plain()
    begin
        VerifySuccess("Bifrost LangModel Prov. ori"::Google, false, false);
    end;

    /// <summary>Gemini: System preserves reply/text and the outgoing prompt payload.</summary>
    [Test]
    procedure AC6_Gemini_System()
    begin
        VerifySuccess("Bifrost LangModel Prov. ori"::Google, true, false);
    end;

    /// <summary>Gemini: File preserves reply/text and the outgoing prompt payload.</summary>
    [Test]
    procedure AC6_Gemini_File()
    begin
        VerifySuccess("Bifrost LangModel Prov. ori"::Google, true, true);
    end;

    /// <summary>xAI: Auth401 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC1_AC4_xAI_Auth401()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::xAI, 401, false, false, 'PreconditionFailed', false);
    end;

    /// <summary>xAI: Auth403 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC1_AC4_xAI_Auth403()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::xAI, 403, false, false, 'PreconditionFailed', false);
    end;

    /// <summary>xAI: Rate429 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_xAI_Rate429()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::xAI, 429, false, false, 'Retryable', false);
    end;

    /// <summary>xAI: Server500 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_xAI_Server500()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::xAI, 500, false, false, 'Retryable', false);
    end;

    /// <summary>xAI: Server503 yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_xAI_Server503()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::xAI, 503, false, false, 'Retryable', false);
    end;

    /// <summary>xAI: Timeout yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_xAI_Timeout()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::xAI, 0, false, false, 'Retryable', false);
    end;

    /// <summary>xAI: TransportThrows yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_xAI_TransportThrows()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::xAI, 0, false, true, 'Retryable', false);
    end;

    /// <summary>xAI: Blocked yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC3_AC4_xAI_Blocked()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::xAI, 0, true, false, 'PreconditionFailed', false);
    end;

    /// <summary>xAI: InvalidBody yields a safe coded response through the public dispatcher.</summary>
    [Test]
    procedure AC2_AC4_xAI_InvalidBody()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::xAI, 200, false, false, 'PreconditionFailed', false);
    end;

    /// <summary>xAI: Plain preserves reply/text and the outgoing prompt payload.</summary>
    [Test]
    procedure AC6_xAI_Plain()
    begin
        VerifySuccess("Bifrost LangModel Prov. ori"::xAI, false, false);
    end;

    /// <summary>xAI: System preserves reply/text and the outgoing prompt payload.</summary>
    [Test]
    procedure AC6_xAI_System()
    begin
        VerifySuccess("Bifrost LangModel Prov. ori"::xAI, true, false);
    end;

    /// <summary>xAI: File preserves reply/text and the outgoing prompt payload.</summary>
    [Test]
    procedure AC6_xAI_File()
    begin
        VerifySuccess("Bifrost LangModel Prov. ori"::xAI, true, true);
    end;

    /// <summary>The Gemini attachment transport maps a rate limit without reflecting the error body.</summary>
    [Test]
    procedure AC2_AC4_Gemini_File429()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::Google, 429, false, false, 'Retryable', true);
    end;

    /// <summary>The xAI attachment transport maps a rate limit without reflecting the error body.</summary>
    [Test]
    procedure AC2_AC4_xAI_File429()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::xAI, 429, false, false, 'Retryable', true);
    end;

    /// <summary>The Anthropic attachment transport maps a rate limit without reflecting the error body.</summary>
    [Test]
    procedure AC2_AC4_Anthropic_File429()
    begin
        VerifyFailure("Bifrost LangModel Prov. ori"::Anthropic, 429, false, false, 'Retryable', true);
    end;

    /// <summary>xAI inline PNG uses input_image, disables store, and does not upload.</summary>
    [Test]
    procedure AC01_xAI_Png_InlineImageDisablesStore()
    begin
        VerifyInlineImage('image/png', 'iVBORw0KGgo=', 'data:image/png;base64,iVBORw0KGgo=');
    end;

    /// <summary>xAI inline JPEG uses the same image path as PNG.</summary>
    [Test]
    procedure AC01_xAI_Jpeg_InlineImageDisablesStore()
    begin
        VerifyInlineImage('image/jpeg', '/9j/4AAQ=', 'data:image/jpeg;base64,/9j/4AAQ=');
    end;

    /// <summary>xAI deletes an uploaded PDF even when the prompt returns a provider error.</summary>
    [Test]
    procedure AC02_xAI_Pdf_DeletesWhenPromptFails()
    var
        Model: Record "Bifrost Language Model ori";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        Response: JsonObject;
    begin
        CreateModel(Model, "Bifrost LangModel Prov. ori"::xAI);
        HttpMock.Configure(400, '{"error":{"code":"invalid_request_error","message":"Invalid key Z9Q7"}}', false, false);
        BindSubscription(HttpMock);
        Response := Execute(Request(Model.Code, false, true));
        UnbindSubscription(HttpMock);
        Assert.AreEqual(1, HttpMock.GetCallCount(), 'The prompt was still sent.');
        Assert.AreEqual(1, HttpMock.GetUploadCount(), 'The PDF was uploaded.');
        Assert.AreEqual(1, HttpMock.GetDeleteCount(), 'The uploaded PDF is deleted when the prompt fails.');
        Assert.AreEqual('upload;prompt;delete;', HttpMock.GetOperationSequence(), 'Delete follows the failed prompt.');
        Assert.IsTrue(HttpMock.GetDeleteUrl().EndsWith('/v1/files/file_llm65'), 'Delete targets the uploaded id.');
        AssertCodedError(Response, 'PreconditionFailed');
        Assert.AreEqual('provider', Response.GetText('parameter'), 'The provider parameter names the transport.');
        Assert.AreEqual('400 invalid_request_error', Response.GetText('received'), 'The safe code follows the HTTP status.');
        Assert.IsTrue(Response.GetText('error').Contains('could not complete the prompt'), 'The public error stays generic.');
        AssertSecretAbsent(Response);
        Model.Delete(true);
    end;

    /// <summary>A failed xAI file delete does not hide a successful reply.</summary>
    [Test]
    procedure AC02_xAI_Pdf_DeleteFailureKeepsReply()
    var
        Model: Record "Bifrost Language Model ori";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        Response: JsonObject;
    begin
        CreateModel(Model, "Bifrost LangModel Prov. ori"::xAI);
        HttpMock.Configure(200, SuccessBody("Bifrost LangModel Prov. ori"::xAI, true), false, false);
        HttpMock.ConfigureDelete(500, '{"error":{"message":"cleanup failed Z9Q7"}}');
        BindSubscription(HttpMock);
        Response := Execute(Request(Model.Code, false, true));
        UnbindSubscription(HttpMock);
        Assert.AreEqual('Success', Response.GetText('status'), 'Delete failure stays internal.');
        Assert.AreEqual('A safe answer', Response.GetText('reply'), 'The reply is unchanged.');
        Assert.AreEqual(1, HttpMock.GetDeleteCount(), 'Delete was still attempted.');
        AssertSecretAbsent(Response);
        Model.Delete(true);
    end;

    /// <summary>An xAI upload failure is returned and does not send the prompt.</summary>
    [Test]
    procedure AC02_xAI_Pdf_UploadFailureSkipsPrompt()
    var
        Model: Record "Bifrost Language Model ori";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        Response: JsonObject;
    begin
        CreateModel(Model, "Bifrost LangModel Prov. ori"::xAI);
        HttpMock.Configure(200, SuccessBody("Bifrost LangModel Prov. ori"::xAI, true), false, false);
        HttpMock.ConfigureUpload(400, '{"error":{"code":"invalid_request_error","message":"bad file Z9Q7"}}');
        BindSubscription(HttpMock);
        Response := Execute(Request(Model.Code, false, true));
        UnbindSubscription(HttpMock);
        Assert.AreEqual(0, HttpMock.GetCallCount(), 'No prompt follows a failed upload.');
        Assert.AreEqual(1, HttpMock.GetUploadCount(), 'The upload was attempted.');
        Assert.AreEqual(0, HttpMock.GetDeleteCount(), 'Nothing was uploaded to delete.');
        Assert.AreEqual('upload;', HttpMock.GetOperationSequence(), 'Only the upload ran.');
        AssertCodedError(Response, 'PreconditionFailed');
        Assert.AreEqual('400 invalid_request_error', Response.GetText('received'), 'The upload status and code are returned.');
        AssertSecretAbsent(Response);
        Model.Delete(true);
    end;

    /// <summary>A stored PNG follows the same inline xAI image path.</summary>
    [Test]
    procedure AC03_xAI_StoredPng_UsesImagePath()
    var
        Attachment: Record "Incoming Document Attachment";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        Response: JsonObject;
    begin
        Response := ExecuteStored('png', 930001, HttpMock, Attachment, true);
        Assert.AreEqual('Success', Response.GetText('status'), 'Stored PNG completion');
        Assert.IsTrue(HttpMock.GetRequestBody().Contains('input_image'), 'Stored PNG is an image.');
        Assert.IsTrue(HttpMock.GetRequestBody().Contains('data:image/png;base64,aGVsbG8='), 'Stored PNG bytes are inline.');
        Assert.AreEqual(0, HttpMock.GetUploadCount(), 'PNG is not uploaded.');
        Assert.AreEqual(0, HttpMock.GetDeleteCount(), 'PNG has nothing to delete.');
        Assert.IsTrue(HttpMock.GetRequestUrl().EndsWith('/responses'), 'Stored PNG uses the Responses API.');
        Attachment.Delete(false);
    end;

    /// <summary>A stored PDF is uploaded and deleted, same as an inline PDF.</summary>
    [Test]
    procedure AC03_xAI_StoredPdf_Uploads()
    var
        Attachment: Record "Incoming Document Attachment";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        Response: JsonObject;
    begin
        Response := ExecuteStored('pdf', 930002, HttpMock, Attachment, true);
        Assert.AreEqual('Success', Response.GetText('status'), 'Stored PDF completion');
        Assert.IsFalse(HttpMock.GetRequestBody().Contains('aGVsbG8='), 'Stored PDF bytes stay out of the prompt.');
        Assert.IsTrue(HttpMock.GetRequestBody().Contains('file_llm65'), 'The prompt references the uploaded id.');
        Assert.AreEqual('ZZTEST93.pdf', HttpMock.GetUploadFileName(), 'The stored file name is uploaded.');
        Assert.AreEqual('application/pdf', HttpMock.GetUploadMime(), 'The stored MIME type is uploaded.');
        Assert.IsTrue(HttpMock.GetUploadContent().Contains('aGVsbG8='), 'Stored PDF bytes are uploaded.');
        Assert.AreEqual('upload;prompt;delete;', HttpMock.GetOperationSequence(), 'Stored PDF is deleted afterwards.');
        Attachment.Delete(false);
    end;

    /// <summary>xAI refuses an inline GIF before any HTTP call.</summary>
    [Test]
    procedure AC04_xAI_Gif_RefusesBeforeHttp()
    begin
        VerifyRefusedImage('image/gif', 'image/gif');
    end;

    /// <summary>An explicit image/jpg is not treated as image/jpeg.</summary>
    [Test]
    procedure AC04_xAI_JpgMime_RefusesBeforeHttp()
    begin
        VerifyRefusedImage('image/jpg', 'image/jpg');
    end;

    /// <summary>A stored GIF is refused on the same path, before HTTP.</summary>
    [Test]
    procedure AC04_xAI_StoredGif_RefusesBeforeHttp()
    var
        Attachment: Record "Incoming Document Attachment";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        Response: JsonObject;
    begin
        Response := ExecuteStored('gif', 930003, HttpMock, Attachment, false);
        AssertRefusedImage(Response, HttpMock, 'image/gif');
        Attachment.Delete(false);
    end;

    /// <summary>A GIF beside a PDF refuses the whole call before the PDF is uploaded.</summary>
    [Test]
    procedure AC04_xAI_GifBesidePdf_RefusesBeforeUpload()
    var
        TempArg: Record "Bifrost Chat Argument ori" temporary;
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        Provider: Interface "Bifrost LangModel Provider ori";
        Result: JsonObject;
        KeyValue: SecretText;
    begin
        TempArg.Init();
        TempArg."Base URL" := 'https://llm65.invalid';
        TempArg.Model := 'test-model';
        KeyValue := Format(FakeKeyTok);
        TempArg.SetApiKey(KeyValue);
        TempArg.SetPayload('{"messages":[{"role":"user","content":"Describe both"}],"files":[{"fileName":"a.gif","mimeType":"image/gif","data":"R0lG"},{"fileName":"a.pdf","mimeType":"application/pdf","data":"aGVsbG8="}]}');
        TempArg."Procedure Type" := TempArg."Procedure Type"::CompletePrompt;
        HttpMock.Configure(200, SuccessBody("Bifrost LangModel Prov. ori"::xAI, true), false, false);
        BindSubscription(HttpMock);
        Provider := Enum::"Bifrost LangModel Prov. ori"::xAI;
        Provider.Execute(TempArg);
        UnbindSubscription(HttpMock);
        Assert.IsTrue(Result.ReadFrom(TempArg.GetResultText()), 'The local refusal is JSON.');
        Assert.IsTrue(Result.GetBoolean('safeRefusal'), 'The refusal is marked safe.');
        Assert.AreEqual('image/gif', Result.GetText('received'), 'The GIF mime is the refusal.');
        Assert.AreEqual(0, HttpMock.GetCallCount(), 'No prompt was sent.');
        Assert.AreEqual(0, HttpMock.GetUploadCount(), 'The sibling PDF was not uploaded.');
        Assert.AreEqual(0, HttpMock.GetDeleteCount(), 'Nothing was uploaded to delete.');
        AssertSecretAbsent(Result);
    end;

    /// <summary>A text-only xAI 4xx carries the HTTP status and a sanitised provider code.</summary>
    [Test]
    procedure AC05_xAI_Text400_CarriesSafeCode()
    var
        Model: Record "Bifrost Language Model ori";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        Response: JsonObject;
    begin
        CreateModel(Model, "Bifrost LangModel Prov. ori"::xAI);
        HttpMock.Configure(400, '{"error":{"type":"invalid_request_error","message":"Invalid key Z9Q7"}}', false, false);
        BindSubscription(HttpMock);
        Response := Execute(Request(Model.Code, false, false));
        UnbindSubscription(HttpMock);
        Assert.IsTrue(HttpMock.GetRequestUrl().EndsWith('/v1/chat/completions'), 'Text-only xAI stays on chat completions.');
        Assert.AreEqual(0, HttpMock.GetUploadCount(), 'Text-only xAI does not upload.');
        AssertCodedError(Response, 'PreconditionFailed');
        Assert.AreEqual('400 invalid_request_error', Response.GetText('received'), 'The type is used when no code is present.');
        AssertSecretAbsent(Response);
        Model.Delete(true);
    end;

    /// <summary>A number prompt is refused before provider dispatch.</summary>
    [Test]
    procedure AC5_PromptNumber()
    var
        Response: JsonObject;
    begin
        Response := Execute('{"prompt":123}');
        AssertCodedError(Response, 'InvalidParameterFormat');
        Assert.AreEqual('prompt', Response.GetText('parameter'), 'Invalid input must name prompt.');
    end;

    /// <summary>A object prompt is refused before provider dispatch.</summary>
    [Test]
    procedure AC5_PromptObject()
    var
        Response: JsonObject;
    begin
        Response := Execute('{"prompt":{}}');
        AssertCodedError(Response, 'InvalidParameterFormat');
        Assert.AreEqual('prompt', Response.GetText('parameter'), 'Invalid input must name prompt.');
    end;

    /// <summary>A array prompt is refused before provider dispatch.</summary>
    [Test]
    procedure AC5_PromptArray()
    var
        Response: JsonObject;
    begin
        Response := Execute('{"prompt":[]}');
        AssertCodedError(Response, 'InvalidParameterFormat');
        Assert.AreEqual('prompt', Response.GetText('parameter'), 'Invalid input must name prompt.');
    end;

    /// <summary>A boolean prompt is refused before provider dispatch.</summary>
    [Test]
    procedure AC5_PromptBoolean()
    var
        Response: JsonObject;
    begin
        Response := Execute('{"prompt":true}');
        AssertCodedError(Response, 'InvalidParameterFormat');
        Assert.AreEqual('prompt', Response.GetText('parameter'), 'Invalid input must name prompt.');
    end;

    /// <summary>A null prompt is refused before provider dispatch.</summary>
    [Test]
    procedure AC5_PromptNull()
    var
        Response: JsonObject;
    begin
        Response := Execute('{"prompt":null}');
        AssertCodedError(Response, 'InvalidParameterFormat');
        Assert.AreEqual('prompt', Response.GetText('parameter'), 'Invalid input must name prompt.');
    end;

    /// <summary>A provider error carried in a successful HTTP envelope is not reflected or logged.</summary>
    [Test]
    procedure AC4_SuccessStatusWithErrorBody()
    var
        Model: Record "Bifrost Language Model ori";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        Response: JsonObject;
    begin
        CreateModel(Model, "Bifrost LangModel Prov. ori"::OpenAI);
        HttpMock.Configure(200, '{"error":{"message":"Invalid key ending Z9Q7"}}', false, false);
        BindSubscription(HttpMock);
        Response := Execute(Request(Model.Code, false, false));
        UnbindSubscription(HttpMock);
        AssertCodedError(Response, 'PreconditionFailed');
        AssertSecretAbsent(Response);
        Model.Delete(true);
    end;

    /// <summary>The Foundation API transport baseline grants neither chat capability nor model read and receives PermissionDenied.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure AC7_TransportBaselineDenied()
    var
        Model: Record "Bifrost Language Model ori";
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Response: JsonObject;
    begin
        // BIFROST API is the transport baseline; it grants neither chat gate nor model-table read.
        LowerPermissions.SetO365Basic();
        LowerPermissions.AddPermissionSet('BIFROST API ori');
        Assert.IsFalse(BifrostChatMgt.HasChatPermission(), 'The transport baseline must not grant the Foundation Chat Gate.');
        Assert.IsFalse(Model.ReadPermission(), 'The transport baseline must not grant language model read.');
        Response := Execute('{"prompt":"Hello"}');
        AssertCodedError(Response, 'PermissionDenied');
    end;

    /// <summary>The transport baseline plus Foundation chat still receives PermissionDenied without model read.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure AC7_TransportAndChatDenied()
    var
        Model: Record "Bifrost Language Model ori";
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Response: JsonObject;
    begin
        // BIFROST API is the transport baseline; it grants neither chat gate nor model-table read.
        LowerPermissions.SetO365Basic();
        LowerPermissions.AddPermissionSet('BIFROST API ori');
        LowerPermissions.AddPermissionSet('BIFROST Chat ori');
        Assert.IsTrue(BifrostChatMgt.HasChatPermission(), 'Foundation chat must grant the Chat Gate over the transport baseline.');
        Assert.IsFalse(Model.ReadPermission(), 'The transport baseline plus Foundation chat must not grant language model read.');
        Response := Execute('{"prompt":"Hello"}');
        AssertCodedError(Response, 'PermissionDenied');
    end;

    /// <summary>The transport baseline plus both chat permission sets suffices for a configured prompt.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure AC7_TransportAndChatPairAllow()
    var
        Model: Record "Bifrost Language Model ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        Response: JsonObject;
        RequestText: Text;
    begin
        LowerPermissions.SetOutsideO365Scope();
        CreateModel(Model, "Bifrost LangModel Prov. ori"::OpenAI);
        RequestText := Request(Model.Code, false, false);
        HttpMock.Configure(200, SuccessBody("Bifrost LangModel Prov. ori"::OpenAI, false), false, false);
        BindSubscription(HttpMock);
        // BIFROST API is the transport baseline; it grants neither chat gate nor model-table read.
        LowerPermissions.SetO365Basic();
        LowerPermissions.AddPermissionSet('BIFROST API ori');
        LowerPermissions.AddPermissionSet('BIFROST Chat ori');
        LowerPermissions.AddPermissionSet('BIFROST LLM Chat ori');
        Response := Execute(RequestText);
        Assert.AreEqual('Success', Response.GetText('status'), 'The transport baseline plus both chat sets must permit completion.');
        Assert.AreEqual('A safe answer', Response.GetText('text'), 'Expected completion.');
        UnbindSubscription(HttpMock);
        LowerPermissions.SetOutsideO365Scope();
        Model.Delete(true);
    end;

    /// <summary>The errors chapter documents validation, authentication, retry and blocked HTTP.</summary>
    [Test]
    procedure AC8_ErrorContract()
    var
        Impl: Codeunit "LLM Prompt Compl Impl ori";
        Errors: JsonArray;
        ErrorText: Text;
    begin
        Assert.IsTrue(Impl.GetErrors(Errors), 'Errors chapter');
        Errors.WriteTo(ErrorText);
        Assert.IsTrue(ErrorText.Contains('InvalidParameterFormat'), 'Prompt format code');
        Assert.IsTrue(ErrorText.Contains('PreconditionFailed'), 'Authentication/blocked code');
        Assert.IsTrue(ErrorText.Contains('Retryable'), 'Transient code');
        Assert.IsTrue(ErrorText.Contains('401'), 'Authentication status');
        Assert.IsTrue(ErrorText.Contains('429'), 'Rate limit status');
        Assert.IsTrue(ErrorText.Contains('Allow HttpClient Requests'), 'HTTP refusal');
    end;

    /// <summary>English auth errors and next steps use the published resources.</summary>
    [Test]
    procedure AC8_EnglishErrorLabels()
    begin
        VerifyLocalizedProviderError(1033, 401, false, 'PreconditionFailed', 'refused authentication', 'API key');
    end;

    /// <summary>Icelandic auth errors and next steps use the published resources.</summary>
    [Test]
    procedure AC8_IcelandicErrorLabels()
    begin
        VerifyLocalizedProviderError(1039, 401, false, 'PreconditionFailed', 'hafnaði auðkenningu', 'API-lykil');
    end;

    /// <summary>English retry errors and next steps use the published resources.</summary>
    [Test]
    procedure AC8_EnglishRetryLabels()
    begin
        VerifyLocalizedProviderError(1033, 429, false, 'Retryable', 'temporarily unavailable', 'Wait and retry');
    end;

    /// <summary>Icelandic retry errors and next steps use the published resources.</summary>
    [Test]
    procedure AC8_IcelandicRetryLabels()
    begin
        VerifyLocalizedProviderError(1039, 429, false, 'Retryable', 'tímabundið ekki tiltækur', 'Bíddu og reyndu aftur');
    end;

    /// <summary>English blocked errors and next steps use the published resources.</summary>
    [Test]
    procedure AC8_EnglishBlockedLabels()
    begin
        VerifyLocalizedProviderError(1033, 0, true, 'PreconditionFailed', 'HttpClient calls are blocked', 'Allow HttpClient Requests');
    end;

    /// <summary>Icelandic blocked errors and next steps use the published resources.</summary>
    [Test]
    procedure AC8_IcelandicBlockedLabels()
    begin
        VerifyLocalizedProviderError(1039, 0, true, 'PreconditionFailed', 'HttpClient-köll eru lokuð', 'Leyfa HttpClient-beiðnir');
    end;

    /// <summary>English provider errors and next steps use the published resources.</summary>
    [Test]
    procedure AC8_EnglishProviderLabels()
    begin
        VerifyLocalizedProviderError(1033, 400, false, 'PreconditionFailed', 'could not complete the prompt', 'API key');
    end;

    /// <summary>Icelandic provider errors and next steps use the published resources.</summary>
    [Test]
    procedure AC8_IcelandicProviderLabels()
    begin
        VerifyLocalizedProviderError(1039, 400, false, 'PreconditionFailed', 'gat ekki unnið kvaðninguna', 'API-lykil');
    end;

    /// <summary>English invalid prompt answers retain the invariant code and localized guidance.</summary>
    [Test]
    procedure AC8_EnglishPromptLabels()
    begin
        VerifyLocalizedPromptError(1033, 'The prompt must be a JSON string.', 'Send the text to complete in prompt.');
    end;

    /// <summary>Icelandic invalid prompt answers retain the invariant code and localized guidance.</summary>
    [Test]
    procedure AC8_IcelandicPromptLabels()
    begin
        VerifyLocalizedPromptError(1039, 'Kvaðningin í prompt verður að vera JSON-strengur.', 'Sendu textann sem á að vinna í prompt.');
    end;

    local procedure VerifyLocalizedProviderError(LanguageId: Integer; HttpStatus: Integer; HttpBlocked: Boolean; ExpectedCode: Text; ExpectedError: Text; ExpectedNextStep: Text)
    var
        TempArgument: Record "Message Argument ori" temporary;
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        Impl: Codeunit "LLM Prompt Compl Impl ori";
        Errors: JsonArray;
        Response: JsonObject;
        ErrorText: Text;
        OriginalLanguage: Integer;
    begin
        // GIVEN an isolated temporary argument and the caller's language.
        TempArgument.Init();
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        OriginalLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        // WHEN the shared runtime mapper handles transport metadata.
        ProviderBase.RespondPromptError(TempArgument, ProviderBase.BuildPromptError(HttpStatus, HttpBlocked));
        Response.ReadFrom(TempArgument.GetResponseText());
        Impl.GetErrors(Errors);
        GlobalLanguage(OriginalLanguage);
        // THEN runtime labels localize, and contract declarations share them.
        // Foundation #777 separately renders shipping Help chapters in English.
        AssertCodedError(Response, ExpectedCode);
        Assert.IsTrue(Response.GetText('error').Contains(ExpectedError), 'Error follows the caller language.');
        Assert.IsTrue(Response.GetText('nextStep').Contains(ExpectedNextStep), 'Next step follows the caller language.');
        Errors.WriteTo(ErrorText);
        Assert.IsTrue(ErrorText.Contains(ExpectedError), 'Error declaration shares the runtime label.');
        Assert.IsTrue(ErrorText.Contains(ExpectedNextStep), 'Error declaration shares the next step.');
        Assert.IsTrue(ErrorText.Contains('Retryable'), 'Codes are invariant across languages.');
        Assert.IsTrue(ErrorText.Contains('InvalidParameterFormat'), 'Validation code is invariant.');
    end;

    local procedure VerifyLocalizedPromptError(LanguageId: Integer; ExpectedError: Text; ExpectedNextStep: Text)
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        Response: JsonObject;
        ResponseContentType: Text[100];
        ResponseText: Text;
        EmptyTaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
    begin
        // GIVEN a numeric prompt with an explicit request LCID and no model/provider fixture.
        RequestContent.AddText('{"prompt":123}');
        // WHEN the public dispatcher processes the caller's LCID.
        // Execute uses the configured default language, so a GlobalLanguage change is insufficient.
        Dispatcher.EnqueueAndProcess("Message Type ori"::"LLM.Prompt.Complete", "Message Version ori"::"1.0", '', '', 'text/json', RequestContent, EmptyTaskId, LanguageId, MessageId, ResponseContent, ResponseContentType, ResponseTime);
        ResponseContent.GetSubText(ResponseText, 1);
        Assert.IsTrue(Response.ReadFrom(ResponseText), 'Response must be JSON.');
        // THEN the parameter/code remain invariant and both labels localize.
        AssertCodedError(Response, 'InvalidParameterFormat');
        Assert.AreEqual('prompt', Response.GetText('parameter'), 'Invalid input names prompt.');
        Assert.AreEqual(ExpectedError, Response.GetText('error'), 'Prompt validation error follows the caller language.');
        Assert.AreEqual(ExpectedNextStep, Response.GetText('nextStep'), 'Prompt guidance follows the caller language.');
    end;

    /// <summary>Stored attachment content is resolved and sent by the prompt implementation.</summary>
    [Test]
    procedure AC6_StoredAttachment()
    var
        Model: Record "Bifrost Language Model ori";
        Attachment: Record "Incoming Document Attachment";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        RequestJson: JsonObject;
        AttachmentJson: JsonObject;
        Response: JsonObject;
        ContentStream: OutStream;
        RequestText: Text;
    begin
        CreateModel(Model, "Bifrost LangModel Prov. ori"::OpenAI);
        Attachment.Init();
        Attachment."Incoming Document Entry No." := 650001;
        Attachment."Line No." := 10000;
        Attachment.Name := 'ZZTEST65';
        Attachment."File Extension" := 'pdf';
        Attachment.Content.CreateOutStream(ContentStream);
        ContentStream.WriteText('hello');
        Attachment.Insert(false);
        RequestJson.ReadFrom(Request(Model.Code, false, false));
        AttachmentJson.Add('table', 'Incoming Document Attachment');
        AttachmentJson.Add('systemId', Format(Attachment.SystemId, 0, 4));
        RequestJson.Add('attachment', AttachmentJson);
        RequestJson.WriteTo(RequestText);
        HttpMock.Configure(200, SuccessBody("Bifrost LangModel Prov. ori"::OpenAI, true), false, false);
        BindSubscription(HttpMock);
        Response := Execute(RequestText);
        UnbindSubscription(HttpMock);
        Assert.AreEqual('Success', Response.GetText('status'), 'Stored file completion');
        Assert.IsTrue(HttpMock.GetRequestBody().Contains('aGVsbG8='), 'Stored content reaches provider.');
        Attachment.Delete(false);
        Model.Delete(true);
    end;

    /// <summary>Failed provider content never reaches the request log even with debug enabled.</summary>
    [Test]
    procedure AC4_DebugLoggingDoesNotStoreFailure()
    var
        Setup: Record "Setup ori";
        RequestLog: Record "Request Log ori";
        Model: Record "Bifrost Language Model ori";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        Response: JsonObject;
        CountBefore: Integer;
        OriginalDebugMode: Boolean;
        SetupPage: TestPage "Setup ori";
    begin
        OriginalDebugMode := Setup.GetRequestDebugMode();
        SetupPage.OpenEdit();
        SetupPage."Request Debug Mode".SetValue(true);
        SetupPage.Close();
        Assert.IsTrue(Setup.GetRequestDebugMode(), 'Debug mode is enabled through its public page.');
        CreateModel(Model, "Bifrost LangModel Prov. ori"::OpenAI);
        RequestLog.SetRange("Log Type", "Request Log Type ori"::LLM);
        CountBefore := RequestLog.Count();
        HttpMock.Configure(401, '{"error":{"message":"Invalid key ending Z9Q7"}}', false, false);
        BindSubscription(HttpMock);
        Response := Execute(Request(Model.Code, false, false));
        UnbindSubscription(HttpMock);
        AssertCodedError(Response, 'PreconditionFailed');
        AssertSecretAbsent(Response);
        Assert.AreEqual(CountBefore, RequestLog.Count(), 'No provider text was buffered for logging.');
        Model.Delete(true);
        SetupPage.OpenEdit();
        SetupPage."Request Debug Mode".SetValue(OriginalDebugMode);
        SetupPage.Close();
    end;

    local procedure VerifyFailure(ProviderType: Enum "Bifrost LangModel Prov. ori"; Status: Integer; Blocked: Boolean; ThrowTransport: Boolean; ExpectedCode: Text; WithFile: Boolean)
    var
        Model: Record "Bifrost Language Model ori";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        Response: JsonObject;
    begin
        // [GIVEN] Owned model and synthetic key; only the transport is intercepted.
        CreateModel(Model, ProviderType);
        HttpMock.Configure(Status, 'Invalid key: llm65-fake-key-Z9Q7; last four Z9Q7', Blocked, ThrowTransport);
        BindSubscription(HttpMock);
        // [WHEN] The actual prompt message executes its provider.
        Response := Execute(Request(Model.Code, false, WithFile));
        UnbindSubscription(HttpMock);
        // [THEN] Stable code and next step; no full key or provider fragment.
        Assert.AreEqual(1, HttpMock.GetCallCount(), 'The real provider must reach the intercepted transport exactly once.');
        if (ProviderType = "Bifrost LangModel Prov. ori"::xAI) and WithFile then begin
            Assert.AreEqual(1, HttpMock.GetUploadCount(), 'A failed xAI document prompt still uploaded the file.');
            Assert.AreEqual(1, HttpMock.GetDeleteCount(), 'A failed xAI document prompt still deletes the file.');
            Assert.AreEqual('upload;prompt;delete;', HttpMock.GetOperationSequence(), 'Delete runs after the failed prompt.');
        end else begin
            Assert.AreEqual(0, HttpMock.GetUploadCount(), 'This failure does not upload an xAI file.');
            Assert.AreEqual(0, HttpMock.GetDeleteCount(), 'This failure does not delete an xAI file.');
        end;
        AssertCodedError(Response, ExpectedCode);
        AssertSecretAbsent(Response);
        if Status in [401, 403] then begin
            Assert.IsTrue(Response.GetText('nextStep').Contains('Model card'), 'Model card guidance');
            Assert.IsTrue(Response.GetText('nextStep').Contains('API key'), 'API key setup guidance');
        end;
        Model.Delete(true);
    end;

    local procedure VerifySuccess(ProviderType: Enum "Bifrost LangModel Prov. ori"; WithSystem: Boolean; WithFile: Boolean)
    var
        Model: Record "Bifrost Language Model ori";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        Response: JsonObject;
    begin
        // [GIVEN] A model card, a fake credential and the real provider response shape.
        CreateModel(Model, ProviderType);
        HttpMock.Configure(200, SuccessBody(ProviderType, WithFile), false, false);
        BindSubscription(HttpMock);
        // [WHEN] Dispatch with optional system prompt and inline file.
        Response := Execute(Request(Model.Code, WithSystem, WithFile));
        UnbindSubscription(HttpMock);
        // [THEN] Success shape is unchanged and the original payload reaches the selected endpoint.
        Assert.AreEqual(1, HttpMock.GetCallCount(), 'One completion request');
        Assert.AreEqual('Success', Response.GetText('status'), 'Success status');
        Assert.AreEqual('A safe answer', Response.GetText('reply'), 'reply');
        Assert.AreEqual('A safe answer', Response.GetText('text'), 'text alias');
        Assert.IsTrue(HttpMock.GetRequestBody().Contains('Hello from issue 65'), 'User prompt was sent.');
        Assert.AreEqual(WithSystem, HttpMock.GetRequestBody().Contains('Be concise'), 'Optional system prompt.');
        if (ProviderType = "Bifrost LangModel Prov. ori"::xAI) and WithFile then
            AssertXaiDocumentUpload(HttpMock)
        else begin
            Assert.AreEqual(WithFile, HttpMock.GetRequestBody().Contains('aGVsbG8='), 'Optional file content.');
            Assert.AreEqual(0, HttpMock.GetUploadCount(), 'This provider does not upload xAI files.');
            Assert.AreEqual(0, HttpMock.GetDeleteCount(), 'This provider does not delete xAI files.');
        end;
        if WithFile and (ProviderType = "Bifrost LangModel Prov. ori"::Google) then
            Assert.IsTrue(HttpMock.GetRequestUrl().Contains(':generateContent'), 'Gemini native file endpoint');
        if (ProviderType = "Bifrost LangModel Prov. ori"::xAI) and (not WithFile) then
            Assert.IsTrue(HttpMock.GetRequestUrl().EndsWith('/v1/chat/completions'), 'Text-only xAI stays on chat completions.');
        Model.Delete(true);
    end;

    local procedure AssertXaiDocumentUpload(var HttpMock: Codeunit "LLM 65 HTTP Mock")
    var
        RequestBody: JsonObject;
    begin
        Assert.IsTrue(RequestBody.ReadFrom(HttpMock.GetRequestBody()), 'The xAI prompt body is JSON.');
        Assert.IsFalse(RequestBody.GetBoolean('store'), 'xAI file calls set store to false.');
        Assert.IsFalse(HttpMock.GetRequestBody().Contains('file_data'), 'xAI documents are not inline file_data.');
        Assert.IsFalse(HttpMock.GetRequestBody().Contains('aGVsbG8='), 'PDF bytes stay out of the prompt body.');
        Assert.IsTrue(HttpMock.GetRequestBody().Contains('file_llm65'), 'The prompt references the uploaded file id.');
        Assert.IsTrue(HttpMock.GetRequestUrl().EndsWith('/responses'), 'xAI file endpoint');
        Assert.AreEqual(1, HttpMock.GetUploadCount(), 'The PDF is uploaded once.');
        Assert.AreEqual(1, HttpMock.GetDeleteCount(), 'The uploaded PDF is deleted.');
        Assert.AreEqual('issue65.pdf', HttpMock.GetUploadFileName(), 'The upload keeps the file name.');
        Assert.AreEqual('application/pdf', HttpMock.GetUploadMime(), 'The upload keeps the PDF MIME type.');
        Assert.IsTrue(HttpMock.GetUploadContent().Contains('aGVsbG8='), 'The uploaded bytes match the file.');
        Assert.IsTrue(HttpMock.GetUploadUrl().EndsWith('/v1/files'), 'The upload uses the Files endpoint.');
        Assert.IsTrue(HttpMock.GetDeleteUrl().EndsWith('/v1/files/file_llm65'), 'Delete uses the uploaded id.');
        Assert.AreEqual('upload;prompt;delete;', HttpMock.GetOperationSequence(), 'Upload, then prompt, then delete.');
    end;

    local procedure VerifyInlineImage(MimeType: Text; ImageData: Text; ExpectedDataUri: Text)
    var
        Model: Record "Bifrost Language Model ori";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        RequestJson: JsonObject;
        FileJson: JsonObject;
        RequestBody: JsonObject;
        Response: JsonObject;
        RequestText: Text;
    begin
        CreateModel(Model, "Bifrost LangModel Prov. ori"::xAI);
        RequestJson.Add('prompt', 'Hello from issue 93');
        RequestJson.Add('roleCode', Model.Code);
        FileJson.Add('fileName', 'issue93.img');
        FileJson.Add('mimeType', MimeType);
        FileJson.Add('data', ImageData);
        RequestJson.Add('file', FileJson);
        RequestJson.WriteTo(RequestText);
        HttpMock.Configure(200, SuccessBody("Bifrost LangModel Prov. ori"::xAI, true), false, false);
        BindSubscription(HttpMock);
        Response := Execute(RequestText);
        UnbindSubscription(HttpMock);
        Assert.AreEqual('Success', Response.GetText('status'), 'Inline image completion');
        Assert.AreEqual(1, HttpMock.GetCallCount(), 'One prompt and no file API call.');
        Assert.AreEqual(0, HttpMock.GetUploadCount(), 'An allowed image is not uploaded.');
        Assert.AreEqual(0, HttpMock.GetDeleteCount(), 'An allowed image has nothing to delete.');
        Assert.IsTrue(RequestBody.ReadFrom(HttpMock.GetRequestBody()), 'The image prompt body is JSON.');
        Assert.IsFalse(RequestBody.GetBoolean('store'), 'Inline images disable store.');
        Assert.IsTrue(HttpMock.GetRequestBody().Contains('input_image'), 'The image uses input_image.');
        Assert.IsTrue(HttpMock.GetRequestBody().Contains(ExpectedDataUri), 'The image is a data URI.');
        Assert.IsFalse(HttpMock.GetRequestBody().Contains('file_data'), 'Images are not sent as file_data.');
        Assert.IsTrue(HttpMock.GetRequestUrl().EndsWith('/responses'), 'Images use the Responses API.');
        Assert.IsTrue(HttpMock.GetRequestBody().Contains('Hello from issue 93'), 'The prompt text is sent.');
        Model.Delete(true);
    end;

    local procedure VerifyRefusedImage(MimeType: Text; ExpectedReceived: Text)
    var
        Model: Record "Bifrost Language Model ori";
        HttpMock: Codeunit "LLM 65 HTTP Mock";
        RequestJson: JsonObject;
        FileJson: JsonObject;
        Response: JsonObject;
        RequestText: Text;
    begin
        CreateModel(Model, "Bifrost LangModel Prov. ori"::xAI);
        RequestJson.Add('prompt', 'Hello from issue 93');
        RequestJson.Add('roleCode', Model.Code);
        FileJson.Add('fileName', 'issue93.bin');
        FileJson.Add('mimeType', MimeType);
        FileJson.Add('data', 'aGVsbG8=');
        RequestJson.Add('file', FileJson);
        RequestJson.WriteTo(RequestText);
        HttpMock.Configure(200, SuccessBody("Bifrost LangModel Prov. ori"::xAI, true), false, false);
        BindSubscription(HttpMock);
        Response := Execute(RequestText);
        UnbindSubscription(HttpMock);
        AssertRefusedImage(Response, HttpMock, ExpectedReceived);
        Model.Delete(true);
    end;

    local procedure AssertRefusedImage(Response: JsonObject; var HttpMock: Codeunit "LLM 65 HTTP Mock"; ExpectedReceived: Text)
    begin
        Assert.AreEqual(0, HttpMock.GetCallCount(), 'No prompt is sent for an unsupported image.');
        Assert.AreEqual(0, HttpMock.GetUploadCount(), 'No upload is sent for an unsupported image.');
        Assert.AreEqual(0, HttpMock.GetDeleteCount(), 'No delete is sent for an unsupported image.');
        Assert.AreEqual('', HttpMock.GetOperationSequence(), 'Unsupported images make no HTTP call.');
        AssertCodedError(Response, 'InvalidParameter');
        Assert.AreEqual('mimeType', Response.GetText('parameter'), 'The refusal names mimeType.');
        Assert.AreEqual(ExpectedReceived, Response.GetText('received'), 'The refused MIME type is returned.');
        Assert.IsTrue(Response.GetText('expected').Contains('image/png'), 'PNG is named as accepted.');
        Assert.IsTrue(Response.GetText('expected').Contains('image/jpeg'), 'JPEG is named as accepted.');
        Assert.IsTrue(Response.GetText('error').Contains('PNG'), 'The error names PNG.');
        Assert.IsTrue(Response.GetText('error').Contains('JPEG'), 'The error names JPEG.');
        AssertSecretAbsent(Response);
    end;

    local procedure ExecuteStored(FileExtension: Text; EntryNo: Integer; var HttpMock: Codeunit "LLM 65 HTTP Mock"; var Attachment: Record "Incoming Document Attachment"; ExpectSuccess: Boolean) Response: JsonObject
    var
        Model: Record "Bifrost Language Model ori";
        RequestJson: JsonObject;
        AttachmentJson: JsonObject;
        ContentStream: OutStream;
        RequestText: Text;
    begin
        CreateModel(Model, "Bifrost LangModel Prov. ori"::xAI);
        Attachment.SetRange("Incoming Document Entry No.", EntryNo);
        Attachment.SetRange("Line No.", 10000);
        if Attachment.FindFirst() then
            Attachment.Delete(false);
        Attachment.Init();
        Attachment."Incoming Document Entry No." := EntryNo;
        Attachment."Line No." := 10000;
        Attachment.Name := 'ZZTEST93';
        Attachment."File Extension" := CopyStr(FileExtension, 1, MaxStrLen(Attachment."File Extension"));
        Attachment.Content.CreateOutStream(ContentStream);
        ContentStream.WriteText('hello');
        Attachment.Insert(false);
        RequestJson.Add('prompt', 'Hello from issue 93');
        RequestJson.Add('roleCode', Model.Code);
        AttachmentJson.Add('table', 'Incoming Document Attachment');
        AttachmentJson.Add('systemId', Format(Attachment.SystemId, 0, 4));
        RequestJson.Add('attachment', AttachmentJson);
        RequestJson.WriteTo(RequestText);
        HttpMock.Configure(200, SuccessBody("Bifrost LangModel Prov. ori"::xAI, true), false, false);
        BindSubscription(HttpMock);
        Response := Execute(RequestText);
        UnbindSubscription(HttpMock);
        if ExpectSuccess then
            Assert.AreEqual('Success', Response.GetText('status'), 'Stored file reached the provider.');
        Model.Delete(true);
    end;

    local procedure CreateModel(var Model: Record "Bifrost Language Model ori"; ProviderType: Enum "Bifrost LangModel Prov. ori")
    var
        Secrets: Codeunit "LangModel Secrets ori";
        KeyValue: SecretText;
    begin
        Model.Init();
        Model.Code := CopyStr('ZZTEST65-' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, MaxStrLen(Model.Code));
        Model.Validate("Chat Provider", ProviderType);
        Model.Model := 'test-model';
        Model."Base URL" := 'https://llm65.invalid';
        Model.Insert(true);
        KeyValue := Format(FakeKeyTok);
        Secrets.SetUserKey(Model.Code, KeyValue);
    end;

    local procedure Request(ModelCode: Code[20]; WithSystem: Boolean; WithFile: Boolean) RequestText: Text
    var
        RequestJson: JsonObject;
        FileJson: JsonObject;
    begin
        RequestJson.Add('prompt', 'Hello from issue 65');
        RequestJson.Add('roleCode', ModelCode);
        if WithSystem then
            RequestJson.Add('system', 'Be concise');
        if WithFile then begin
            FileJson.Add('fileName', 'issue65.pdf');
            FileJson.Add('mimeType', 'application/pdf');
            FileJson.Add('data', 'aGVsbG8=');
            RequestJson.Add('file', FileJson);
        end;
        RequestJson.WriteTo(RequestText);
    end;

    local procedure SuccessBody(ProviderType: Enum "Bifrost LangModel Prov. ori"; WithFile: Boolean): Text
    begin
        if ProviderType = "Bifrost LangModel Prov. ori"::Anthropic then
            exit('{"content":[{"type":"text","text":"A safe answer"}],"usage":{"input_tokens":1,"output_tokens":3}}');
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

    local procedure AssertCodedError(Response: JsonObject; ExpectedCode: Text)
    begin
        Assert.AreEqual('Error', Response.GetText('status'), 'Coded failure status.');
        Assert.AreEqual(ExpectedCode, Response.GetText('code'), 'Failure code.');
        Assert.AreNotEqual('', Response.GetText('nextStep'), 'Actionable next step.');
        Assert.AreNotEqual('', Response.GetText('expected'), 'Expected response.');
    end;

    local procedure AssertSecretAbsent(Response: JsonObject)
    var
        ResponseText: Text;
    begin
        Response.WriteTo(ResponseText);
        Assert.IsFalse(ResponseText.Contains(FakeKeyTok), 'Fake key must not escape.');
        Assert.IsFalse(ResponseText.Contains('Z9Q7'), 'Even the last four characters must not escape.');
        Assert.IsFalse(ResponseText.Contains('Invalid key'), 'Raw provider text must not escape.');
    end;
}
