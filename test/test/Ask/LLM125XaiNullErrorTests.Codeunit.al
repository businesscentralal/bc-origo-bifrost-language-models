namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;
using System.Utilities;

/// <summary>
/// Issue 125 AC05 regression: a successful xAI Responses body carries "error": null.
/// Only a non-null error is a provider failure. Mock-only; no credentials or live calls.
/// </summary>
codeunit 96076 "LLM 125 xAI Null Error Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        FakeKeyTok: Label 'xai125n-fixture-K4M2', Locked = true;
        DocumentTok: Label '<html><body>OK</body></html>', Locked = true;

    /// <summary>Ask with a text attachment succeeds when the Responses body has "error": null (UAT case b).</summary>
    [Test]
    procedure Scenario_AC05_AskFile_NullErrorIsSuccess()
    begin
        VerifyNullErrorSuccess(true, false);
    end;

    /// <summary>Ask in html mode with a text attachment succeeds when the body has "error": null (UAT case c).</summary>
    [Test]
    procedure Scenario_AC05_AskHtmlFile_NullErrorIsSuccess()
    begin
        VerifyNullErrorSuccess(true, true);
    end;

    /// <summary>Complete with a text attachment uses the same Responses transport and succeeds.</summary>
    [Test]
    procedure Scenario_AC05_CompleteFile_NullErrorIsSuccess()
    begin
        VerifyNullErrorSuccess(false, false);
    end;

    /// <summary>A 2xx body with a non-null error object still fails as a coded provider refusal.</summary>
    [Test]
    procedure Scenario_AC05_NonNullErrorOn2xx_StillFails()
    var
        Result: JsonObject;
        Response: JsonObject;
        Body: Text;
    begin
        // Story #125 AC05 | Time: none | Risk: dropping null must not hide a real error.
        Result := RunScenario(true, false, 1033, 200,
            '{"id":"resp_fixture","status":"failed","error":{"code":"invalid_request","message":"bad file K4M2"},"output":[]}', '');
        Response := Result.GetObject('response');
        Response.WriteTo(Body);
        Assert.AreEqual('Error', Response.GetText('status'), Body);
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), 'Coded provider refusal.');
        Assert.IsFalse(Body.Contains('K4M2'), 'No provider prose or key fragment returned.');
        Assert.AreEqual(1, Result.GetInteger('deletes'), 'Uploaded file removed on failure.');
        Assert.IsTrue(Result.GetBoolean('cleanedUp'), 'Owned fixture removed.');
    end;

    /// <summary>An upload response that carries "error": null keeps its file id and the prompt succeeds.</summary>
    [Test]
    procedure Scenario_AC05_UploadNullError_KeepsFileId()
    var
        Result: JsonObject;
        Response: JsonObject;
        Body: Text;
    begin
        // Story #125 AC05 | Time: none | Risk: OpenAI-compatible file objects may carry a null error field.
        Result := RunScenario(true, false, 1039, 200, NullErrorReply(false),
            '{"id":"file_null125","object":"file","bytes":5,"error":null}');
        Response := Result.GetObject('response');
        Response.WriteTo(Body);
        Assert.AreEqual('Success', Response.GetText('status'), Body);
        Assert.IsTrue(Result.GetText('request').Contains('file_null125'), 'Uploaded id is sent.');
        Assert.AreEqual(1, Result.GetInteger('deletes'), 'Uploaded file removed.');
        Assert.IsTrue(Result.GetBoolean('cleanedUp'), 'Owned fixture removed.');
    end;

    local procedure VerifyNullErrorSuccess(IsAsk: Boolean; HtmlMode: Boolean)
    var
        Result: JsonObject;
        Response: JsonObject;
        Locale: Integer;
        Index: Integer;
        Expected: Text;
        Body: Text;
    begin
        // Story #125 AC05 | Time: SESSION TIME presence only | Risk: success body read as failure.
        for Index := 1 to 2 do begin
            Locale := 1033;
            if Index = 2 then
                Locale := 1039;
            Result := RunScenario(IsAsk, HtmlMode, Locale, 200, NullErrorReply(HtmlMode), '');
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
            Assert.IsTrue(Result.GetText('url').EndsWith('/v1/responses'), 'Files use Responses.');
            Assert.AreEqual(1, Result.GetInteger('uploads'), 'One upload.');
            Assert.AreEqual(1, Result.GetInteger('deletes'), 'One cleanup.');
            Assert.IsTrue(Result.GetBoolean('cleanedUp'), 'Owned fixture removed.');
        end;
    end;

    /// <summary>A Responses reply in the documented wire shape, with the null error and incomplete_details fields.</summary>
    local procedure NullErrorReply(HtmlMode: Boolean): Text
    var
        Reply: Text;
    begin
        Reply := 'OK';
        if HtmlMode then
            Reply := DocumentTok;
        exit('{"id":"resp_fixture","object":"response","status":"completed","error":null,"incomplete_details":null,' +
            '"output":[{"type":"message","role":"assistant","status":"completed","content":[{"type":"output_text","text":"' + Reply + '"}]}],' +
            '"usage":{"input_tokens":10,"output_tokens":2}}');
    end;

    local procedure FakeKey() Result: SecretText
    begin
        Result := Format(FakeKeyTok);
    end;

    local procedure RunScenario(IsAsk: Boolean; HtmlMode: Boolean; Locale: Integer; HttpStatus: Integer; ProviderBody: Text; UploadBody: Text) Result: JsonObject
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
        Model.Code := CopyStr('X125N-' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(Model.Code));
        Model.Validate("Chat Provider", Enum::"Bifrost LangModel Prov. ori"::xAI);
        Model.Model := 'fixture-model';
        Model."Base URL" := 'https://xai125n.invalid/v1';
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
        Blob.CreateOutStream(Output, TextEncoding::UTF8);
        Output.WriteText('hello');
        Blob.CreateInStream(Input);
        StagingId := Staging.Create(Input, 'fixture.txt', 'text/plain', 'LM125 owned null-error fixture');
        Attachment.Add('stagingId', Format(StagingId, 0, 4));
        Attachments.Add(Attachment);
        Request.Add('attachments', Attachments);
        Mock.Configure(HttpStatus, ProviderBody, false, false);
        if UploadBody <> '' then
            Mock.ConfigureUpload(200, UploadBody);
        BindSubscription(Mock);
        Dispatch(MessageType, Request, Locale, Response, MessageId);
        UnbindSubscription(Mock);
        Model.Delete(true);
        if Staging.Exists(StagingId) then
            Staging.Take(StagingId, Blob);
        Result.Add('response', Response);
        Result.Add('request', Mock.GetRequestBody());
        Result.Add('url', Mock.GetRequestUrl());
        Result.Add('uploads', Mock.GetUploadCount());
        Result.Add('deletes', Mock.GetDeleteCount());
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
}
