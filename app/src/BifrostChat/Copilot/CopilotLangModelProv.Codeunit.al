namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

using System.AI;

/// <summary>
/// Implements the Bifrost Language Model Provider interface for the BC Copilot provider.
/// Uses System.AI managed resources — no API keys, no external endpoints.
/// </summary>
codeunit 10035385 "Copilot LangModel Prov. ori" implements "Bifrost LangModel Provider ori"
{
    Access = Internal;

    var
        CopilotNotEnabledLbl: Label 'Copilot is not enabled for Bifrost Chat. Ask your administrator to enable it on the Copilot & agent capabilities page.', Comment = 'is-IS=Copilot er ekki virkjað fyrir Bifröst spjall. Biddu kerfisstjóra um að virkja það á síðunni Copilot og eiginleikar fulltrúa.';
        FilesNotSupportedErr: Label 'The Copilot provider does not support file attachments. Use an external provider (OpenAI, Azure OpenAI, Anthropic) for document processing.', Comment = 'is-IS=Copilot-veitandinn styður ekki skráarviðhengi. Notaðu ytri veitanda (OpenAI, Azure OpenAI, Anthropic) til að vinna úr skjölum.';

    /// <summary>
    /// Dispatches the requested operation to the Copilot provider and writes results to the temporary argument.
    /// </summary>
    procedure Execute(var Argument: Record "Bifrost Chat Argument ori" temporary)
    var
        Usage: Codeunit "LLM Usage Recorder ori";
        ProcType: Enum "Bifrost Chat Proc. Type ori";
    begin
        ProcType := Argument."Procedure Type";
        if ProcType in [ProcType::SendChatMessage, ProcType::CompletePrompt, ProcType::ContinueWithToolResults] then begin
            Usage.BeginScope();
            Usage.SetContext(Argument);
        end;
        case ProcType of
            ProcType::IsConfigured:
                Argument."Result Boolean" := CheckIsConfigured();
            ProcType::BuildConfigJson:
                Argument.SetResultText(BuildConfigJsonInternal());
            ProcType::SendChatMessage:
                DoSendChatMessage(Argument);
            ProcType::CompletePrompt:
                DoCompletePrompt(Argument);
            ProcType::ContinueWithToolResults:
                Argument.SetResultText(BuildErrorJson('Copilot provider does not support split tool execution.'));
            ProcType::GetAvailableModels:
                Argument."Result Boolean" := false;
            ProcType::TestConnection:
                DoTestConnection(Argument);
            ProcType::GetTokenUsage:
                begin
                    Argument."Input Tokens" := 0;
                    Argument."Output Tokens" := 0;
                end;
            ProcType::GetProviderName:
                Argument.SetResultText('Copilot');
            ProcType::RequiresApiKey,
            ProcType::HasServiceKeyPermission,
            ProcType::SupportsSplitToolExecution,
            ProcType::SupportsModelSelection,
            ProcType::HasExternalEndpoint:
                Argument."Result Boolean" := false;
            ProcType::SupportsToolCalling:
                Argument."Result Boolean" := true;
            ProcType::GetMaxToolCount:
                Argument."Result Integer" := 20;
            ProcType::GetApiKeyLabel,
            ProcType::GetApiKeyInstruction,
            ProcType::GetApiKeyPlaceholder,
            ProcType::GetApiKeyDocsUrl,
            ProcType::GetApiKeyDocsLinkText,
            ProcType::GetServiceKeyDescription,
            ProcType::GetDefaultBaseUrl,
            ProcType::GetDefaultModel,
            ProcType::GetDefaultSkillUrl:
                Argument.SetResultText('');
            ProcType::GetDefaultSkillText:
                Argument.SetResultText(GetDefaultSkillTextInternal());
            ProcType::GetDefaultTimeoutSeconds,
            ProcType::GetDefaultMaxTokens,
            ProcType::GetDefaultContextTokens:
                Argument."Result Integer" := 0;
        end;
        if ProcType in [ProcType::SendChatMessage, ProcType::CompletePrompt, ProcType::ContinueWithToolResults] then
            Usage.EndScope();
    end;

    local procedure CheckIsConfigured(): Boolean
    var
        CopilotCapability: Codeunit "Copilot Capability";
    begin
        if not CopilotCapability.IsCapabilityRegistered(Enum::"Copilot Capability"::"Bifrost Chat ori") then
            exit(false);
        exit(CopilotCapability.IsCapabilityActive(Enum::"Copilot Capability"::"Bifrost Chat ori"));
    end;

    local procedure BuildConfigJsonInternal(): Text
    var
        Config: JsonObject;
        ConfigText: Text;
        DefaultSkillInstructionTok: Label 'On startup, call the who_am_i tool to learn about the current user and company.', Locked = true;
    begin
        Config.Add('provider', 'Copilot');
        Config.Add('authMode', 'none');
        Config.Add('requiresApiKey', false);
        Config.Add('defaultSkillInstruction', DefaultSkillInstructionTok);

        Config.WriteTo(ConfigText);
        exit(ConfigText);
    end;

    [NonDebuggable]
    local procedure DoSendChatMessage(var Argument: Record "Bifrost Chat Argument ori" temporary)
    var
        CopilotProxy: Codeunit "Copilot Chat Proxy ori";
    begin
        if not CheckIsConfigured() then begin
            Argument.SetResultText(BuildErrorJson(CopilotNotEnabledLbl));
            exit;
        end;
        Argument.SetResultText(CopilotProxy.SendChatMessage(Argument.GetPayload()));
    end;

    [NonDebuggable]
    local procedure DoCompletePrompt(var Argument: Record "Bifrost Chat Argument ori" temporary)
    var
        AOAIChatMessages: Codeunit "AOAI Chat Messages";
        AOAIOperationResponse: Codeunit "AOAI Operation Response";
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        PayloadObject: JsonObject;
        Failure: JsonObject;
        SystemPrompt: Text;
        UserPrompt: Text;
        ResponseObj: JsonObject;
        ResultText: Text;
    begin
        if GetBlockerResponse(Failure) then begin
            Failure.WriteTo(ResultText);
            Argument.SetResultText(ResultText);
            exit;
        end;

        if not PayloadObject.ReadFrom(Argument.GetPayload()) then begin
            Argument.SetResultText(BuildErrorJson('Invalid payload JSON.'));
            exit;
        end;

        SystemPrompt := GetPayloadText(PayloadObject, 'systemPrompt');
        if SystemPrompt <> '' then
            AOAIChatMessages.SetPrimarySystemMessage(SystemPrompt);

        UserPrompt := GetFirstUserMessage(PayloadObject);
        if HasFiles(PayloadObject) then begin
            Argument.SetResultText(BuildErrorJson(FilesNotSupportedErr));
            exit;
        end;
        AOAIChatMessages.AddUserMessage(UserPrompt);

        // Business Central throws for a refused managed call; the error is kept as a redacted reason (#132).
        ClearLastError();
        if not GenerateCompletion(AOAIChatMessages, AOAIOperationResponse) then begin
            Failure := ProviderBase.BuildCopilotFailure('', '', -1, GetLastErrorText());
            ClearLastError();
            Failure.WriteTo(ResultText);
            Argument.SetResultText(ResultText);
            exit;
        end;

        if not AOAIOperationResponse.IsSuccess() then begin
            Failure := ProviderBase.BuildCopilotFailure('', '', AOAIOperationResponse.GetStatusCode(), AOAIOperationResponse.GetError());
            Failure.WriteTo(ResultText);
            Argument.SetResultText(ResultText);
            exit;
        end;

        ResponseObj.Add('reply', AOAIChatMessages.GetLastMessage());
        ResponseObj.WriteTo(ResultText);
        Argument.SetResultText(ResultText);
    end;

    [NonDebuggable]
    local procedure GenerateCompletion(var AOAIChatMessages: Codeunit "AOAI Chat Messages"; var AOAIOperationResponse: Codeunit "AOAI Operation Response"): Boolean
    var
        AzureOpenAI: Codeunit "Azure OpenAI";
        UsageCopilot: Codeunit "LLM Usage Copilot ori";
        AOAIDeployments: Codeunit "AOAI Deployments";
        AOAIChatCompletionParams: Codeunit "AOAI Chat Completion Params";
    begin
        AzureOpenAI.SetCopilotCapability(Enum::"Copilot Capability"::"Bifrost Chat ori");
        AzureOpenAI.SetManagedResourceAuthorization(Enum::"AOAI Model Type"::"Chat Completions", AOAIDeployments.GetGPT41Latest());
        AOAIChatCompletionParams.SetMaxTokens(4096);
        exit(UsageCopilot.Generate(AzureOpenAI, AOAIChatMessages, AOAIChatCompletionParams, AOAIOperationResponse));
    end;

    /// <summary>
    /// Fills a coded Copilot failure when the Bifrost Copilot capability is not registered or not active, or when
    /// this session cannot run Microsoft-managed Copilot (MCP, API, OData, web services, background). True when
    /// Copilot cannot be called; no request is sent then (#132).
    /// </summary>
    procedure GetBlockerResponse(var Response: JsonObject): Boolean
    var
        CopilotCapability: Codeunit "Copilot Capability";
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        Registered: Boolean;
        Active: Boolean;
        SessionToken: Text;
        Kind: Text;
    begin
        Registered := CopilotCapability.IsCapabilityRegistered(Enum::"Copilot Capability"::"Bifrost Chat ori");
        if Registered then
            Active := CopilotCapability.IsCapabilityActive(Enum::"Copilot Capability"::"Bifrost Chat ori");
        SessionToken := ProviderBase.GetCopilotSessionToken(CurrentClientType(), GuiAllowed());
        Kind := ProviderBase.GetCopilotBlockerKind(Registered, Active, SessionToken);
        if Kind = '' then
            exit(false);
        Response := ProviderBase.BuildCopilotFailure(Kind, SessionToken, -1, '');
        exit(true);
    end;

    local procedure GetPayloadText(PayloadObject: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if PayloadObject.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
    end;

    local procedure GetFirstUserMessage(PayloadObject: JsonObject): Text
    var
        MessagesToken: JsonToken;
        MessageToken: JsonToken;
        MessageObject: JsonObject;
    begin
        if not PayloadObject.Get('messages', MessagesToken) then
            exit('');
        if not MessagesToken.IsArray() then
            exit('');
        foreach MessageToken in MessagesToken.AsArray() do begin
            MessageObject := MessageToken.AsObject();
            if GetPayloadText(MessageObject, 'role') = 'user' then
                exit(GetPayloadText(MessageObject, 'content'));
        end;
    end;

    local procedure HasFiles(PayloadObject: JsonObject): Boolean
    var
        FilesToken: JsonToken;
    begin
        if not PayloadObject.Get('files', FilesToken) then
            exit(false);
        exit(FilesToken.IsArray() and (FilesToken.AsArray().Count() > 0));
    end;

    local procedure DoTestConnection(var Argument: Record "Bifrost Chat Argument ori" temporary)
    var
        CopilotCapability: Codeunit "Copilot Capability";
        NotRegisteredErr: Label 'The Bifrost Chat capability is not registered. Try reinstalling the extension.', Comment = 'is-IS=Bifröst spjallgetan er ekki skráð. Prófaðu að setja viðbótina upp aftur.';
    begin
        if not CopilotCapability.IsCapabilityRegistered(Enum::"Copilot Capability"::"Bifrost Chat ori") then begin
            Argument.SetErrorMessage(NotRegisteredErr);
            Argument."Result Boolean" := false;
            exit;
        end;

        if not CopilotCapability.IsCapabilityActive(Enum::"Copilot Capability"::"Bifrost Chat ori") then begin
            Argument.SetErrorMessage(CopilotNotEnabledLbl);
            Argument."Result Boolean" := false;
            exit;
        end;

        Argument."Result Boolean" := true;
    end;

    local procedure GetDefaultSkillTextInternal(): Text
    var
        DefaultSkill: Codeunit "Copilot Default Skill ori";
    begin
        exit(DefaultSkill.GetSkillText());
    end;

    local procedure BuildErrorJson(ErrorMessage: Text): Text
    var
        ErrorObj: JsonObject;
        Result: Text;
    begin
        ErrorObj.Add('error', ErrorMessage);
        ErrorObj.WriteTo(Result);
        exit(Result);
    end;
}
