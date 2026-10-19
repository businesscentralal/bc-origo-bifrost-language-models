namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

/// <summary>
/// Shared helper procedures for Bifrost Chat language-model providers: config resolution,
/// service-key permission checks, token-usage parsing and multi-modal message building.
/// </summary>
codeunit 10035410 "LangModel Prov. Base ori"
{
    Access = Internal;

    var
        PromptAuthErr: Label 'The language model provider refused authentication.', Comment = 'is-IS=Veitandi mállíkansins hafnaði auðkenningu.';
        PromptRetryErr: Label 'The language model provider is temporarily unavailable.', Comment = 'is-IS=Veitandi mállíkansins er tímabundið ekki tiltækur.';
        PromptProviderErr: Label 'The language model provider could not complete the prompt.', Comment = 'is-IS=Veitandi mállíkansins gat ekki unnið kvaðninguna.';
        PromptAnswerExpectedTxt: Label 'an answer from the language model', Comment = 'is-IS=svar frá mállíkaninu';
        PromptSetupNextStepTxt: Label 'Check the Base URL, model and API key setup on the Bifrost Language Model card; use Bifrost App Secrets to set the API key, then try Test Connection.', Comment = 'is-IS=Athugaðu grunnslóð, líkan og uppsetningu API-lykils á spjaldi Bifröst mállíkans. Stilltu API-lykilinn í leyndarmálum forrita Bifröst og veldu síðan Prófa tengingu.';
        PromptRetryNextStepTxt: Label 'Wait and retry. If the failure persists, check the provider status and the limits on the Bifrost Language Model card.', Comment = 'is-IS=Bíddu og reyndu aftur. Ef villan kemur aftur skaltu athuga stöðu veitandans og takmarkanir á spjaldi Bifröst mállíkans.';
        PromptBlockedNextStepTxt: Label 'Ask an administrator to enable Allow HttpClient Requests for Bifrost Language Models in Extension Management, then retry.', Comment = 'is-IS=Biddu kerfisstjóra um að virkja Leyfa HttpClient-beiðnir fyrir Bifröst mállíkön í viðbótastjórnun og reyndu síðan aftur.';
        PromptAuthWhenTxt: Label 'The provider returns HTTP 401 or 403. Provider error bodies are never returned or logged.', Comment = 'is-IS=Veitandinn skilar HTTP 401 eða 403. Villutexti veitandans er aldrei birtur eða skráður.';
        PromptRetryWhenTxt: Label 'The provider returns HTTP 408, 429 or 5xx, or the request times out or cannot reach the provider.', Comment = 'is-IS=Veitandinn skilar HTTP 408, 429 eða 5xx, eða beiðnin rennur út á tíma eða nær ekki til veitandans.';
        PromptBlockedWhenTxt: Label 'Allow HttpClient Requests is disabled for the app.', Comment = 'is-IS=Leyfa HttpClient-beiðnir er óvirkt fyrir forritið.';
        PromptProviderWhenTxt: Label 'The provider refuses the request or returns an invalid response, including an unsupported file.', Comment = 'is-IS=Veitandinn hafnar beiðninni eða skilar ógildu svari, þar á meðal vegna skráar sem er ekki studd.';
        HttpClientBlockedMsg: Label 'HttpClient calls are blocked in this environment. An administrator must allow AL HttpClient requests.', Comment = 'is-IS=HttpClient-köll eru lokuð í þessu umhverfi. Kerfisstjóri þarf að leyfa AL HttpClient-beiðnir.';

    /// <summary>Builds a safe prompt failure from transport metadata, never a provider body or exception.</summary>
    procedure BuildPromptError(HttpStatus: Integer; HttpBlocked: Boolean) Response: JsonObject
    var
        ErrorCode: Enum "Bifrost Error Code ori";
        MessageText: Text;
        NextStep: Text;
    begin
        GetPromptFailure(HttpStatus, HttpBlocked, ErrorCode, MessageText, NextStep);
        Response.Add('error', MessageText);
        Response.Add('providerStatus', HttpStatus);
        Response.Add('httpBlocked', HttpBlocked);
    end;

    /// <summary>Returns a coded, localized prompt failure without reflecting provider-controlled text.</summary>
    procedure RespondPromptError(var Argument: Record "Message Argument ori"; Response: JsonObject)
    var
        ErrorCode: Enum "Bifrost Error Code ori";
        MessageText: Text;
        NextStep: Text;
        HttpStatus: Integer;
        HttpBlocked: Boolean;
    begin
        HttpStatus := -1;
        if not TryReadPromptFailure(Response, HttpStatus, HttpBlocked) then begin
            ClearLastError();
            HttpStatus := -1;
            HttpBlocked := false;
        end;
        GetPromptFailure(HttpStatus, HttpBlocked, ErrorCode, MessageText, NextStep);
        Argument.RespondWithError(ErrorCode, MessageText, '', '', PromptAnswerExpectedTxt, NextStep);
    end;

    /// <summary>Adds the same safe error labels used by prompt execution to its public contract.</summary>
    procedure AddPromptErrors(var Errors: JsonArray)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, PromptAuthErr, PromptAuthWhenTxt, PromptSetupNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::Retryable, PromptRetryErr, PromptRetryWhenTxt, PromptRetryNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, HttpClientBlockedMsg, PromptBlockedWhenTxt, PromptBlockedNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, PromptProviderErr, PromptProviderWhenTxt, PromptSetupNextStepTxt));
    end;

    [TryFunction]
    local procedure TryReadPromptFailure(Response: JsonObject; var HttpStatus: Integer; var HttpBlocked: Boolean)
    begin
        if Response.Contains('providerStatus') then
            HttpStatus := Response.GetInteger('providerStatus');
        if Response.Contains('httpBlocked') then
            HttpBlocked := Response.GetBoolean('httpBlocked');
    end;

    local procedure GetPromptFailure(HttpStatus: Integer; HttpBlocked: Boolean; var ErrorCode: Enum "Bifrost Error Code ori"; var MessageText: Text; var NextStep: Text)
    begin
        ErrorCode := "Bifrost Error Code ori"::PreconditionFailed;
        MessageText := PromptProviderErr;
        NextStep := PromptSetupNextStepTxt;
        if HttpBlocked then begin
            MessageText := HttpClientBlockedMsg;
            NextStep := PromptBlockedNextStepTxt;
            exit;
        end;
        case HttpStatus of
            401, 403:
                MessageText := PromptAuthErr;
            0, 408, 429, 500 .. 599:
                begin
                    ErrorCode := "Bifrost Error Code ori"::Retryable;
                    MessageText := PromptRetryErr;
                    NextStep := PromptRetryNextStepTxt;
                end;
        end;
    end;

    /// <summary>
    /// Returns whether the current user may view, set or clear the shared (service) API key.
    /// </summary>
    procedure HasServiceKeyPermission(): Boolean
    var
        ChatSvcGate: Record "Chat Svc Gate ori";
    begin
        exit(ChatSvcGate.WritePermission());
    end;

    /// <summary>
    /// Resolves the base URL for endpoint joins, trimming surrounding whitespace and trailing slashes.
    /// A blank or whitespace-only argument falls back to the provider default; stored values are unchanged.
    /// </summary>
    procedure GetBaseUrl(var Argument: Record "Bifrost Chat Argument ori" temporary; DefaultUrl: Text): Text
    var
        BaseUrl: Text;
    begin
        BaseUrl := Argument."Base URL".Trim();
        if BaseUrl = '' then
            BaseUrl := DefaultUrl.Trim();
        exit(DelChr(BaseUrl, '>', '/'));
    end;

    /// <summary>
    /// Joins a resolved base URL and endpoint path with one slash, without repeating a terminal v1 segment.
    /// Normalizes only the request URL; configured base and path values are unchanged.
    /// </summary>
    procedure JoinEndpointUrl(BaseUrl: Text; EndpointPath: Text): Text
    var
        ResolvedBaseUrl: Text;
        ResolvedPath: Text;
    begin
        ResolvedBaseUrl := DelChr(BaseUrl.Trim(), '>', '/');
        ResolvedPath := '/' + DelChr(EndpointPath, '<', '/');
        if ResolvedBaseUrl.EndsWith('/v1') then
            if (ResolvedPath = '/v1') or ResolvedPath.StartsWith('/v1/') then
                ResolvedPath := CopyStr(ResolvedPath, 4);
        if ResolvedPath = '' then
            exit(ResolvedBaseUrl);
        ResolvedPath := '/' + DelChr(ResolvedPath, '<', '/');
        exit(ResolvedBaseUrl + ResolvedPath);
    end;

    /// <summary>
    /// Returns the argument's Model, or the provider default when blank.
    /// </summary>
    procedure GetModel(var Argument: Record "Bifrost Chat Argument ori" temporary; DefaultModel: Text): Text
    begin
        if Argument.Model <> '' then
            exit(Argument.Model);
        exit(DefaultModel);
    end;

    /// <summary>
    /// Returns the argument's timeout in milliseconds, or the provider default when zero.
    /// </summary>
    procedure GetTimeoutMs(var Argument: Record "Bifrost Chat Argument ori" temporary; DefaultMs: Integer): Integer
    begin
        if Argument."Timeout Ms" > 0 then
            exit(Argument."Timeout Ms");
        exit(DefaultMs);
    end;

    /// <summary>
    /// Returns the argument's max tokens, or the provider default when zero.
    /// </summary>
    procedure GetMaxTokens(var Argument: Record "Bifrost Chat Argument ori" temporary; DefaultMaxTokens: Integer): Integer
    begin
        if Argument."Max Tokens" > 0 then
            exit(Argument."Max Tokens");
        exit(DefaultMaxTokens);
    end;

    /// <summary>
    /// Returns whether the argument carries an API key and a resolvable Base URL.
    /// </summary>
    [NonDebuggable]
    procedure IsConfigured(var Argument: Record "Bifrost Chat Argument ori" temporary; DefaultBaseUrl: Text): Boolean
    begin
        if not Argument.HasApiKey() then
            exit(false);
        exit(GetBaseUrl(Argument, DefaultBaseUrl) <> '');
    end;

    /// <summary>
    /// Parses OpenAI-format token usage from a response JSON string.
    /// </summary>
    procedure ParseTokenUsage(ResponseJson: Text; var InputTokens: Integer; var OutputTokens: Integer)
    var
        ResponseObject: JsonObject;
        UsageToken: JsonToken;
        UsageObject: JsonObject;
        PromptToken: JsonToken;
        CompletionToken: JsonToken;
    begin
        InputTokens := 0;
        OutputTokens := 0;
        if not ResponseObject.ReadFrom(ResponseJson) then
            exit;
        if not ResponseObject.Get('usage', UsageToken) then
            exit;
        if not UsageToken.IsObject() then
            exit;
        UsageObject := UsageToken.AsObject();
        if UsageObject.Get('prompt_tokens', PromptToken) then
            InputTokens := PromptToken.AsValue().AsInteger();
        if UsageObject.Get('completion_tokens', CompletionToken) then
            OutputTokens := CompletionToken.AsValue().AsInteger();
    end;

    /// <summary>
    /// Raises an error if HttpClient is not allowed in this environment.
    /// </summary>
    procedure EnsureHttpClientAllowed()
    begin
        if not CanSendHttpRequests() then
            Error(HttpClientBlockedMsg);
    end;

    /// <summary>Returns whether the environment permits outgoing provider requests.</summary>
    procedure CanSendHttpRequests(): Boolean
    var
        Handled: Boolean;
        Allowed: Boolean;
    begin
        OnCheckHttpClientAllowed(Handled, Allowed);
        if Handled then
            exit(Allowed);
        exit(true);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnCheckHttpClientAllowed(var Handled: Boolean; var Allowed: Boolean)
    begin
    end;

    /// <summary>
    /// If the payload contains a files array, converts the last user message
    /// from plain text to a multi-modal content array (OpenAI format).
    /// </summary>
    procedure AttachFilesToMessages(PayloadObject: JsonObject; var Messages: JsonArray)
    var
        FilesToken: JsonToken;
        FilesArray: JsonArray;
        FileToken: JsonToken;
        ContentArray: JsonArray;
        TextBlock: JsonObject;
        FileBlock: JsonObject;
        LastToken: JsonToken;
        LastMessage: JsonObject;
        NewMessage: JsonObject;
        UserText: Text;
        LastIndex: Integer;
    begin
        if not PayloadObject.Get('files', FilesToken) then
            exit;
        if not FilesToken.IsArray() then
            exit;
        FilesArray := FilesToken.AsArray();
        if FilesArray.Count() = 0 then
            exit;

        LastIndex := Messages.Count() - 1;
        if LastIndex < 0 then
            exit;
        Messages.Get(LastIndex, LastToken);
        if not LastToken.IsObject() then
            exit;
        LastMessage := LastToken.AsObject();

        UserText := GetJsonTextInternal(LastMessage, 'content');
        TextBlock.Add('type', 'text');
        TextBlock.Add('text', UserText);
        ContentArray.Add(TextBlock);

        foreach FileToken in FilesArray do
            if FileToken.IsObject() then begin
                FileBlock := BuildOpenAIFileBlock(FileToken.AsObject());
                ContentArray.Add(FileBlock);
                Clear(FileBlock);
            end;

        // Replace the last message — JsonArray.Get returns a copy, not a reference
        Messages.RemoveAt(LastIndex);
        NewMessage.Add('role', 'user');
        NewMessage.Add('content', ContentArray);
        Messages.Add(NewMessage);
    end;

    local procedure BuildOpenAIFileBlock(FileObj: JsonObject) Block: JsonObject
    var
        DataUriTok: Label 'data:%1;base64,%2', Locked = true;
        ImageUrl: JsonObject;
        FileContent: JsonObject;
        MimeType: Text;
        DataUri: Text;
    begin
        MimeType := GetJsonTextInternal(FileObj, 'mimeType');
        DataUri := StrSubstNo(DataUriTok, MimeType, GetJsonTextInternal(FileObj, 'data'));

        if MimeType.StartsWith('image/') then begin
            ImageUrl.Add('url', DataUri);
            Block.Add('type', 'image_url');
            Block.Add('image_url', ImageUrl);
        end else begin
            FileContent.Add('filename', GetJsonTextInternal(FileObj, 'fileName'));
            FileContent.Add('file_data', DataUri);
            Block.Add('type', 'file');
            Block.Add('file', FileContent);
        end;
    end;

    local procedure GetJsonTextInternal(JObject: JsonObject; PropertyName: Text): Text
    var
        JToken: JsonToken;
    begin
        if JObject.Get(PropertyName, JToken) then
            if JToken.IsValue() then
                exit(JToken.AsValue().AsText());
    end;
}
