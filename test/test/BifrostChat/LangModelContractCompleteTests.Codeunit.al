namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Catalogue test for the message types of Bifrost Language Models: every type declares the contract chapters
/// Foundation requires, every error carries a machine code, the direction matches the effect, and the discovery
/// texts exist, differ from each other and have an Icelandic translation. The rules follow Foundation's
/// "Msg Type Conformance Tests" and the contract standard of Bifrost Foundation. A new type of this app is
/// covered without a change here.
/// </summary>
codeunit 96036 "LangModel Contract Compl Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        AppFirstOrdinalTok: Label '10035335', Locked = true;
        AppLastOrdinalTok: Label '10035484', Locked = true;

    /// <summary>
    /// Verifies that every message type of this app meets the contract, direction and discovery rules.
    /// </summary>
    [Test]
    procedure Catalogue_EveryType_MeetsContractAndDiscoveryRules()
    var
        Found: List of [Text];
        Entry: Text;
        Problems: Text;
        TypesChecked: Integer;
    begin
        // [SCENARIO] Every message type of Bifrost Language Models has a complete contract, a direction that matches its effect and translated discovery texts.
        CollectCatalogueProblems(Found, TypesChecked);

        Assert.IsTrue(TypesChecked > 0, 'The app contributes at least one message type to the catalogue.');
        foreach Entry in Found do
            Problems += Entry + ' ';
        Assert.AreEqual('', Problems, 'Contract or discovery gaps (Type|Rule): ' + Problems);
    end;

    /// <summary>
    /// Verifies that the completion type is part of the catalogue the other tests walk.
    /// </summary>
    [Test]
    procedure Catalogue_ContainsLLMPromptComplete()
    var
        TypeNames: List of [Text];
    begin
        // [SCENARIO] The catalogue walk reaches LLM.Prompt.Complete, so the rules are enforced for it.
        CollectTypeNames(TypeNames);

        Assert.IsTrue(TypeNames.Contains('LLM.Prompt.Complete'), 'LLM.Prompt.Complete is in the app range.');
    end;

    /// <summary>
    /// Verifies that a contract without a required chapter is reported once per chapter.
    /// </summary>
    [Test]
    procedure Rules_MissingChapters_AreReported()
    var
        Contract: JsonObject;
        Found: List of [Text];
    begin
        // [SCENARIO] A contract that declares only an envelope is missing every other required chapter.
        Contract.ReadFrom('{"envelope":{"version":"1.0"}}');

        CheckContract('Sales.Thing.Get', Contract, Found);

        Assert.IsTrue(Found.Contains('Sales.Thing.Get|Missing chapter parameters'), 'parameters');
        Assert.IsTrue(Found.Contains('Sales.Thing.Get|Missing chapter response'), 'response');
        Assert.IsTrue(Found.Contains('Sales.Thing.Get|Missing chapter errors'), 'errors');
        Assert.IsTrue(Found.Contains('Sales.Thing.Get|Missing chapter effect'), 'effect');
        Assert.IsTrue(Found.Contains('Sales.Thing.Get|Missing chapter examples'), 'examples');
        Assert.IsTrue(Found.Contains('Sales.Thing.Get|Missing chapter overview'), 'overview');
        Assert.IsTrue(Found.Contains('Sales.Thing.Get|Missing chapter related'), 'related');
        Assert.IsFalse(Found.Contains('Sales.Thing.Get|Missing chapter envelope'), 'The envelope is declared.');
    end;

    /// <summary>
    /// Verifies that an errors entry without a machine code, a condition or a next step is reported.
    /// </summary>
    [Test]
    procedure Rules_ErrorWithoutCodeWhenOrFix_IsReported()
    var
        Contract: JsonObject;
        Found: List of [Text];
    begin
        // [SCENARIO] Every errors entry carries a Bifrost Error Code name, a condition and a next step.
        Contract.ReadFrom('{"errors":[{"error":"No code","when":"x","fix":"y"},{"code":"MissingParameter","fix":"y"},{"code":"MissingParameter","when":"x"}]}');

        CheckContract('Sales.Thing.Get', Contract, Found);

        Assert.IsTrue(Found.Contains('Sales.Thing.Get|Error without code'), 'No code is reported.');
        Assert.IsTrue(Found.Contains('Sales.Thing.Get|Error without when'), 'No condition is reported.');
        Assert.IsTrue(Found.Contains('Sales.Thing.Get|Error without fix'), 'No next step is reported.');
    end;

    /// <summary>
    /// Verifies that an example without a real request or response object is reported.
    /// </summary>
    [Test]
    procedure Rules_ExampleWithoutRequestOrResponse_IsReported()
    var
        Contract: JsonObject;
        Found: List of [Text];
    begin
        // [SCENARIO] An example is a request and a response object, and the request names its message type.
        Contract.ReadFrom('{"examples":[{"title":"x"},{"title":"y","request":{"data":{}},"response":{"status":"Success"}}]}');

        CheckContract('Sales.Thing.Get', Contract, Found);

        Assert.IsTrue(Found.Contains('Sales.Thing.Get|Example without request'), 'No request is reported.');
        Assert.IsTrue(Found.Contains('Sales.Thing.Get|Example without response'), 'No response is reported.');
        Assert.IsTrue(Found.Contains('Sales.Thing.Get|Example request without type'), 'A request without its message type is reported.');
    end;

    /// <summary>
    /// Verifies that an effect that is not read, write or irreversible, or that has no changes text, is reported.
    /// </summary>
    [Test]
    procedure Rules_BadEffect_IsReported()
    var
        Contract: JsonObject;
        Found: List of [Text];
    begin
        // [SCENARIO] The effect chapter states one of the three effects and what changes.
        Contract.ReadFrom('{"effect":{"effect":"maybe"}}');

        CheckContract('Sales.Thing.Get', Contract, Found);

        Assert.IsTrue(Found.Contains('Sales.Thing.Get|Effect value'), 'An unknown effect is reported.');
        Assert.IsTrue(Found.Contains('Sales.Thing.Get|Effect without changes'), 'A missing changes text is reported.');
    end;

    /// <summary>
    /// Verifies that reads are Outbound and writes and irreversible effects are Inbound.
    /// </summary>
    [Test]
    procedure Rules_DirectionMustMatchEffect()
    begin
        // [SCENARIO] Foundation's convention: writes are Inbound, reads are Outbound.
        Assert.IsTrue(DirectionMatchesEffect('read', "Msg Direction ori"::Outbound), 'read is Outbound');
        Assert.IsFalse(DirectionMatchesEffect('read', "Msg Direction ori"::Inbound), 'read is not Inbound');
        Assert.IsTrue(DirectionMatchesEffect('write', "Msg Direction ori"::Inbound), 'write is Inbound');
        Assert.IsTrue(DirectionMatchesEffect('irreversible', "Msg Direction ori"::Inbound), 'irreversible is Inbound');
        Assert.IsFalse(DirectionMatchesEffect('write', "Msg Direction ori"::Outbound), 'write is not Outbound');
    end;

    /// <summary>
    /// Verifies the description rules: length, a third-person verb first and no implementation detail.
    /// </summary>
    [Test]
    procedure Rules_BadDescription_IsReported()
    var
        Found: List of [Text];
    begin
        // [SCENARIO] A description that is too short, does not start with a third-person verb or names a codeunit is reported.
        CheckDescription('Sales.Thing.Get', 'Thing', Found);
        Assert.IsTrue(Found.Contains('Sales.Thing.Get|Description length'), 'length');
        Assert.IsTrue(Found.Contains('Sales.Thing.Get|Description verb'), 'verb');

        Clear(Found);
        CheckDescription('Sales.Thing.Get', 'One-shot completion of a prompt through codeunit 10035396.', Found);
        Assert.IsTrue(Found.Contains('Sales.Thing.Get|Description verb'), 'A noun first is reported.');
        Assert.IsTrue(Found.Contains('Sales.Thing.Get|Description detail'), 'A codeunit is reported.');

        Clear(Found);
        CheckDescription('Sales.Thing.Get', 'Returns the thing for one customer.', Found);
        Assert.AreEqual(0, Found.Count(), 'A conforming description has no problem.');
    end;

    /// <summary>
    /// Verifies that a number from this app's object range in public text is reported.
    /// </summary>
    [Test]
    procedure Rules_ObjectNumberOfThisApp_IsReported()
    begin
        // [SCENARIO] Public help names no object of this app by number; Business Central numbers and neighbours pass.
        Assert.IsTrue(NamesAppObjectNumber('see codeunit 10035396'), 'inside the range');
        Assert.IsTrue(NamesAppObjectNumber('10035335'), 'first number');
        Assert.IsTrue(NamesAppObjectNumber('(10035484)'), 'last number');
        Assert.IsFalse(NamesAppObjectNumber('table 112 and 10035334 and 10035485 and 100353960'), 'Business Central numbers, neighbours and longer numbers pass');
    end;

    local procedure CollectCatalogueProblems(var Found: List of [Text]; var TypesChecked: Integer)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        MsgInterface: Interface "Msg Interface ori";
        Contract: JsonObject;
        FirstOrdinal: Integer;
        LastOrdinal: Integer;
        Ordinal: Integer;
        Index: Integer;
        TypeName: Text;
        SavedLanguage: Integer;
    begin
        Evaluate(FirstOrdinal, AppFirstOrdinalTok);
        Evaluate(LastOrdinal, AppLastOrdinalTok);
        SavedLanguage := GlobalLanguage();
        for Index := 1 to Enum::"Message Type ori".Ordinals().Count() do begin
            Ordinal := Enum::"Message Type ori".Ordinals().Get(Index);
            TypeName := Enum::"Message Type ori".Names().Get(Index);
            if (Ordinal >= FirstOrdinal) and (Ordinal <= LastOrdinal) then begin
                TypesChecked += 1;
                MessageType := Enum::"Message Type ori".FromInteger(Ordinal);
                MsgInterface := MessageType;
                GlobalLanguage(1033);
                if not ContractMgt.GetContract(MessageType, Contract) then
                    Found.Add(TypeName + '|Contract')
                else begin
                    CheckContract(TypeName, Contract, Found);
                    CheckDirection(TypeName, Contract, MsgInterface.GetMessageDirection(), Found);
                    CheckObjectNumbers(TypeName, Contract, Found);
                end;
                CheckDescription(TypeName, MsgInterface.GetDescription(), Found);
                CheckDiscovery(MessageType, TypeName, Found);
            end;
        end;
        GlobalLanguage(SavedLanguage);
    end;

    local procedure CollectTypeNames(var TypeNames: List of [Text])
    var
        FirstOrdinal: Integer;
        LastOrdinal: Integer;
        Ordinal: Integer;
        Index: Integer;
    begin
        Evaluate(FirstOrdinal, AppFirstOrdinalTok);
        Evaluate(LastOrdinal, AppLastOrdinalTok);
        for Index := 1 to Enum::"Message Type ori".Ordinals().Count() do begin
            Ordinal := Enum::"Message Type ori".Ordinals().Get(Index);
            if (Ordinal >= FirstOrdinal) and (Ordinal <= LastOrdinal) then
                TypeNames.Add(Enum::"Message Type ori".Names().Get(Index));
        end;
    end;

    local procedure CheckContract(TypeName: Text; Contract: JsonObject; var Found: List of [Text])
    var
        ChapterName: Text;
        RequiredChapters: List of [Text];
    begin
        RequiredChapters.AddRange('envelope', 'parameters', 'response', 'errors', 'effect', 'related', 'examples', 'overview');
        foreach ChapterName in RequiredChapters do
            if not Contract.Contains(ChapterName) then
                Found.Add(TypeName + '|Missing chapter ' + ChapterName);
        CheckParameters(TypeName, Contract, Found);
        CheckErrors(TypeName, Contract, Found);
        CheckEffect(TypeName, Contract, Found);
        CheckExamples(TypeName, Contract, Found);
    end;

    local procedure CheckParameters(TypeName: Text; Contract: JsonObject; var Found: List of [Text])
    var
        ChapterToken: JsonToken;
        EntryToken: JsonToken;
        Entry: JsonObject;
    begin
        if not Contract.Get('parameters', ChapterToken) then
            exit;
        if not ChapterToken.IsArray() then begin
            Found.Add(TypeName + '|Parameters not an array');
            exit;
        end;
        foreach EntryToken in ChapterToken.AsArray() do begin
            Entry := EntryToken.AsObject();
            if not (Entry.Contains('name') and Entry.Contains('type') and Entry.Contains('description')) then
                Found.Add(TypeName + '|Parameter without name, type or description');
        end;
    end;

    local procedure CheckErrors(TypeName: Text; Contract: JsonObject; var Found: List of [Text])
    var
        ChapterToken: JsonToken;
        EntryToken: JsonToken;
        Entry: JsonObject;
    begin
        if not Contract.Get('errors', ChapterToken) then
            exit;
        foreach EntryToken in ChapterToken.AsArray() do begin
            Entry := EntryToken.AsObject();
            if not Entry.Contains('code') then
                AddOnce(Found, TypeName + '|Error without code');
            if not Entry.Contains('when') then
                AddOnce(Found, TypeName + '|Error without when');
            if not Entry.Contains('fix') then
                AddOnce(Found, TypeName + '|Error without fix');
        end;
    end;

    local procedure CheckEffect(TypeName: Text; Contract: JsonObject; var Found: List of [Text])
    var
        ChapterToken: JsonToken;
        Effect: JsonObject;
        EffectValue: Text;
    begin
        if not Contract.Get('effect', ChapterToken) then
            exit;
        Effect := ChapterToken.AsObject();
        EffectValue := GetText(Effect, 'effect');
        if not (EffectValue in ['read', 'write', 'irreversible']) then
            Found.Add(TypeName + '|Effect value');
        if GetText(Effect, 'changes') = '' then
            Found.Add(TypeName + '|Effect without changes');
    end;

    local procedure CheckExamples(TypeName: Text; Contract: JsonObject; var Found: List of [Text])
    var
        ChapterToken: JsonToken;
        EntryToken: JsonToken;
        RequestToken: JsonToken;
        ResponseToken: JsonToken;
        Entry: JsonObject;
    begin
        if not Contract.Get('examples', ChapterToken) then
            exit;
        foreach EntryToken in ChapterToken.AsArray() do begin
            Entry := EntryToken.AsObject();
            if not Entry.Get('request', RequestToken) then
                AddOnce(Found, TypeName + '|Example without request')
            else
                if not RequestToken.IsObject() then
                    AddOnce(Found, TypeName + '|Example without request')
                else
                    if not RequestToken.AsObject().Contains('type') then
                        AddOnce(Found, TypeName + '|Example request without type');
            if not Entry.Get('response', ResponseToken) then
                AddOnce(Found, TypeName + '|Example without response')
            else
                if not ResponseToken.IsObject() then
                    AddOnce(Found, TypeName + '|Example without response');
        end;
    end;

    local procedure CheckDirection(TypeName: Text; Contract: JsonObject; Direction: Enum "Msg Direction ori"; var Found: List of [Text])
    var
        ChapterToken: JsonToken;
    begin
        if not Contract.Get('effect', ChapterToken) then
            exit;
        if not DirectionMatchesEffect(GetText(ChapterToken.AsObject(), 'effect'), Direction) then
            Found.Add(TypeName + '|Direction does not match effect');
    end;

    local procedure DirectionMatchesEffect(EffectValue: Text; Direction: Enum "Msg Direction ori"): Boolean
    begin
        if EffectValue = 'read' then
            exit(Direction = "Msg Direction ori"::Outbound);
        exit(Direction = "Msg Direction ori"::Inbound);
    end;

    local procedure CheckObjectNumbers(TypeName: Text; Contract: JsonObject; var Found: List of [Text])
    var
        ContractText: Text;
    begin
        Contract.WriteTo(ContractText);
        if NamesAppObjectNumber(ContractText) then
            Found.Add(TypeName + '|Object number of this app in the contract');
    end;

    local procedure CheckDescription(TypeName: Text; Description: Text; var Found: List of [Text])
    begin
        if (StrLen(Description) < 20) or (StrLen(Description) > 200) then
            Found.Add(TypeName + '|Description length');
        if not StartsWithVerb(Description) then
            Found.Add(TypeName + '|Description verb');
        if LowerCase(Description).Contains('codeunit') then
            Found.Add(TypeName + '|Description detail');
        if NamesAppObjectNumber(Description) then
            Found.Add(TypeName + '|Object number of this app in the description');
    end;

    local procedure StartsWithVerb(Description: Text): Boolean
    var
        FirstWord: Text;
    begin
        if Description = '' then
            exit(false);
        FirstWord := Description.Split(' ').Get(1);
        if FirstWord in ['This', 'Is', 'Has'] then
            exit(false);
        exit((FirstWord[1] in ['A' .. 'Z']) and FirstWord.EndsWith('s'));
    end;

    local procedure CheckDiscovery(MessageType: Enum "Message Type ori"; TypeName: Text; var Found: List of [Text])
    var
        EnglishDescription: Text;
        EnglishKeywords: Text;
        EnglishSelection: Text;
        IcelandicDescription: Text;
        IcelandicKeywords: Text;
        IcelandicSelection: Text;
        SavedLanguage: Integer;
        Succeeded: Boolean;
    begin
        SavedLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        Succeeded := TryReadDiscovery(MessageType, EnglishDescription, EnglishKeywords, EnglishSelection);
        GlobalLanguage(1039);
        if Succeeded then
            Succeeded := TryReadDiscovery(MessageType, IcelandicDescription, IcelandicKeywords, IcelandicSelection);
        GlobalLanguage(SavedLanguage);
        if not Succeeded then begin
            Found.Add(TypeName + '|Discovery unreadable');
            exit;
        end;
        if EnglishKeywords = '' then
            Found.Add(TypeName + '|Keywords missing');
        if EnglishSelection = '' then
            Found.Add(TypeName + '|Selection description missing');
        if (EnglishSelection <> '') and (EnglishSelection = EnglishDescription) then
            Found.Add(TypeName + '|Selection description equals description');
        if IcelandicDescription = EnglishDescription then
            Found.Add(TypeName + '|Description not translated');
        if IcelandicKeywords = EnglishKeywords then
            Found.Add(TypeName + '|Keywords not translated');
        if IcelandicSelection = EnglishSelection then
            Found.Add(TypeName + '|Selection description not translated');
        if IcelandicKeywords.Split(',').Count() < EnglishKeywords.Split(',').Count() then
            Found.Add(TypeName + '|Icelandic keywords shorter than English');
    end;

    [TryFunction]
    local procedure TryReadDiscovery(MessageType: Enum "Message Type ori"; var Description: Text; var Keywords: Text; var Selection: Text)
    var
        MsgInterface: Interface "Msg Interface ori";
        Discovery: Interface "Msg Discovery ori";
    begin
        MsgInterface := MessageType;
        Discovery := MessageType;
        Description := MsgInterface.GetDescription();
        Keywords := Discovery.GetKeywords();
        Selection := Discovery.GetSelectionDescription();
    end;

    /// <summary>
    /// True when the text holds a number from the object range of this app (10035335 to 10035484) on its own,
    /// not as part of a longer number. Business Central numbers such as 112 are allowed in public help.
    /// </summary>
    local procedure NamesAppObjectNumber(Value: Text): Boolean
    var
        FirstNumber: Integer;
        LastNumber: Integer;
        Number: Integer;
        Run: Text;
        Index: Integer;
    begin
        Evaluate(FirstNumber, AppFirstOrdinalTok);
        Evaluate(LastNumber, AppLastOrdinalTok);
        Value += ' ';
        for Index := 1 to StrLen(Value) do
            if Value[Index] in ['0' .. '9'] then
                Run += CopyStr(Value, Index, 1)
            else begin
                if StrLen(Run) = 8 then begin
                    Evaluate(Number, Run);
                    if (Number >= FirstNumber) and (Number <= LastNumber) then
                        exit(true);
                end;
                Run := '';
            end;
        exit(false);
    end;

    local procedure GetText(Source: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Source.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure AddOnce(var Found: List of [Text]; Problem: Text)
    begin
        if not Found.Contains(Problem) then
            Found.Add(Problem);
    end;
}
