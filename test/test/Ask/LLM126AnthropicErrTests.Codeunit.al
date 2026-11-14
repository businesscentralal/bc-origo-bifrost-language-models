namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Story #125 AC03 on the Anthropic tool loop (LLM.Prompt.Ask): a provider HTTP failure keeps its status, a sanitised
/// error code and, for a non-authentication 4xx, a redacted reason. Answered by LLM 100 HTTP Mock; no credentials.
/// </summary>
codeunit 96073 "LLM 126 Anthropic Err Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        SecretMarkerTok: Label 'Z9Q7-oinn126', Locked = true;

    [Test]
    procedure Anthropic_Ask404_ReturnsStatusAndErrorType()
    var
        Response: JsonObject;
    begin
        // Story #125 AC03 | Time: none | Risk: Ask lost the provider status that Complete reports.
        Response := RunAskFailure(404, '{"type":"error","error":{"type":"not_found_error","message":"model: claude-' + SecretMarkerTok + '"}}');
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), 'Coded prompt failure.');
        Assert.AreEqual('404 not_found_error', Response.GetText('received'), 'Status and provider error type are kept.');
        AssertNoMarker(Response);
    end;

    [Test]
    procedure Anthropic_Ask400_ReturnsRedactedReason()
    var
        Response: JsonObject;
        ResponseText: Text;
    begin
        // Story #125 AC03 | Time: none | Risk: unredacted provider text reaches the caller.
        Response := RunAskFailure(400, '{"type":"error","error":{"type":"invalid_request_error","message":"invalid model ' + SecretMarkerTok + '"}}');
        Assert.AreEqual('400 invalid_request_error', Response.GetText('received'), 'Status and provider error type are kept.');
        Response.WriteTo(ResponseText);
        Assert.IsTrue(ResponseText.Contains('invalid model [redacted]'), 'The redacted 4xx reason is returned: ' + ResponseText);
        AssertNoMarker(Response);
    end;

    [Test]
    procedure Anthropic_Ask401_KeepsAuthenticationBodyPrivate()
    var
        Response: JsonObject;
        ResponseText: Text;
    begin
        // Story #125 AC03 | Time: none | Risk: authentication bodies leak.
        Response := RunAskFailure(401, '{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key ' + SecretMarkerTok + '"}}');
        Assert.AreEqual('401 authentication_error', Response.GetText('received'), 'Only the status and error type are kept.');
        Response.WriteTo(ResponseText);
        Assert.IsFalse(ResponseText.Contains('x-api-key'), 'No authentication reason is returned.');
        AssertNoMarker(Response);
    end;

    [Test]
    procedure Anthropic_AskSuccess_StillAnswers()
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        AnthropicProxy: Codeunit "Anthropic LangModel Proxy ori";
        Mock: Codeunit "LLM 100 HTTP Mock";
        Reply: JsonObject;
        ReplyText: Text;
    begin
        // Story #125 AC03 | Time: none | Risk: the status hook changes a successful round.
        SetUpArgument(TempArgument);
        Mock.ConfigureStatus(200, '{"content":[{"type":"text","text":"done"}],"stop_reason":"end_turn","usage":{"input_tokens":1,"output_tokens":1}}');
        BindSubscription(Mock);
        ReplyText := AnthropicProxy.SendChatMessage(TempArgument, AskPayload());
        UnbindSubscription(Mock);
        Assert.AreEqual(1, Mock.GetCallCount(), 'One provider request.');
        Assert.IsTrue(Reply.ReadFrom(ReplyText), ReplyText);
        Assert.AreEqual('done', Reply.GetText('reply'), 'The reply is unchanged.');
    end;

    local procedure RunAskFailure(Status: Integer; Body: Text) Response: JsonObject
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        TempMessage: Record "Message Argument ori" temporary;
        AnthropicProxy: Codeunit "Anthropic LangModel Proxy ori";
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        Mock: Codeunit "LLM 100 HTTP Mock";
        Failure: JsonObject;
        ReplyText: Text;
    begin
        SetUpArgument(TempArgument);
        Mock.ConfigureStatus(Status, Body);
        BindSubscription(Mock);
        ReplyText := AnthropicProxy.SendChatMessage(TempArgument, AskPayload());
        UnbindSubscription(Mock);
        Assert.AreEqual(1, Mock.GetCallCount(), 'One provider request.');
        Assert.IsTrue(Failure.ReadFrom(ReplyText), ReplyText);
        Assert.IsTrue(Failure.Contains('error'), 'The round fails.');
        Assert.AreEqual(Status, Failure.GetInteger('providerStatus'), 'The provider status is structured.');
        AssertNoMarker(Failure);
        TempMessage.Init();
        TempMessage.ID := CreateGuid();
        TempMessage.Insert(true);
        ProviderBase.RespondPromptError(TempMessage, Failure);
        Response.ReadFrom(TempMessage.GetResponseText());
    end;

    local procedure AssertNoMarker(Value: JsonObject)
    var
        ValueText: Text;
    begin
        Value.WriteTo(ValueText);
        Assert.IsFalse(ValueText.Contains(SecretMarkerTok), 'Provider-controlled text stays private: ' + ValueText);
    end;

    local procedure AskPayload() PayloadText: Text
    var
        PayloadObject: JsonObject;
        Messages: JsonArray;
        Message: JsonObject;
        Allowed: JsonArray;
    begin
        Message.Add('role', 'user');
        Message.Add('content', 'QUESTION:\nSay hi.');
        Messages.Add(Message);
        PayloadObject.Add('messages', Messages);
        PayloadObject.Add('model', 'test-model');
        Allowed.Add('who_am_i');
        PayloadObject.Add('allowedTools', Allowed);
        PayloadObject.WriteTo(PayloadText);
    end;

    local procedure SetUpArgument(var TempArgument: Record "Bifrost Chat Argument ori" temporary)
    var
        KeyText: Text;
        KeyValue: SecretText;
    begin
        KeyText := 'test-key';
        KeyValue := KeyText;
        TempArgument.Init();
        TempArgument."Base URL" := 'https://mock.test.local';
        TempArgument.Model := 'test-model';
        TempArgument.SetApiKey(KeyValue);
    end;
}
