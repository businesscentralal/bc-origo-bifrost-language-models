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
        PromptReasonTxt: Label '%1 Provider reason: %2', Comment = '%1 = localized failure, %2 = redacted provider diagnostic, is-IS=%1 Ástæða veitanda: %2';
        PromptAnswerExpectedTxt: Label 'an answer from the language model', Comment = 'is-IS=svar frá mállíkaninu';
        PromptSetupNextStepTxt: Label 'Check the Base URL, model and API key setup on the Bifrost Language Model card; use Bifrost App Secrets to set the API key, then try Test Connection.', Comment = 'is-IS=Athugaðu grunnslóð, líkan og uppsetningu API-lykils á spjaldi Bifröst mállíkans. Stilltu API-lykilinn í leyndarmálum forrita Bifröst og veldu síðan Prófa tengingu.';
        PromptRetryNextStepTxt: Label 'Wait and retry. If the failure persists, check the provider status and the limits on the Bifrost Language Model card.', Comment = 'is-IS=Bíddu og reyndu aftur. Ef villan kemur aftur skaltu athuga stöðu veitandans og takmarkanir á spjaldi Bifröst mállíkans.';
        PromptBlockedNextStepTxt: Label 'Ask an administrator to enable Allow HttpClient Requests for Bifrost Language Models in Extension Management, then retry.', Comment = 'is-IS=Biddu kerfisstjóra um að virkja Leyfa HttpClient-beiðnir fyrir Bifröst mállíkön í viðbótastjórnun og reyndu síðan aftur.';
        PromptAuthWhenTxt: Label 'The provider returns HTTP 401 or 403. Provider error bodies are never returned or logged.', Comment = 'is-IS=Veitandinn skilar HTTP 401 eða 403. Villutexti veitandans er aldrei birtur eða skráður.';
        PromptRetryWhenTxt: Label 'The provider returns HTTP 408, 429 or 5xx, or the request times out or cannot reach the provider.', Comment = 'is-IS=Veitandinn skilar HTTP 408, 429 eða 5xx, eða beiðnin rennur út á tíma eða nær ekki til veitandans.';
        PromptBlockedWhenTxt: Label 'Allow HttpClient Requests is disabled for the app.', Comment = 'is-IS=Leyfa HttpClient-beiðnir er óvirkt fyrir forritið.';
        PromptProviderWhenTxt: Label 'The provider refuses the request or returns an invalid response, including an unsupported file.', Comment = 'is-IS=Veitandinn hafnar beiðninni eða skilar ógildu svari, þar á meðal vegna skráar sem er ekki studd.';
        HttpClientBlockedMsg: Label 'HttpClient calls are blocked in this environment. An administrator must allow AL HttpClient requests.', Comment = 'is-IS=HttpClient-köll eru lokuð í þessu umhverfi. Kerfisstjóri þarf að leyfa AL HttpClient-beiðnir.';
        UnsupportedImageErr: Label 'This language model accepts only PNG and JPEG images.', Comment = 'is-IS=Þetta mállíkan tekur aðeins við PNG- og JPEG-myndum.';
        UnsupportedImageWhenTxt: Label 'The file mimeType is an image other than image/png or image/jpeg.', Comment = 'is-IS=mimeType skráarinnar er mynd sem er hvorki image/png né image/jpeg.';
        UnsupportedImageExpectedTxt: Label 'image/png or image/jpeg', Comment = 'is-IS=image/png eða image/jpeg';
        UnsupportedImageNextStepTxt: Label 'Send a PNG or JPEG image, or send a PDF or another document instead of this image type. No request was sent.', Comment = 'is-IS=Sendu PNG- eða JPEG-mynd, eða sendu PDF eða annað skjal í stað þessarar myndgerðar. Engin beiðni var send.';
        OversizeFileErr: Label 'The file is larger than the language model file size limit.', Comment = 'is-IS=Skráin er stærri en stærðartakmörk mállíkansins.';
        OversizeFileWhenTxt: Label 'The decoded file is larger than the language model file size limit.', Comment = 'is-IS=Afkóðuð skrá er stærri en stærðartakmörk mállíkansins.';
        OversizeFileExpectedTxt: Label 'a file within the language model file size limit', Comment = 'is-IS=skrá innan stærðartakmarka mállíkansins';
        OversizeFileNextStepTxt: Label 'Reduce the file size. No request was sent.', Comment = 'is-IS=Minnkaðu skrána. Engin beiðni var send.';
        TotalOversizeErr: Label 'The attached files total %1 bytes, which is over the %2 byte cap.', Comment = 'is-IS=Viðhengdu skrárnar eru samtals %1 bæti, sem er yfir hámarkinu %2 bæti.';
        TotalOversizeWhenTxt: Label 'The decoded size of all attached files together is larger than the total file size cap.', Comment = 'is-IS=Afkóðuð stærð allra viðhengdra skráa saman er stærri en heildarstærðartakmörkin.';
        TotalOversizeExpectedTxt: Label 'at most %1 bytes in total', Comment = 'is-IS=í mesta lagi %1 bæti samtals';
        TotalOversizeNextStepTxt: Label 'Remove or reduce files so the total decoded size is within the cap. No request was sent.', Comment = 'is-IS=Fjarlægðu eða minnkaðu skrár svo heildarstærðin sé innan hámarksins. Engin beiðni var send.';
        ProviderParameterTok: Label 'provider', Locked = true;
        FileParameterTok: Label 'file', Locked = true;
        FilesParameterTok: Label 'files', Locked = true;
        UnsupportedImageKindTok: Label 'unsupportedImage', Locked = true;
        OversizeKindTok: Label 'oversize', Locked = true;
        TotalOversizeKindTok: Label 'totalOversize', Locked = true;

    /// <summary>Builds a safe prompt failure from transport metadata, never a provider body or exception.</summary>
    procedure BuildPromptError(HttpStatus: Integer; HttpBlocked: Boolean) Response: JsonObject
    begin
        Response := BuildPromptError(HttpStatus, HttpBlocked, '');
    end;

    /// <summary>Builds a safe prompt failure and keeps only a sanitised provider error code.</summary>
    procedure BuildPromptError(HttpStatus: Integer; HttpBlocked: Boolean; ProviderErrorCode: Text) Response: JsonObject
    begin
        Response := BuildPromptError(HttpStatus, HttpBlocked, ProviderErrorCode, '');
    end;

    /// <summary>Preserves only allowlisted diagnostic words from a non-authentication provider 4xx reason.</summary>
    procedure BuildPromptError(HttpStatus: Integer; HttpBlocked: Boolean; ProviderErrorCode: Text; ProviderReason: Text) Response: JsonObject
    var
        ErrorCode: Enum "Bifrost Error Code ori";
        MessageText: Text;
        NextStep: Text;
        SafeCode: Text;
    begin
        GetPromptFailure(HttpStatus, HttpBlocked, ErrorCode, MessageText, NextStep);
        Response.Add('error', MessageText);
        Response.Add('providerStatus', HttpStatus);
        Response.Add('httpBlocked', HttpBlocked);
        SafeCode := AcceptProviderCodeToken(ProviderErrorCode);
        if SafeCode <> '' then
            Response.Add('providerErrorCode', SafeCode);
        if (HttpStatus >= 400) and (HttpStatus < 500) and not (HttpStatus in [401, 403]) then begin
            ProviderReason := RedactProviderReason(ProviderReason);
            if ProviderReason <> '' then
                Response.Add('providerReason', ProviderReason);
        end;
    end;

    /// <summary>Returns a coded, localized prompt failure without reflecting provider-controlled text.</summary>
    procedure RespondPromptError(var Argument: Record "Message Argument ori"; Response: JsonObject)
    var
        ErrorCode: Enum "Bifrost Error Code ori";
        MessageText: Text;
        NextStep: Text;
        HttpStatus: Integer;
        HttpBlocked: Boolean;
        ProviderErrorCode: Text;
        ReceivedMime: Text;
        ReceivedText: Text;
        ParameterName: Text;
        ProviderReason: Text;
    begin
        if IsSafeTotalOversizeRefusal(Response, ReceivedText) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(TotalOversizeErr, ReceivedText, Response.GetText('capBytes')), FilesParameterTok, ReceivedText, StrSubstNo(TotalOversizeExpectedTxt, Response.GetText('capBytes')), TotalOversizeNextStepTxt);
            exit;
        end;
        if IsSafeOversizeRefusal(Response) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, OversizeFileErr, FileParameterTok, '', OversizeFileExpectedTxt, OversizeFileNextStepTxt);
            exit;
        end;
        if IsSafeImageRefusal(Response, ReceivedMime) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, UnsupportedImageErr, 'mimeType', ReceivedMime, UnsupportedImageExpectedTxt, UnsupportedImageNextStepTxt);
            exit;
        end;
        HttpStatus := -1;
        if not TryReadPromptFailure(Response, HttpStatus, HttpBlocked, ProviderErrorCode) then begin
            ClearLastError();
            HttpStatus := -1;
            HttpBlocked := false;
            ProviderErrorCode := '';
        end;
        GetPromptFailure(HttpStatus, HttpBlocked, ErrorCode, MessageText, NextStep);
        if (HttpStatus >= 100) and (HttpStatus <= 599) then begin
            ParameterName := ProviderParameterTok;
            ReceivedText := Format(HttpStatus, 0, 9);
            if ProviderErrorCode <> '' then
                ReceivedText += ' ' + ProviderErrorCode;
        end;
        if (HttpStatus >= 400) and (HttpStatus < 500) and not (HttpStatus in [401, 403]) then
            if Response.Contains('providerReason') then begin
                ProviderReason := RedactProviderReason(Response.GetText('providerReason'));
                if ProviderReason <> '' then
                    MessageText := StrSubstNo(PromptReasonTxt, MessageText, ProviderReason);
            end;
        Argument.RespondWithError(ErrorCode, MessageText, ParameterName, ReceivedText, PromptAnswerExpectedTxt, NextStep);
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
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, UnsupportedImageErr, UnsupportedImageWhenTxt, UnsupportedImageNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, OversizeFileErr, OversizeFileWhenTxt, OversizeFileNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, TotalOversizeErr, TotalOversizeWhenTxt, TotalOversizeNextStepTxt));
    end;

    /// <summary>Builds the local unsupported-image refusal. No provider call is made for this answer.</summary>
    procedure BuildUnsupportedImageRefusal(MimeType: Text) Response: JsonObject
    begin
        Response.Add('error', UnsupportedImageErr);
        Response.Add('safeRefusal', true);
        Response.Add('refusalKind', UnsupportedImageKindTok);
        Response.Add('received', SanitizeMimeType(MimeType));
    end;

    /// <summary>Builds the local oversize-file refusal. No provider call is made for this answer.</summary>
    procedure BuildOversizeRefusal() Response: JsonObject
    begin
        Response.Add('error', OversizeFileErr);
        Response.Add('safeRefusal', true);
        Response.Add('refusalKind', OversizeKindTok);
    end;

    /// <summary>Builds the local total-size refusal. The error names the measured total and the cap. No provider call is made.</summary>
    procedure BuildTotalOversizeRefusal(TotalBytes: BigInteger; CapBytes: BigInteger) Response: JsonObject
    var
        TotalText: Text;
        CapText: Text;
    begin
        TotalText := Format(TotalBytes, 0, 9);
        CapText := Format(CapBytes, 0, 9);
        Response.Add('error', StrSubstNo(TotalOversizeErr, TotalText, CapText));
        Response.Add('safeRefusal', true);
        Response.Add('refusalKind', TotalOversizeKindTok);
        Response.Add('totalBytes', TotalText);
        Response.Add('capBytes', CapText);
    end;

    /// <summary>
    /// Returns a provider error code or type when it is a lowercase identifier.
    /// Provider messages, secrets and prompt text are never copied.
    /// </summary>
    [NonDebuggable]
    procedure SanitizeProviderErrorCode(ResponseText: Text): Text
    var
        Root: JsonObject;
        ErrorToken: JsonToken;
        CodeToken: JsonToken;
        Candidate: Text;
    begin
        if not Root.ReadFrom(ResponseText) then
            exit('');
        if Root.Get('error', ErrorToken) and ErrorToken.IsObject() then begin
            if ErrorToken.AsObject().Get('code', CodeToken) then
                Candidate := JsonValueText(CodeToken);
            if Candidate = '' then
                if ErrorToken.AsObject().Get('type', CodeToken) then
                    Candidate := JsonValueText(CodeToken);
        end;
        if Candidate = '' then
            if Root.Get('code', CodeToken) then
                Candidate := JsonValueText(CodeToken);
        if Candidate = '' then
            if Root.Get('type', CodeToken) then
                Candidate := JsonValueText(CodeToken);
        exit(AcceptProviderCodeToken(Candidate));
    end;

    /// <summary>Reads only a JSON provider reason; arbitrary text and other response fields are discarded.</summary>
    [NonDebuggable]
    procedure ReadProviderReason(ResponseText: Text): Text
    var
        Root: JsonObject;
        ErrorToken: JsonToken;
        MessageToken: JsonToken;
    begin
        if not Root.ReadFrom(ResponseText) then
            exit('');
        if Root.Get('error', ErrorToken) then
            if ErrorToken.IsObject() then begin
                if ErrorToken.AsObject().Get('message', MessageToken) then
                    exit(RedactProviderReason(JsonValueText(MessageToken)));
            end else
                exit(RedactProviderReason(JsonValueText(ErrorToken)));
        if Root.Get('message', MessageToken) then
            exit(RedactProviderReason(JsonValueText(MessageToken)));
    end;

    /// <summary>
    /// Fail-closed redaction: keeps a fixed diagnostic vocabulary and protocol field names only.
    /// All other tokens (including names, keys, fragments, URLs and prompt/file content) become [redacted].
    /// Authentication bodies are not passed here by the transport.
    /// </summary>
    [NonDebuggable]
    procedure RedactProviderReason(Reason: Text) Result: Text
    var
        Index: Integer;
        Word: Text;
        Character: Char;
        HasDiagnostic: Boolean;
    begin
        if (Reason = '') or (StrLen(Reason) > 8192) then
            exit('');
        for Index := 1 to StrLen(Reason) + 1 do begin
            Character := ' ';
            if Index <= StrLen(Reason) then
                Character := Reason[Index];
            if IsLatinLetter(Character) or IsDigit(Character) or (Character = '_') or (Character = '-') then
                Word += Format(Character)
            else
                if Word <> '' then begin
                    AppendDiagnosticWord(LowerCase(Word), Result, HasDiagnostic);
                    Word := '';
                end;
            if StrLen(Result) > 300 then
                break;
        end;
        if not HasDiagnostic then
            exit('');
        exit(CopyStr(Result, 1, 300));
    end;

    local procedure AppendDiagnosticWord(Word: Text; var Result: Text; var HasDiagnostic: Boolean)
    var
        VocabularyTok: Label '|a|an|the|is|are|was|be|must|not|only|and|or|for|in|of|to|with|this|that|as|at|by|on|from|cannot|does|do|has|have|please|use|instead|provided|received|valid|invalid|unsupported|supported|unknown|unrecognized|missing|required|expected|allowed|not_allowed|too|large|long|exceeds|maximum|minimum|limit|request|parameter|parameters|field|fields|value|type|format|content|message|messages|input|output|model|file|files|image|document|text|html|json|object|array|string|number|boolean|null|file_data|file_id|file_url|filename|input_file|input_image|input_text|image_url|response_format|max_tokens|max_completion_tokens|max_output_tokens|instructions|tools|tool_choice|function|functions|role|user|system|assistant|store|reasoning_effort|redacted|', Locked = true;
    begin
        if Word in ['invalid', 'unsupported', 'unknown', 'unrecognized', 'missing', 'required', 'expected', 'exceeds', 'cannot', 'not'] then
            HasDiagnostic := true;
        if not VocabularyTok.Contains('|' + Word + '|') or (Word = 'redacted') then
            Word := '[redacted]';
        if (Word = '[redacted]') and Result.EndsWith(Word) then
            exit;
        if Result <> '' then
            Result += ' ';
        Result += Word;
    end;

    /// <summary>Returns the file id when it can be placed in a URL path, otherwise empty.</summary>
    procedure NormalizeProviderFileId(FileId: Text): Text
    var
        Index: Integer;
        Character: Char;
    begin
        if (StrLen(FileId) < 1) or (StrLen(FileId) > 128) then
            exit('');
        for Index := 1 to StrLen(FileId) do begin
            Character := FileId[Index];
            if not (IsLatinLetter(Character) or IsDigit(Character) or (Character = '_') or (Character = '-')) then
                exit('');
        end;
        exit(FileId);
    end;

    [TryFunction]
    local procedure TryReadPromptFailure(Response: JsonObject; var HttpStatus: Integer; var HttpBlocked: Boolean; var ProviderErrorCode: Text)
    begin
        ProviderErrorCode := '';
        if Response.Contains('providerStatus') then
            HttpStatus := Response.GetInteger('providerStatus');
        if Response.Contains('httpBlocked') then
            HttpBlocked := Response.GetBoolean('httpBlocked');
        if Response.Contains('providerErrorCode') then
            ProviderErrorCode := AcceptProviderCodeToken(Response.GetText('providerErrorCode'));
    end;

    local procedure IsSafeImageRefusal(Response: JsonObject; var ReceivedMime: Text): Boolean
    begin
        ReceivedMime := '';
        if not IsSafeRefusalKind(Response, UnsupportedImageKindTok) then
            exit(false);
        if Response.Contains('received') then
            ReceivedMime := SanitizeMimeType(Response.GetText('received'));
        exit(true);
    end;

    local procedure IsSafeOversizeRefusal(Response: JsonObject): Boolean
    begin
        exit(IsSafeRefusalKind(Response, OversizeKindTok));
    end;

    local procedure IsSafeTotalOversizeRefusal(Response: JsonObject; var TotalText: Text): Boolean
    var
        CapText: Text;
    begin
        TotalText := '';
        if not IsSafeRefusalKind(Response, TotalOversizeKindTok) then
            exit(false);
        if not Response.Contains('totalBytes') or not Response.Contains('capBytes') then
            exit(false);
        TotalText := Response.GetText('totalBytes');
        CapText := Response.GetText('capBytes');
        if not IsDecimalDigitText(TotalText) or not IsDecimalDigitText(CapText) then
            exit(false);
        exit(true);
    end;

    local procedure IsDecimalDigitText(Value: Text): Boolean
    begin
        if Value = '' then
            exit(false);
        exit(DelChr(Value, '=', '0123456789') = '');
    end;

    local procedure IsSafeRefusalKind(Response: JsonObject; Kind: Text): Boolean
    begin
        if not Response.Contains('safeRefusal') then
            exit(false);
        if not Response.GetBoolean('safeRefusal') then
            exit(false);
        if not Response.Contains('refusalKind') then
            exit(Kind = UnsupportedImageKindTok);
        exit(Response.GetText('refusalKind') = Kind);
    end;

    local procedure SanitizeMimeType(MimeType: Text): Text
    var
        Normalized: Text;
        Index: Integer;
        Character: Char;
        Result: Text;
    begin
        Normalized := LowerCase(MimeType);
        for Index := 1 to StrLen(Normalized) do begin
            Character := Normalized[Index];
            if not (IsLatinLetter(Character) or IsDigit(Character) or (Character = '/') or (Character = '+') or (Character = '.') or (Character = '-')) then
                exit('image/unsupported');
            Result += Character;
            if StrLen(Result) >= 80 then
                exit(Result);
        end;
        if Result = '' then
            exit('image/unsupported');
        exit(Result);
    end;

    local procedure AcceptProviderCodeToken(Value: Text): Text
    var
        Index: Integer;
        Character: Char;
    begin
        if (StrLen(Value) < 3) or (StrLen(Value) > 64) or (StrPos(Value, '_') = 0) then
            exit('');
        if Value.StartsWith('sk_') or Value.StartsWith('xai') or Value.Contains('bearer') then
            exit('');
        for Index := 1 to StrLen(Value) do begin
            Character := Value[Index];
            if Index = 1 then begin
                if (Character < 'a') or (Character > 'z') then
                    exit('');
            end else
                if not (IsLatinLetter(Character) or IsDigit(Character) or (Character = '_')) then
                    exit('');
            if (Character >= 'A') and (Character <= 'Z') then
                exit('');
        end;
        exit(Value);
    end;

    local procedure JsonValueText(Token: JsonToken): Text
    begin
        if not Token.IsValue() then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    local procedure IsLatinLetter(Character: Char): Boolean
    begin
        exit(((Character >= 'a') and (Character <= 'z')) or ((Character >= 'A') and (Character <= 'Z')));
    end;

    local procedure IsDigit(Character: Char): Boolean
    begin
        exit((Character >= '0') and (Character <= '9'));
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
    /// Fills a chat argument from a language model: endpoint, model, timeout, token limits and API key.
    /// Shared by LLM.Prompt.Complete and LLM.Prompt.Ask so both build the provider call the same way.
    /// </summary>
    [NonDebuggable]
    procedure BuildModelChatArgument(var BifrostLanguageModel: Record "Bifrost Language Model ori"; var TempChatArg: Record "Bifrost Chat Argument ori" temporary)
    var
        LangModelSecrets: Codeunit "LangModel Secrets ori";
        ApiKeyValue: SecretText;
    begin
        TempChatArg.Init();
        TempChatArg."Language Model SystemId" := BifrostLanguageModel.SystemId;
        TempChatArg."Base URL" := BifrostLanguageModel."Base URL";
        TempChatArg.Model := BifrostLanguageModel.Model;
        TempChatArg."Timeout Ms" := BifrostLanguageModel."Timeout Seconds" * 1000;
        TempChatArg."Max Tokens" := BifrostLanguageModel."Max Tokens";
        TempChatArg."Context Tokens" := BifrostLanguageModel.GetContextTokens();
        if LangModelSecrets.TryGetApiKey(BifrostLanguageModel.Code, ApiKeyValue) then
            TempChatArg.SetApiKey(ApiKeyValue);
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
