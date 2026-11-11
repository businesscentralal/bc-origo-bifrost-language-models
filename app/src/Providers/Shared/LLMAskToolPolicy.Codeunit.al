namespace Origo.Bifrost.LanguageModels;

using Origo.Bifrost;

/// <summary>
/// The tool policy of a headless prompt (LLM.Prompt.Ask): which tools the model is offered and which calls it may run.
/// Read-only tools are allowed, writes are denied, and anything the policy has not classified is denied (fail closed).
/// The policy is applied twice: FilterToolDefinitions removes tools from the definitions sent to the model, and
/// CheckToolCall is run again for every call the model returns. Caller lists (allow, deny, allowMessageTypes,
/// denyMessageTypes) can narrow the policy and never widen it. All model-facing sentences are English and Locked.
/// </summary>
codeunit 10035430 "LLM Ask Tool Policy ori"
{
    Access = Internal;

    var
        RunBlobIds: List of [Text];
        UnknownToolTxt: Label 'Tool "%1" is not available in this session.', Comment = '%1 = tool name', Locked = true;
        WriteToolTxt: Label 'Tool "%1" is not available: this session is read-only.', Comment = '%1 = tool name', Locked = true;
        NotOfferedTxt: Label 'Tool "%1" is not available in this session.', Comment = '%1 = tool name', Locked = true;
        UnknownTypeTxt: Label 'Unknown message type "%1".', Comment = '%1 = message type', Locked = true;
        TypeDeniedTxt: Label 'Message type "%1" is not available in this session.', Comment = '%1 = message type', Locked = true;
        TypeNotReadTxt: Label 'Message type "%1" is not available: only read-only message types run in this session.', Comment = '%1 = message type', Locked = true;
        BlobDeniedTxt: Label 'Blob "%1" was not created in this session and cannot be read.', Comment = '%1 = blob reference', Locked = true;
        ReadOnlyTypesSentenceTxt: Label ' Only read-only message types run in this session.', Locked = true;
        AlwaysDeniedTypePrefixTxt: Label 'Orchestrator.Playbook.', Locked = true;

    /// <summary>
    /// Classifies a tool name: 'read', 'session' (blob store), 'write', 'denied' (always denied) or 'unknown'.
    /// Includes the three names CallTool runs that ListTools does not publish (who_am_i, get_company_memory, set_company_memory).
    /// </summary>
    /// <param name="ToolName">The tool name.</param>
    /// <returns>The class of the tool.</returns>
    procedure ClassifyTool(ToolName: Text): Text
    begin
        case ToolName of
            'get_records', 'get_record_ids', 'get_record_count', 'get_totals', 'find_entries', 'get_fields',
            'search_tables', 'list_message_types', 'describe_message_type', 'get_page_url', 'get_next_line_no',
            'get_user_memory', 'get_company_memory', 'who_am_i', 'invoke_message_type':
                exit('read');
            'get_blob', 'list_blobs', 'set_blob', 'delete_blobs':
                exit('session');
            'set_records', 'set_user_memory', 'set_company_memory':
                exit('write');
            'download_blob':
                exit('denied');
        end;
        exit('unknown');
    end;

    /// <summary>
    /// Remembers a blob created in this run; get_blob is allowed for these references only.
    /// </summary>
    /// <param name="BlobRefOrId">The blob reference ({{blob:guid}}) or the bare id.</param>
    procedure RegisterRunBlob(BlobRefOrId: Text)
    begin
        RunBlobIds.Add(ExtractBlobId(BlobRefOrId).ToLower());
    end;

    /// <summary>
    /// True when the tool is offered to the model after the policy and the caller lists are applied.
    /// get_blob is offered (it is checked per reference at call time); list_blobs, set_blob and delete_blobs are not.
    /// </summary>
    /// <param name="ToolName">The tool name.</param>
    /// <param name="CallerTools">The caller's tools object (allow, deny, allowMessageTypes, denyMessageTypes); may be empty.</param>
    /// <returns>True when the tool is offered.</returns>
    procedure IsToolOffered(ToolName: Text; CallerTools: JsonObject): Boolean
    begin
        case ClassifyTool(ToolName) of
            'read':
                ;
            'session':
                if ToolName <> 'get_blob' then
                    exit(false);
            else
                exit(false);
        end;
        exit(PassesCallerToolLists(ToolName, CallerTools));
    end;

    /// <summary>
    /// Builds the list of tool names offered to the model: the tools of the server that the policy classified as allowed,
    /// narrowed by the caller lists. A name in the caller's allow list that is unknown or not allowed is reported in
    /// Warnings as toolNotAvailable:name and never fails the request.
    /// </summary>
    /// <param name="ServerTools">The tool definitions published by the tool server.</param>
    /// <param name="CallerTools">The caller's tools object; may be empty.</param>
    /// <param name="AllowedNames">Receives the names of the tools to offer.</param>
    /// <param name="Warnings">Receives warning texts.</param>
    procedure GetAllowedToolNames(ServerTools: JsonArray; CallerTools: JsonObject; var AllowedNames: List of [Text]; var Warnings: List of [Text])
    var
        ToolToken: JsonToken;
        AllowList: List of [Text];
        Name: Text;
        ToolName: Text;
        Reason: Text;
    begin
        Clear(AllowedNames);
        Clear(Warnings);
        foreach ToolToken in ServerTools do
            if ToolToken.IsObject() then begin
                ToolName := GetText(ToolToken.AsObject(), 'name');
                if IsToolOffered(ToolName, CallerTools) then
                    AllowedNames.Add(ToolName);
            end;
        if ReadTextList(CallerTools, 'allow', AllowList) then
            foreach Name in AllowList do
                if not AllowedNames.Contains(Name) then
                    Warnings.Add('toolNotAvailable:' + Name);
        if ReadTextList(CallerTools, 'allowMessageTypes', AllowList) then
            foreach Name in AllowList do
                if not CheckMessageType(Name, CallerTools, Reason) then
                    Warnings.Add('toolNotAvailable:' + Name);
    end;

    /// <summary>
    /// Reads the allowedTools array (tool names) that a request or a saved conversation state carries.
    /// </summary>
    /// <param name="Source">The payload or the conversation state.</param>
    /// <param name="Names">Receives the names.</param>
    /// <returns>True when the key is present, even if the array is empty (nothing is offered).</returns>
    procedure ReadAllowedTools(Source: JsonObject; var Names: List of [Text]): Boolean
    begin
        exit(ReadTextList(Source, 'allowedTools', Names));
    end;

    /// <summary>
    /// Writes the allowedTools array into a conversation state so the later rounds offer the same tools.
    /// </summary>
    /// <param name="Names">The names.</param>
    /// <param name="Target">The conversation state.</param>
    procedure WriteAllowedTools(Names: List of [Text]; var Target: JsonObject)
    var
        NamesArray: JsonArray;
        Name: Text;
    begin
        foreach Name in Names do
            NamesArray.Add(Name);
        Target.Add('allowedTools', NamesArray);
    end;

    /// <summary>
    /// Builds a new array from the tool definitions that are in AllowedNames. The array the server hands out is never changed.
    /// The description of invoke_message_type gets one sentence saying that only read-only message types run.
    /// </summary>
    /// <param name="ServerTools">The tool definitions published by the tool server.</param>
    /// <param name="AllowedNames">The names to keep.</param>
    /// <param name="FilteredTools">Receives the filtered definitions.</param>
    procedure FilterToolDefinitions(ServerTools: JsonArray; AllowedNames: List of [Text]; var FilteredTools: JsonArray)
    var
        ToolToken: JsonToken;
        CopyToken: JsonToken;
        Tool: JsonObject;
        ToolName: Text;
    begin
        Clear(FilteredTools);
        foreach ToolToken in ServerTools do begin
            if not ToolToken.IsObject() then
                continue;
            ToolName := GetText(ToolToken.AsObject(), 'name');
            if not AllowedNames.Contains(ToolName) then
                continue;
            CopyToken := ToolToken.AsObject().Clone();
            Tool := CopyToken.AsObject();
            if ToolName = 'invoke_message_type' then
                AppendReadOnlySentence(Tool);
            FilteredTools.Add(Tool);
        end;
    end;

    /// <summary>
    /// Checks one tool call the model returned, before it runs. A denial is a reason for the model, not a failure of the run.
    /// </summary>
    /// <param name="ToolName">The tool name the model used.</param>
    /// <param name="Arguments">The arguments the model sent.</param>
    /// <param name="CallerTools">The caller's tools object; may be empty.</param>
    /// <param name="Reason">Receives the English reason when the call is denied.</param>
    /// <returns>True when the call may run.</returns>
    procedure CheckToolCall(ToolName: Text; Arguments: JsonObject; CallerTools: JsonObject; var Reason: Text): Boolean
    var
        ToolClass: Text;
    begin
        Reason := '';
        ToolClass := ClassifyTool(ToolName);
        case ToolClass of
            'unknown', 'denied':
                begin
                    Reason := StrSubstNo(UnknownToolTxt, ToolName);
                    exit(false);
                end;
            'write':
                begin
                    Reason := StrSubstNo(WriteToolTxt, ToolName);
                    exit(false);
                end;
            'session':
                if ToolName <> 'get_blob' then begin
                    Reason := StrSubstNo(UnknownToolTxt, ToolName);
                    exit(false);
                end;
        end;

        if not PassesCallerToolLists(ToolName, CallerTools) then begin
            Reason := StrSubstNo(NotOfferedTxt, ToolName);
            exit(false);
        end;

        if not CheckBlobReferences(ToolName, Arguments, Reason) then
            exit(false);

        if ToolName = 'invoke_message_type' then
            exit(CheckMessageTypeCall(Arguments, CallerTools, Reason));
        exit(true);
    end;

    /// <summary>
    /// Checks a message type name the way invoke_message_type resolves it: Evaluate, then the canonical name.
    /// </summary>
    /// <param name="MessageTypeText">The name, in any case, or the ordinal as text.</param>
    /// <param name="CallerTools">The caller's tools object; may be empty.</param>
    /// <param name="Reason">Receives the English reason when the type is denied.</param>
    /// <returns>True when the type may run.</returns>
    procedure CheckMessageType(MessageTypeText: Text; CallerTools: JsonObject; var Reason: Text): Boolean
    var
        CanonicalName: Text;
        Effect: JsonObject;
        HasEffect: Boolean;
    begin
        Reason := '';
        if not TryCanonicalMessageType(MessageTypeText, CanonicalName) then begin
            Reason := StrSubstNo(UnknownTypeTxt, MessageTypeText);
            exit(false);
        end;
        if IsAlwaysDeniedMessageType(CanonicalName) then begin
            Reason := StrSubstNo(TypeDeniedTxt, CanonicalName);
            exit(false);
        end;
        if not PassesCallerTypeLists(CanonicalName, CallerTools) then begin
            Reason := StrSubstNo(TypeDeniedTxt, CanonicalName);
            exit(false);
        end;
        HasEffect := GetDeclaredEffect(CanonicalName, Effect);
        if not IsReadEffect(Effect, HasEffect) then begin
            Reason := StrSubstNo(TypeNotReadTxt, CanonicalName);
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// True for the message types that are denied whatever the caller sends: the nested LLM types, the playbook types
    /// (every canonical name starting Orchestrator.Playbook.), the request log (Gunnar's decision A3) and the email types Email.Draft.Set and Email.Message.Send (#113).
    /// </summary>
    /// <param name="CanonicalName">The canonical message type name.</param>
    /// <returns>True when the type is always denied.</returns>
    procedure IsAlwaysDeniedMessageType(CanonicalName: Text): Boolean
    begin
        if CanonicalName.ToLower() in ['llm.prompt.ask', 'llm.prompt.complete', 'data.requestlog.get', 'email.draft.set', 'email.message.send'] then
            exit(true);
        exit(CanonicalName.ToLower().StartsWith(AlwaysDeniedTypePrefixTxt.ToLower()));
    end;

    /// <summary>
    /// True only when the declared effect is the text 'read'. A missing chapter, a missing, null or non-scalar effect counts as not read.
    /// </summary>
    /// <param name="Effect">The effect chapter.</param>
    /// <param name="HasEffect">True when the type declared the chapter.</param>
    /// <returns>True when the effect is read.</returns>
    procedure IsReadEffect(Effect: JsonObject; HasEffect: Boolean): Boolean
    var
        EffectToken: JsonToken;
    begin
        if not HasEffect then
            exit(false);
        if not Effect.Get('effect', EffectToken) then
            exit(false);
        if not EffectToken.IsValue() then
            exit(false);
        if EffectToken.AsValue().IsNull() then
            exit(false);
        exit(EffectToken.AsValue().AsText() = 'read');
    end;

    /// <summary>
    /// Resolves a message type exactly like Foundation (Evaluate) and returns its canonical enum name.
    /// </summary>
    /// <param name="MessageTypeText">The name in any case, or the ordinal as text.</param>
    /// <param name="CanonicalName">Receives the canonical name.</param>
    /// <returns>True when the text resolves to a registered message type.</returns>
    procedure TryCanonicalMessageType(MessageTypeText: Text; var CanonicalName: Text): Boolean
    var
        MessageType: Enum "Message Type ori";
        Names: List of [Text];
        Ordinals: List of [Integer];
        Index: Integer;
    begin
        CanonicalName := '';
        if DelChr(MessageTypeText, '<>', ' ') = '' then
            exit(false);
        if not TryEvaluate(MessageTypeText, MessageType) then
            exit(false);
        Names := MessageType.Names();
        Ordinals := MessageType.Ordinals();
        Index := Ordinals.IndexOf(MessageType.AsInteger());
        if Index = 0 then
            exit(false);
        CanonicalName := Names.Get(Index);
        exit(CanonicalName <> '');
    end;

    [TryFunction]
    local procedure TryEvaluate(MessageTypeText: Text; var MessageType: Enum "Message Type ori")
    begin
        Evaluate(MessageType, MessageTypeText);
    end;

    local procedure GetDeclaredEffect(CanonicalName: Text; var Effect: JsonObject): Boolean
    var
        MessageType: Enum "Message Type ori";
        ContractInterface: Interface "Msg Contract ori";
    begin
        if not TryEvaluate(CanonicalName, MessageType) then
            exit(false);
        ContractInterface := MessageType;
        exit(ContractInterface.GetEffect(Effect));
    end;

    local procedure CheckMessageTypeCall(Arguments: JsonObject; CallerTools: JsonObject; var Reason: Text): Boolean
    var
        TypeToken: JsonToken;
        TypeText: Text;
    begin
        if Arguments.Get('type', TypeToken) then
            if TypeToken.IsValue() then
                if not TypeToken.AsValue().IsNull() then
                    TypeText := TypeToken.AsValue().AsText();
        exit(CheckMessageType(TypeText, CallerTools, Reason));
    end;

    local procedure CheckBlobReferences(ToolName: Text; Arguments: JsonObject; var Reason: Text): Boolean
    var
        ArgumentText: Text;
        RefText: Text;
        BlobId: Text;
        StartPos: Integer;
        EndPos: Integer;
        Offset: Integer;
    begin
        if ToolName = 'get_blob' then begin
            RefText := GetText(Arguments, 'ref');
            if not RunBlobIds.Contains(ExtractBlobId(RefText).ToLower()) then begin
                Reason := StrSubstNo(BlobDeniedTxt, RefText);
                exit(false);
            end;
            exit(true);
        end;

        // {{blob:guid}} references inside any argument are resolved by the tool server: only this run's blobs may be referenced.
        Arguments.WriteTo(ArgumentText);
        Offset := 1;
        StartPos := StrPos(ArgumentText, '{{blob:');
        while StartPos > 0 do begin
            EndPos := StrPos(CopyStr(ArgumentText, StartPos), '}}');
            if EndPos = 0 then
                exit(true);
            RefText := CopyStr(ArgumentText, StartPos, EndPos + 1);
            BlobId := ExtractBlobId(RefText);
            if not RunBlobIds.Contains(BlobId.ToLower()) then begin
                Reason := StrSubstNo(BlobDeniedTxt, RefText);
                exit(false);
            end;
            Offset := StartPos + EndPos + 1;
            if Offset > StrLen(ArgumentText) then
                exit(true);
            StartPos := StrPos(CopyStr(ArgumentText, Offset), '{{blob:');
            if StartPos > 0 then
                StartPos := StartPos + Offset - 1;
        end;
        exit(true);
    end;

    local procedure PassesCallerToolLists(ToolName: Text; CallerTools: JsonObject): Boolean
    var
        List: List of [Text];
    begin
        if ReadTextList(CallerTools, 'allow', List) then
            if not List.Contains(ToolName) then
                exit(false);
        if ReadTextList(CallerTools, 'deny', List) then
            if List.Contains(ToolName) then
                exit(false);
        exit(true);
    end;

    local procedure PassesCallerTypeLists(CanonicalName: Text; CallerTools: JsonObject): Boolean
    var
        List: List of [Text];
    begin
        if ReadCanonicalTypeList(CallerTools, 'allowMessageTypes', List) then
            if not List.Contains(CanonicalName) then
                exit(false);
        if ReadCanonicalTypeList(CallerTools, 'denyMessageTypes', List) then
            if List.Contains(CanonicalName) then
                exit(false);
        exit(true);
    end;

    // Returns true when the caller sent the key (an empty array counts: allow [] means nothing is offered).
    local procedure ReadTextList(Source: JsonObject; KeyName: Text; var Result: List of [Text]): Boolean
    var
        ListToken: JsonToken;
        ItemToken: JsonToken;
    begin
        Clear(Result);
        if not Source.Get(KeyName, ListToken) then
            exit(false);
        if not ListToken.IsArray() then
            exit(false);
        foreach ItemToken in ListToken.AsArray() do
            if ItemToken.IsValue() then
                if not ItemToken.AsValue().IsNull() then
                    Result.Add(ItemToken.AsValue().AsText());
        exit(true);
    end;

    // Same as ReadTextList, with every name resolved to its canonical message type name. A name that does not resolve is kept as typed.
    local procedure ReadCanonicalTypeList(Source: JsonObject; KeyName: Text; var Result: List of [Text]): Boolean
    var
        Raw: List of [Text];
        Item: Text;
        Canonical: Text;
    begin
        Clear(Result);
        if not ReadTextList(Source, KeyName, Raw) then
            exit(false);
        foreach Item in Raw do
            if TryCanonicalMessageType(Item, Canonical) then
                Result.Add(Canonical)
            else
                Result.Add(Item);
        exit(true);
    end;

    local procedure AppendReadOnlySentence(var Tool: JsonObject)
    var
        DescriptionToken: JsonToken;
        Description: Text;
    begin
        if Tool.Get('description', DescriptionToken) then
            if DescriptionToken.IsValue() then
                Description := DescriptionToken.AsValue().AsText();
        Tool.Replace('description', Description + ReadOnlyTypesSentenceTxt);
    end;

    local procedure ExtractBlobId(BlobRef: Text): Text
    begin
        if BlobRef.StartsWith('{{blob:') and BlobRef.EndsWith('}}') then
            exit(CopyStr(BlobRef, 8, StrLen(BlobRef) - 9));
        exit(BlobRef);
    end;

    local procedure GetText(Source: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not Source.Get(PropertyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;
}
