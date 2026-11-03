namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests the read-only tool policy of LLM.Prompt.Ask (language-models#100): classification, message type checks,
/// canonicalization, caller narrowing, blob references and the fail-closed rule.
/// </summary>
codeunit 96042 "LLM Ask Tool Policy Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Classification_WriteAndDownloadAreDenied_ReadsAllowed()
    var
        Policy: Codeunit "LLM Ask Tool Policy ori";
        Empty: JsonObject;
        Arguments: JsonObject;
        Reason: Text;
        ToolName: Text;
    begin
        // [SCENARIO] set_records, set_user_memory, set_company_memory and download_blob are denied; every read tool is allowed
        foreach ToolName in ReadTools() do
            Assert.IsTrue(Policy.CheckToolCall(ToolName, ValidArguments(ToolName), Empty, Reason), 'Read tool must be allowed: ' + ToolName + ' ' + Reason);
        foreach ToolName in WriteTools() do begin
            Assert.IsFalse(Policy.CheckToolCall(ToolName, Arguments, Empty, Reason), 'Write tool must be denied: ' + ToolName);
            Assert.AreNotEqual('', Reason, 'A denial carries a reason for the model');
        end;
        Assert.IsFalse(Policy.CheckToolCall('download_blob', Arguments, Empty, Reason), 'download_blob is always denied');
        Assert.IsTrue(Policy.CheckToolCall('get_user_memory', Arguments, Empty, Reason), 'get_user_memory is allowed');
        Assert.IsTrue(Policy.CheckToolCall('get_company_memory', Arguments, Empty, Reason), 'get_company_memory is allowed');
    end;

    [Test]
    procedure Classification_UnknownAndInventedNamesAreDenied()
    var
        Policy: Codeunit "LLM Ask Tool Policy ori";
        Empty: JsonObject;
        Arguments: JsonObject;
        Reason: Text;
    begin
        // [SCENARIO] a name outside the table, including a model-invented one, is denied
        Assert.IsFalse(Policy.CheckToolCall('delete_everything', Arguments, Empty, Reason), 'Invented tool');
        Assert.IsFalse(Policy.CheckToolCall('', Arguments, Empty, Reason), 'Empty tool name');
        Assert.IsFalse(Policy.CheckToolCall('GET_RECORDS', Arguments, Empty, Reason), 'Tool names are case sensitive like the tool server');
        Assert.AreEqual('unknown', Policy.ClassifyTool('whatever'), 'Unknown class');
    end;

    [Test]
    procedure InvokeMessageType_OnlyReadEffectIsAllowed()
    var
        Policy: Codeunit "LLM Ask Tool Policy ori";
        Empty: JsonObject;
        Effect: JsonObject;
        Reason: Text;
    begin
        // [SCENARIO] declared effects read, write, irreversible, missing and null: only read is allowed
        Effect.Add('effect', 'read');
        Assert.IsTrue(Policy.IsReadEffect(Effect, true), 'read');
        Clear(Effect);
        Effect.Add('effect', 'write');
        Assert.IsFalse(Policy.IsReadEffect(Effect, true), 'write');
        Clear(Effect);
        Effect.Add('effect', 'irreversible');
        Assert.IsFalse(Policy.IsReadEffect(Effect, true), 'irreversible');
        Clear(Effect);
        Assert.IsFalse(Policy.IsReadEffect(Effect, true), 'missing effect key');
        Assert.IsFalse(Policy.IsReadEffect(Effect, false), 'GetEffect returned false');
        Effect.Add('effect', JsonValueNull());
        Assert.IsFalse(Policy.IsReadEffect(Effect, true), 'null effect');
        Clear(Effect);
        Effect.Add('effect', JsonArrayValue());
        Assert.IsFalse(Policy.IsReadEffect(Effect, true), 'non-scalar effect');

        // Real registered types through the contract: a read type passes, a write type does not
        Assert.IsTrue(Policy.CheckMessageType('Help.WhoAmI.Get', Empty, Reason), 'Help.WhoAmI.Get is read: ' + Reason);
        Assert.IsFalse(Policy.CheckMessageType('Data.Records.Set', Empty, Reason), 'Data.Records.Set is a write');
        Assert.IsFalse(Policy.CheckMessageType('Test.LanguageModel.Set', Empty, Reason), 'Test.LanguageModel.Set is a write');
    end;

    [Test]
    procedure InvokeMessageType_UnknownEmptyMissingTypeAreDenied()
    var
        Policy: Codeunit "LLM Ask Tool Policy ori";
        Empty: JsonObject;
        Arguments: JsonObject;
        Reason: Text;
    begin
        Arguments.Add('type', 'No.Such.Type');
        Assert.IsFalse(Policy.CheckToolCall('invoke_message_type', Arguments, Empty, Reason), 'Unknown type');
        Assert.IsTrue(Reason.Contains('Unknown message type'), 'Reason names the problem: ' + Reason);
        Clear(Arguments);
        Arguments.Add('type', '');
        Assert.IsFalse(Policy.CheckToolCall('invoke_message_type', Arguments, Empty, Reason), 'Empty type');
        Clear(Arguments);
        Assert.IsFalse(Policy.CheckToolCall('invoke_message_type', Arguments, Empty, Reason), 'Missing type');
        Clear(Arguments);
        Arguments.Add('type', JsonValueNull());
        Assert.IsFalse(Policy.CheckToolCall('invoke_message_type', Arguments, Empty, Reason), 'Null type');
    end;

    [Test]
    procedure Canonicalization_CaseAndOrdinalAreJudgedLikeTheName()
    var
        Policy: Codeunit "LLM Ask Tool Policy ori";
        Empty: JsonObject;
        Canonical: Text;
        Reason: Text;
        Ordinal: Integer;
        Complete: Enum "Message Type ori";
    begin
        // [SCENARIO] lower case and ordinal spellings resolve like the canonical name
        Assert.IsTrue(Policy.TryCanonicalMessageType('help.whoami.get', Canonical), 'lower case resolves');
        Assert.AreEqual('Help.WhoAmI.Get', Canonical, 'canonical name');
        Assert.IsTrue(Policy.CheckMessageType('help.whoami.get', Empty, Reason), 'lower case read type allowed');

        Assert.IsTrue(Policy.TryCanonicalMessageType('llm.prompt.complete', Canonical), 'LLM.Prompt.Complete resolves in lower case');
        Assert.AreEqual('LLM.Prompt.Complete', Canonical, 'canonical LLM.Prompt.Complete');
        Assert.IsFalse(Policy.CheckMessageType('llm.prompt.complete', Empty, Reason), 'lower case Complete denied');
        Assert.IsFalse(Policy.CheckMessageType('LLM.Prompt.Complete', Empty, Reason), 'Complete denied');

        Evaluate(Complete, 'LLM.Prompt.Complete');
        Ordinal := Complete.AsInteger();
        Assert.IsTrue(Policy.TryCanonicalMessageType(Format(Ordinal), Canonical), 'ordinal text resolves');
        Assert.AreEqual('LLM.Prompt.Complete', Canonical, 'ordinal gives the canonical name');
        Assert.IsFalse(Policy.CheckMessageType(Format(Ordinal), Empty, Reason), 'Complete denied as ordinal');
    end;

    [Test]
    procedure AlwaysDenied_AskCompletePlaybookAndRequestLog()
    var
        Policy: Codeunit "LLM Ask Tool Policy ori";
    begin
        Assert.IsTrue(Policy.IsAlwaysDeniedMessageType('LLM.Prompt.Ask'), 'LLM.Prompt.Ask');
        Assert.IsTrue(Policy.IsAlwaysDeniedMessageType('llm.prompt.ask'), 'LLM.Prompt.Ask lower case');
        Assert.IsTrue(Policy.IsAlwaysDeniedMessageType('LLM.Prompt.Complete'), 'LLM.Prompt.Complete');
        Assert.IsTrue(Policy.IsAlwaysDeniedMessageType('Orchestrator.Playbook.Run'), 'Playbook prefix');
        Assert.IsTrue(Policy.IsAlwaysDeniedMessageType('Orchestrator.Playbook.Anything.Else'), 'Playbook prefix, any suffix');
        Assert.IsTrue(Policy.IsAlwaysDeniedMessageType('orchestrator.playbook.run'), 'Playbook prefix, lower case');
        Assert.IsTrue(Policy.IsAlwaysDeniedMessageType('Data.RequestLog.Get'), 'Request log (decision A3)');
        Assert.IsFalse(Policy.IsAlwaysDeniedMessageType('Orchestrator.Playbooks'), 'Not the prefix');
        Assert.IsFalse(Policy.IsAlwaysDeniedMessageType('Help.WhoAmI.Get'), 'Read type');
    end;

    [Test]
    procedure CallerLists_NarrowAndNeverWiden()
    var
        Policy: Codeunit "LLM Ask Tool Policy ori";
        Caller: JsonObject;
        Arguments: JsonObject;
        Reason: Text;
    begin
        // allow cannot add a write tool
        Caller.Add('allow', TextArray('set_records,get_records'));
        Assert.IsFalse(Policy.CheckToolCall('set_records', Arguments, Caller, Reason), 'allow does not add a write tool');
        Assert.IsTrue(Policy.CheckToolCall('get_records', Arguments, Caller, Reason), 'allow keeps a read tool');
        Assert.IsFalse(Policy.CheckToolCall('get_fields', Arguments, Caller, Reason), 'allow narrows: others are not offered');

        // deny removes
        Clear(Caller);
        Caller.Add('deny', TextArray('get_records'));
        Assert.IsFalse(Policy.CheckToolCall('get_records', Arguments, Caller, Reason), 'deny removes a read tool');
        Assert.IsTrue(Policy.CheckToolCall('get_fields', Arguments, Caller, Reason), 'deny leaves the others');

        // allowMessageTypes cannot add an always-denied or write type
        Clear(Caller);
        Clear(Arguments);
        Caller.Add('allowMessageTypes', TextArray('LLM.Prompt.Complete,Data.Records.Set,Help.WhoAmI.Get'));
        Arguments.Add('type', 'LLM.Prompt.Complete');
        Assert.IsFalse(Policy.CheckToolCall('invoke_message_type', Arguments, Caller, Reason), 'allowMessageTypes does not add an always-denied type');
        Clear(Arguments);
        Arguments.Add('type', 'Data.Records.Set');
        Assert.IsFalse(Policy.CheckToolCall('invoke_message_type', Arguments, Caller, Reason), 'allowMessageTypes does not add a write type');
        Clear(Arguments);
        Arguments.Add('type', 'Help.WhoAmI.Get');
        Assert.IsTrue(Policy.CheckToolCall('invoke_message_type', Arguments, Caller, Reason), 'allowMessageTypes keeps a read type');

        // denyMessageTypes removes, in any spelling
        Clear(Caller);
        Caller.Add('denyMessageTypes', TextArray('help.whoami.get'));
        Assert.IsFalse(Policy.CheckToolCall('invoke_message_type', Arguments, Caller, Reason), 'denyMessageTypes removes the canonical type given in lower case');
    end;

    [Test]
    procedure CallerLists_AllowEmptyOffersNothing_UnknownNamesWarn()
    var
        Policy: Codeunit "LLM Ask Tool Policy ori";
        Server: Codeunit "MCP Tool Server ori";
        ServerTools: JsonArray;
        Caller: JsonObject;
        NoNames: JsonArray;
        Allowed: List of [Text];
        Warnings: List of [Text];
    begin
        Server.ListTools(ServerTools);
        Caller.Add('allow', NoNames);
        Policy.GetAllowedToolNames(ServerTools, Caller, Allowed, Warnings);
        Assert.AreEqual(0, Allowed.Count(), 'allow [] offers no tools');
        Assert.AreEqual(0, Warnings.Count(), 'no warning for an empty list');

        Clear(Caller);
        Caller.Add('allow', TextArray('get_records,set_records,no_such_tool'));
        Policy.GetAllowedToolNames(ServerTools, Caller, Allowed, Warnings);
        Assert.AreEqual(1, Allowed.Count(), 'Only get_records is offered');
        Assert.IsTrue(Allowed.Contains('get_records'), 'get_records offered');
        Assert.IsTrue(Warnings.Contains('toolNotAvailable:set_records'), 'write tool in allow warns');
        Assert.IsTrue(Warnings.Contains('toolNotAvailable:no_such_tool'), 'unknown tool in allow warns');

        Clear(Caller);
        Caller.Add('allowMessageTypes', TextArray('Data.Records.Set'));
        Policy.GetAllowedToolNames(ServerTools, Caller, Allowed, Warnings);
        Assert.IsTrue(Warnings.Contains('toolNotAvailable:Data.Records.Set'), 'write type in allowMessageTypes warns');
    end;

    [Test]
    procedure AllCombinations_NeverOfferWriteOrUnclassified()
    var
        Policy: Codeunit "LLM Ask Tool Policy ori";
        Server: Codeunit "MCP Tool Server ori";
        ServerTools: JsonArray;
        Caller: JsonObject;
        Allowed: List of [Text];
        Warnings: List of [Text];
        Name: Text;
        Variant: Integer;
    begin
        Server.ListTools(ServerTools);
        for Variant := 0 to 4 do begin
            Clear(Caller);
            case Variant of
                1:
                    Caller.Add('allow', TextArray('set_records,set_user_memory,download_blob,get_records,list_blobs,set_blob,delete_blobs'));
                2:
                    Caller.Add('deny', TextArray('get_records'));
                3:
                    Caller.Add('allowMessageTypes', TextArray('Data.Records.Set,LLM.Prompt.Ask'));
                4:
                    Caller.Add('denyMessageTypes', TextArray('Help.WhoAmI.Get'));
            end;
            Policy.GetAllowedToolNames(ServerTools, Caller, Allowed, Warnings);
            foreach Name in Allowed do begin
                Assert.AreNotEqual('write', Policy.ClassifyTool(Name), 'No write tool is ever offered: ' + Name);
                Assert.AreNotEqual('denied', Policy.ClassifyTool(Name), 'No always-denied tool is ever offered: ' + Name);
                Assert.AreNotEqual('unknown', Policy.ClassifyTool(Name), 'No unclassified tool is ever offered: ' + Name);
                Assert.IsFalse(Name in ['list_blobs', 'set_blob', 'delete_blobs'], 'Session tools other than get_blob are not offered: ' + Name);
            end;
        end;
    end;

    [Test]
    procedure FailClosed_EveryPublishedToolIsClassified()
    var
        Policy: Codeunit "LLM Ask Tool Policy ori";
        Server: Codeunit "MCP Tool Server ori";
        ServerTools: JsonArray;
        ToolToken: JsonToken;
        NameToken: JsonToken;
        ToolName: Text;
    begin
        // [SCENARIO] this test fails when ListTools() returns a tool the policy has not classified
        Server.ListTools(ServerTools);
        Assert.IsTrue(ServerTools.Count() > 0, 'The server publishes tools');
        foreach ToolToken in ServerTools do begin
            ToolToken.AsObject().Get('name', NameToken);
            ToolName := NameToken.AsValue().AsText();
            Assert.AreNotEqual('unknown', Policy.ClassifyTool(ToolName), 'Unclassified tool published by ListTools: ' + ToolName);
        end;
        // The three names CallTool runs that ListTools does not publish are classified too
        Assert.AreNotEqual('unknown', Policy.ClassifyTool('who_am_i'), 'who_am_i');
        Assert.AreNotEqual('unknown', Policy.ClassifyTool('get_company_memory'), 'get_company_memory');
        Assert.AreNotEqual('unknown', Policy.ClassifyTool('set_company_memory'), 'set_company_memory');
    end;

    [Test]
    procedure FailClosed_ANewToolIsNotOfferedAndNotCallable()
    var
        Policy: Codeunit "LLM Ask Tool Policy ori";
        Server: Codeunit "MCP Tool Server ori";
        ServerTools: JsonArray;
        ServerCopy: JsonArray;
        NewTool: JsonObject;
        Caller: JsonObject;
        Arguments: JsonObject;
        Allowed: List of [Text];
        Warnings: List of [Text];
        Filtered: JsonArray;
        Reason: Text;
        Before: Integer;
    begin
        // [SCENARIO] a tool added through the seam (the array the policy is given) is denied and not offered
        Server.ListTools(ServerTools);
        Before := Server.GetToolCount();
        // ListTools hands out the registry itself: work on a copy so the seam does not add to it
        ServerCopy := ServerTools.Clone().AsArray();
        ServerTools := ServerCopy;
        NewTool.Add('name', 'brand_new_tool');
        NewTool.Add('description', 'unclassified');
        ServerTools.Add(NewTool);
        Policy.GetAllowedToolNames(ServerTools, Caller, Allowed, Warnings);
        Assert.IsFalse(Allowed.Contains('brand_new_tool'), 'Not offered');
        Policy.FilterToolDefinitions(ServerTools, Allowed, Filtered);
        Assert.AreEqual(Allowed.Count(), Filtered.Count(), 'Filtered holds exactly the allowed tools');
        Assert.IsFalse(Policy.CheckToolCall('brand_new_tool', Arguments, Caller, Reason), 'Not callable');
        Assert.AreEqual(Before, Server.GetToolCount(), 'The registry is not mutated');
    end;

    [Test]
    procedure Filter_InvokeMessageTypeDescriptionGetsOneSentence_RegistryUntouched()
    var
        Policy: Codeunit "LLM Ask Tool Policy ori";
        Server: Codeunit "MCP Tool Server ori";
        ServerTools: JsonArray;
        Filtered: JsonArray;
        Allowed: List of [Text];
        Warnings: List of [Text];
        Caller: JsonObject;
        Description: Text;
        OriginalDescription: Text;
        CountBefore: Integer;
    begin
        Server.ListTools(ServerTools);
        CountBefore := ServerTools.Count();
        OriginalDescription := ToolDescription(ServerTools, 'invoke_message_type');
        Policy.GetAllowedToolNames(ServerTools, Caller, Allowed, Warnings);
        Policy.FilterToolDefinitions(ServerTools, Allowed, Filtered);
        Assert.AreEqual(Allowed.Count(), Filtered.Count(), 'One definition per allowed tool');
        Assert.AreEqual(CountBefore, ServerTools.Count(), 'The source array is not changed');
        Description := ToolDescription(Filtered, 'invoke_message_type');
        Assert.IsTrue(Description.StartsWith(OriginalDescription), 'Original text kept');
        Assert.IsTrue(Description.Contains('Only read-only message types run in this session.'), 'Read-only sentence appended');
        Assert.AreEqual(OriginalDescription, ToolDescription(ServerTools, 'invoke_message_type'), 'Registry description unchanged');
    end;

    [Test]
    procedure Blobs_OnlyGetBlobOfThisRunIsAllowed()
    var
        Policy: Codeunit "LLM Ask Tool Policy ori";
        Empty: JsonObject;
        Arguments: JsonObject;
        Reason: Text;
    begin
        // [SCENARIO] decision A1: get_blob only for references created in this run; list/set/delete denied
        Arguments.Add('ref', '{{blob:aaaa-1111}}');
        Assert.IsFalse(Policy.CheckToolCall('get_blob', Arguments, Empty, Reason), 'Foreign blob refused');
        Policy.RegisterRunBlob('{{blob:AAAA-1111}}');
        Assert.IsTrue(Policy.CheckToolCall('get_blob', Arguments, Empty, Reason), 'Run blob allowed (case-insensitive id)');
        Clear(Arguments);
        Arguments.Add('ref', 'aaaa-1111');
        Assert.IsTrue(Policy.CheckToolCall('get_blob', Arguments, Empty, Reason), 'Bare id of a run blob allowed');
        Assert.IsFalse(Policy.CheckToolCall('list_blobs', Arguments, Empty, Reason), 'list_blobs denied');
        Assert.IsFalse(Policy.CheckToolCall('set_blob', Arguments, Empty, Reason), 'set_blob denied');
        Assert.IsFalse(Policy.CheckToolCall('delete_blobs', Arguments, Empty, Reason), 'delete_blobs denied');

        // a {{blob:..}} reference in the arguments of another tool is resolved by the tool server: only run blobs may be referenced
        Clear(Arguments);
        Arguments.Add('filter', 'x{{blob:foreign-2222}}y');
        Assert.IsFalse(Policy.CheckToolCall('get_records', Arguments, Empty, Reason), 'Foreign blob reference inside another tool refused');
        Clear(Arguments);
        Arguments.Add('filter', 'x{{blob:aaaa-1111}}y');
        Assert.IsTrue(Policy.CheckToolCall('get_records', Arguments, Empty, Reason), 'Run blob reference inside another tool allowed');
    end;

    [Test]
    procedure Permission_PolicyCallableWithTheLlmChatBaseline()
    var
        Policy: Codeunit "LLM Ask Tool Policy ori";
        Empty: JsonObject;
        Arguments: JsonObject;
        Reason: Text;
    begin
        // The permission-set check itself runs in LLM Ask Tool Policy Perm Tests (96043)
        Assert.IsTrue(Policy.CheckToolCall('get_fields', Arguments, Empty, Reason), 'Callable');
    end;

    local procedure ReadTools() Names: List of [Text]
    begin
        Names.AddRange('get_records', 'get_record_ids', 'get_record_count', 'get_totals', 'find_entries', 'get_fields',
            'search_tables', 'list_message_types', 'describe_message_type', 'get_page_url', 'get_next_line_no',
            'get_user_memory', 'get_company_memory', 'who_am_i');
    end;

    local procedure WriteTools() Names: List of [Text]
    begin
        Names.AddRange('set_records', 'set_user_memory', 'set_company_memory');
    end;

    local procedure ValidArguments(ToolName: Text) Arguments: JsonObject
    begin
        if ToolName = 'invoke_message_type' then
            Arguments.Add('type', 'Help.WhoAmI.Get');
    end;

    local procedure TextArray(Csv: Text) Result: JsonArray
    var
        Item: Text;
    begin
        foreach Item in Csv.Split(',') do
            Result.Add(Item);
    end;

    local procedure JsonArrayValue() Result: JsonArray
    begin
        Result.Add('read');
    end;

    local procedure JsonValueNull() Result: JsonValue
    begin
        Result.SetValueToNull();
    end;

    local procedure ToolDescription(Tools: JsonArray; ToolName: Text): Text
    var
        ToolToken: JsonToken;
        NameToken: JsonToken;
        DescriptionToken: JsonToken;
    begin
        foreach ToolToken in Tools do begin
            ToolToken.AsObject().Get('name', NameToken);
            if NameToken.AsValue().AsText() = ToolName then begin
                ToolToken.AsObject().Get('description', DescriptionToken);
                exit(DescriptionToken.AsValue().AsText());
            end;
        end;
    end;
}
