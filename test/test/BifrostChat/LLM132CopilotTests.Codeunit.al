namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Story #132: LLM.Prompt.Complete with a Copilot language model answers a distinct coded error instead of the
/// generic provider failure. Capability not registered / not active name the Copilot &amp; agent capabilities page;
/// a session where Business Central refuses Microsoft-managed Copilot (MCP, API, background) is refused before any
/// request; a failed managed Azure OpenAI call keeps its status and a redacted reason. No provider is called.
/// </summary>
codeunit 96076 "LLM 132 Copilot Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        SecretMarkerTok: Label 'Q8W2-oinn132', Locked = true;
        ModelCodeTok: Label 'LM132COPLT', Locked = true;
        BaseUrlTok: Label 'Base URL', Locked = true;
        CapabilitiesPageTok: Label 'Copilot & agent capabilities', Locked = true;
        CapabilitiesPageIsTok: Label 'Copilot og eiginleikar fulltrúa', Locked = true;
        GenericProviderErrTok: Label 'The language model provider could not complete the prompt.', Locked = true;

    [Test]
    procedure AC2_NotActive_NamesCapabilitiesPage_1033()
    var
        Response: JsonObject;
    begin
        // Story #132 AC2 | Time: none | Risk: an inactive capability reads as a Base URL/API key problem.
        Response := Respond('copilotNotActive', '', -1, '', 1033);
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), 'Coded failure.');
        Assert.AreEqual('The Bifrost Copilot capability is not active.', Response.GetText('error'), 'Distinct message.');
        Assert.AreEqual('roleCode', Response.GetText('parameter'), 'The language model is the parameter to change.');
        Assert.AreEqual('copilot', Response.GetText('received'), 'Fixed received token.');
        Assert.IsTrue(Response.GetText('nextStep').Contains(CapabilitiesPageTok), 'Next step names the capabilities page: ' + Response.GetText('nextStep'));
        Assert.IsFalse(Response.GetText('nextStep').Contains(BaseUrlTok), 'No Base URL/API key next step.');
    end;

    [Test]
    procedure AC2_NotActive_NamesCapabilitiesPage_1039()
    var
        Response: JsonObject;
    begin
        // Story #132 AC2 | Time: none | Risk: the Icelandic answer falls back to English or to the API key text.
        Response := Respond('copilotNotActive', '', -1, '', 1039);
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), 'Coded failure.');
        Assert.AreEqual('Bifröst Copilot-getan er ekki virk.', Response.GetText('error'), 'Icelandic message.');
        Assert.IsTrue(Response.GetText('nextStep').Contains(CapabilitiesPageIsTok), 'Icelandic next step names the page: ' + Response.GetText('nextStep'));
        Assert.IsFalse(Response.GetText('nextStep').Contains('API-lykil'), 'No API key next step.');
    end;

    [Test]
    procedure AC2_NotRegistered_NamesCapabilitiesPage()
    var
        Response: JsonObject;
    begin
        // Story #132 AC2 | Time: none | Risk: a missing registration is indistinguishable from an inactive one.
        Response := Respond('copilotNotRegistered', '', -1, '', 1033);
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), 'Coded failure.');
        Assert.AreEqual('The Bifrost Copilot capability is not registered in this environment.', Response.GetText('error'), 'Distinct message.');
        Assert.IsTrue(Response.GetText('nextStep').Contains(CapabilitiesPageTok), 'Next step names the capabilities page.');
        Assert.IsFalse(Response.GetText('nextStep').Contains(BaseUrlTok), 'No Base URL/API key next step.');
    end;

    [Test]
    procedure AC2_BlockerKind_CapabilityBeforeSession()
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
    begin
        // Story #132 AC2 | Time: none | Risk: a session refusal hides the capability that also has to be fixed.
        Assert.AreEqual('copilotNotRegistered', ProviderBase.GetCopilotBlockerKind(false, false, 'api'), 'Not registered first.');
        Assert.AreEqual('copilotNotRegistered', ProviderBase.GetCopilotBlockerKind(false, true, ''), 'Active without registration is still not registered.');
        Assert.AreEqual('copilotNotActive', ProviderBase.GetCopilotBlockerKind(true, false, 'api'), 'Not active before the session.');
        Assert.AreEqual('copilotSession', ProviderBase.GetCopilotBlockerKind(true, true, 'background'), 'Session refusal.');
        Assert.AreEqual('', ProviderBase.GetCopilotBlockerKind(true, true, ''), 'Callable.');
    end;

    [Test]
    procedure AC1_SessionToken_MirrorsPlatformClientTypeCheck()
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
    begin
        // Story #132 AC1 | Time: none | Risk: Copilot is called where Business Central throws (API/OData/background).
        Assert.AreEqual('api', ProviderBase.GetCopilotSessionToken(ClientType::Api, true), 'API session.');
        Assert.AreEqual('odata', ProviderBase.GetCopilotSessionToken(ClientType::OData, true), 'OData session.');
        Assert.AreEqual('odatav4', ProviderBase.GetCopilotSessionToken(ClientType::ODataV4, true), 'OData V4 session.');
        Assert.AreEqual('soap', ProviderBase.GetCopilotSessionToken(ClientType::SOAP, true), 'SOAP session.');
        Assert.AreEqual('management', ProviderBase.GetCopilotSessionToken(ClientType::Management, true), 'Management session.');
        Assert.AreEqual('background', ProviderBase.GetCopilotSessionToken(ClientType::Background, false), 'Background session.');
        Assert.AreEqual('background', ProviderBase.GetCopilotSessionToken(ClientType::Web, false), 'A web session without UI is background.');
        Assert.AreEqual('', ProviderBase.GetCopilotSessionToken(ClientType::Web, true), 'Interactive web client may call Copilot.');
    end;

    [Test]
    procedure AC1_SessionRefusal_DocumentsReason_1033()
    var
        Response: JsonObject;
    begin
        // Story #132 AC1 | Time: none | Risk: MCP callers get a generic failure instead of the documented session limit.
        Response := Respond('copilotSession', 'api', -1, '', 1033);
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), 'Coded failure.');
        Assert.IsTrue(Response.GetText('error').StartsWith('Copilot cannot run in this session.'), Response.GetText('error'));
        Assert.IsTrue(Response.GetText('error').Contains('MCP'), 'The message names MCP.');
        Assert.AreEqual('provider', Response.GetText('parameter'), 'Provider parameter.');
        Assert.AreEqual('copilot api', Response.GetText('received'), 'Session token received.');
        Assert.IsTrue(Response.GetText('nextStep').Contains('not Copilot'), 'Next step points to another provider.');
        Assert.IsFalse(Response.GetText('nextStep').Contains(BaseUrlTok), 'No Base URL/API key next step.');
    end;

    [Test]
    procedure AC1_SessionRefusal_DocumentsReason_1039()
    var
        Response: JsonObject;
    begin
        // Story #132 AC1 | Time: none | Risk: the Icelandic session refusal is untranslated.
        Response := Respond('copilotSession', 'background', -1, '', 1039);
        Assert.IsTrue(Response.GetText('error').StartsWith('Copilot getur ekki keyrt í þessari lotu.'), Response.GetText('error'));
        Assert.AreEqual('copilot background', Response.GetText('received'), 'Session token received.');
    end;

    [Test]
    procedure AC1_SessionRefusal_UnknownTokenIsDropped()
    var
        Response: JsonObject;
    begin
        // Story #132 AC1 | Time: none | Risk: an arbitrary session token is reflected to the caller (invalid input).
        Response := Respond('copilotSession', SecretMarkerTok, -1, '', 1033);
        Assert.AreEqual('copilot', Response.GetText('received'), 'Only allowlisted session tokens are returned.');
        AssertNoMarker(Response);
    end;

    [Test]
    procedure AC3_CallFailure400_KeepsStatusAndRedactedReason()
    var
        Response: JsonObject;
    begin
        // Story #132 AC3 | Time: none | Risk: the managed Azure OpenAI failure hides its status and reason.
        Response := Respond('copilotCall', '', 400, 'invalid request: messages must not be empty ' + SecretMarkerTok, 1033);
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), 'Coded failure.');
        Assert.AreEqual('copilot 400', Response.GetText('received'), 'The status is kept.');
        Assert.IsTrue(Response.GetText('error').StartsWith('The Copilot service could not complete the prompt.'), Response.GetText('error'));
        Assert.IsTrue(Response.GetText('error').Contains('Provider reason: invalid request messages must not be empty [redacted]'), Response.GetText('error'));
        Assert.IsFalse(Response.GetText('nextStep').Contains(BaseUrlTok), 'No Base URL/API key next step.');
        Assert.IsTrue(Response.GetText('nextStep').Contains(CapabilitiesPageTok), 'Next step names the capabilities page.');
        AssertNoMarker(Response);
    end;

    [Test]
    procedure AC3_CallFailureThrown_KeepsPlatformReason()
    var
        Response: JsonObject;
    begin
        // Story #132 AC3 | Time: none | Risk: a thrown System.AI error is cleared and only the generic text is left.
        Response := Respond('copilotCall', '', -1, 'Microsoft Copilot Capabilities are not allowed in API and OData Web Services sessions.', 1033);
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), 'Coded failure.');
        Assert.AreEqual('copilot', Response.GetText('received'), 'No status for a thrown error.');
        Assert.IsTrue(Response.GetText('error').Contains('microsoft copilot capabilities are not allowed in api and odata web services sessions'), Response.GetText('error'));
    end;

    [Test]
    procedure AC3_CallFailure429_IsRetryable()
    var
        Response: JsonObject;
    begin
        // Story #132 AC3 | Time: none | Risk: a throttled Copilot call is reported as a setup error.
        Response := Respond('copilotCall', '', 429, 'rate limit exceeded', 1033);
        Assert.AreEqual('Retryable', Response.GetText('code'), 'Transient status.');
        Assert.AreEqual('copilot 429', Response.GetText('received'), 'The status is kept.');
        Assert.IsTrue(Response.GetText('nextStep').StartsWith('Wait and retry.'), Response.GetText('nextStep'));
    end;

    [Test]
    procedure AC3_CallFailure401_KeepsAuthenticationReasonPrivate()
    var
        Response: JsonObject;
    begin
        // Story #132 AC3 | Time: none | Risk: an authentication body reaches the caller (edge case).
        Response := Respond('copilotCall', '', 401, 'invalid api key ' + SecretMarkerTok, 1033);
        Assert.AreEqual('copilot 401', Response.GetText('received'), 'The status is kept.');
        Assert.AreEqual('The Copilot service could not complete the prompt.', Response.GetText('error'), 'No reason for 401.');
        AssertNoMarker(Response);
    end;

    [Test]
    procedure AC1_AC2_Complete_CopilotModel_NeverGenericFailure()
    var
        CopilotProvider: Codeunit "Copilot LangModel Prov. ori";
        Response: JsonObject;
        Expected: JsonObject;
        ResponseText: Text;
    begin
        // Story #132 AC1/AC2 | Time: none | Risk: LLM.Prompt.Complete with a COPILOT card answers the generic Base URL failure.
        CreateCopilotModel();
        Response := ExecuteComplete(1033);
        DeleteCopilotModel();
        Response.WriteTo(ResponseText);
        if Response.GetText('status') = 'Success' then begin
            Assert.AreNotEqual('', Response.GetText('reply'), 'A Copilot success carries the reply.');
            exit;
        end;
        Assert.AreNotEqual(GenericProviderErrTok, Response.GetText('error'), 'Not the generic provider failure: ' + ResponseText);
        Assert.IsFalse(Response.GetText('nextStep').Contains(BaseUrlTok), 'No Base URL/API key next step: ' + ResponseText);
        if CopilotProvider.GetBlockerResponse(Expected) then
            Assert.AreEqual(Expected.GetText('error'), Response.GetText('error'), 'The capability or session refusal of this session: ' + ResponseText)
        else
            Assert.IsTrue(Response.GetText('error').StartsWith('The Copilot service could not complete the prompt.'), 'A managed call failure: ' + ResponseText);
    end;

    [Test]
    procedure AC4_ContractDocumentsCopilotLimits()
    var
        Impl: Codeunit "LLM Prompt Compl Impl ori";
        AskImpl: Codeunit "LLM Prompt Ask Impl ori";
        Errors: JsonArray;
        ErrorText: Text;
        Notes: Text;
    begin
        // Story #132 AC4 | Time: none | Risk: the help does not say where Copilot can run.
        Assert.IsTrue(Impl.GetErrors(Errors), 'Errors chapter');
        Errors.WriteTo(ErrorText);
        Assert.IsTrue(ErrorText.Contains('The Bifrost Copilot capability is not active.'), 'Not active row.');
        Assert.IsTrue(ErrorText.Contains('The Bifrost Copilot capability is not registered in this environment.'), 'Not registered row.');
        Assert.IsTrue(ErrorText.Contains('Copilot cannot run in this session.'), 'Session row.');
        Assert.IsTrue(ErrorText.Contains('The Copilot service could not complete the prompt.'), 'Call failure row.');
        Assert.IsTrue(Impl.GetNotes(Notes), 'Notes chapter');
        Assert.IsTrue(Notes.Contains('only LLM.Prompt.* type that accepts a Copilot language model'), 'Complete notes name the supported type.');
        Assert.IsTrue(Notes.Contains('interactive Business Central client session'), 'Complete notes name the session limit.');
        Assert.IsTrue(Impl.GetSelectionDescription().Contains('interactive Business Central client session'), 'Selection description names the limit.');
        Assert.IsTrue(AskImpl.GetSelectionDescription().Contains('Copilot language models are refused.'), 'Ask selection description.');
        Clear(Notes);
        Assert.IsTrue(AskImpl.GetNotes(Notes), 'Ask notes chapter');
        Assert.IsTrue(Notes.Contains('LLM.Prompt.Complete accepts a Copilot language model only in an interactive Business Central client session.'), 'Ask notes point to Complete.');
    end;

    local procedure Respond(Kind: Text; SessionToken: Text; StatusCode: Integer; Reason: Text; LanguageId: Integer) Response: JsonObject
    var
        TempMessage: Record "Message Argument ori" temporary;
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        Failure: JsonObject;
        PreviousLanguage: Integer;
    begin
        Failure := ProviderBase.BuildCopilotFailure(Kind, SessionToken, StatusCode, Reason);
        AssertNoMarker(Failure);
        TempMessage.Init();
        TempMessage.ID := CreateGuid();
        TempMessage.Insert(true);
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        ProviderBase.RespondPromptError(TempMessage, Failure);
        GlobalLanguage(PreviousLanguage);
        Assert.IsTrue(Response.ReadFrom(TempMessage.GetResponseText()), TempMessage.GetResponseText());
        Assert.AreEqual('Error', Response.GetText('status'), 'Error answer.');
    end;

    local procedure ExecuteComplete(LanguageId: Integer) ResponseJson: JsonObject
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
        RequestContent.AddText('{"prompt":"Reply with OK","roleCode":"' + ModelCodeTok + '"}');
        Dispatcher.EnqueueAndProcess("Message Type ori"::"LLM.Prompt.Complete", "Message Version ori"::"1.0", '', '', 'text/json', RequestContent, EmptyTaskId, LanguageId, MessageId, ResponseContent, ResponseContentType, ResponseTime);
        ResponseContent.GetSubText(ResponseText, 1);
        Assert.IsTrue(ResponseJson.ReadFrom(ResponseText), ResponseText);
    end;

    local procedure CreateCopilotModel()
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
    begin
        DeleteCopilotModel();
        BifrostLanguageModel.Init();
        BifrostLanguageModel.Code := ModelCodeTok;
        BifrostLanguageModel."Chat Provider" := Enum::"Bifrost LangModel Prov. ori"::Copilot;
        BifrostLanguageModel.Insert(true);
    end;

    local procedure DeleteCopilotModel()
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
    begin
        if BifrostLanguageModel.Get(ModelCodeTok) then
            BifrostLanguageModel.Delete(true);
    end;

    local procedure AssertNoMarker(Value: JsonObject)
    var
        ValueText: Text;
    begin
        Value.WriteTo(ValueText);
        Assert.IsFalse(ValueText.Contains(SecretMarkerTok), 'Provider-controlled text stays private: ' + ValueText);
    end;
}
