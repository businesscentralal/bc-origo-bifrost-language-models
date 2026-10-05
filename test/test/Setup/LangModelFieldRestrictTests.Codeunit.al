namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests for the Data.Records field-write restrictions on Bifrost Language Model ori's endpoint
/// fields (Base URL 20, Chat Path 24, Models Path 25) added by "LangModel Field Restrict ori"
/// (language-models#49, core#344). The endpoint holds the address that the provider API key is
/// sent to, so the generic data API must not let a caller point it elsewhere. Reading stays open
/// and the neighbouring fields are untouched. The field flags are read through the public
/// Help.Fields.Get message type, the same decision Data.Records.Get and Data.Records.Set take (#51).
/// </summary>
codeunit 96004 "LangModel Field Restrict Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        EndpointHintTxt: Label 'Use the Bifrost Language Model card or the Bifrost Language Models setup page to change the endpoint fields.', Locked = true;

    [Test]
    procedure FieldRestrict_ThreeEndpointFieldsWriteRestricted()
    var
        Flags: Dictionary of [Integer, JsonObject];
    begin
        // [SCENARIO] TC001 / AC01: the three endpoint fields are write-restricted.
        // [WHEN] Help.Fields.Get reports the endpoint fields
        GetFieldFlags('[20,24,25]', Flags);

        // [THEN] Base URL, Chat Path and Models Path are all write-restricted
        Assert.IsTrue(FlagOf(Flags, 20, 'writeRestricted'), 'Base URL (20) should be write-restricted.');
        Assert.IsTrue(FlagOf(Flags, 24, 'writeRestricted'), 'Chat Path (24) should be write-restricted.');
        Assert.IsTrue(FlagOf(Flags, 25, 'writeRestricted'), 'Models Path (25) should be write-restricted.');
    end;

    [Test]
    procedure FieldRestrict_EndpointFieldsNotReadRestricted()
    var
        Flags: Dictionary of [Integer, JsonObject];
    begin
        // [SCENARIO] TC002 / AC02: the same three fields stay readable.
        GetFieldFlags('[20,24,25]', Flags);

        Assert.IsFalse(FlagOf(Flags, 20, 'readRestricted'), 'Base URL (20) must stay readable.');
        Assert.IsFalse(FlagOf(Flags, 24, 'readRestricted'), 'Chat Path (24) must stay readable.');
        Assert.IsFalse(FlagOf(Flags, 25, 'readRestricted'), 'Models Path (25) must stay readable.');
    end;

    [Test]
    procedure FieldRestrict_NeighbourFieldsNotRestricted()
    var
        Flags: Dictionary of [Integer, JsonObject];
    begin
        // [SCENARIO] TC003 / AC03: the fields next to the endpoint are not affected.
        GetFieldFlags('[1,12,21,22]', Flags);

        Assert.IsFalse(FlagOf(Flags, 1, 'writeRestricted'), 'Code (1) must stay writable.');
        Assert.IsFalse(FlagOf(Flags, 12, 'writeRestricted'), 'Chat Provider (12) must stay writable.');
        Assert.IsFalse(FlagOf(Flags, 21, 'writeRestricted'), 'Model (21) must stay writable.');
        Assert.IsFalse(FlagOf(Flags, 22, 'writeRestricted'), 'Timeout Seconds (22) must stay writable.');
    end;

    [Test]
    procedure FieldRestrict_TableLevelChecksStayFalse()
    var
        TempArgument: Record "Message Argument ori" temporary;
    begin
        // [SCENARIO] TC004 / AC04: the restrictions are field-level only.
        Assert.IsFalse(TempArgument.IsTableReadRestrictedForDataRecords(Database::"Bifrost Language Model ori"), 'Table read must stay open.');
        Assert.IsFalse(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Bifrost Language Model ori", false), 'Table write must stay open.');
    end;

    [Test]
    procedure FieldRestrict_HintForEndpointFieldsEmptyForNeighbour()
    var
        TempArgument: Record "Message Argument ori" temporary;
    begin
        // [SCENARIO] TC005 / AC05: the endpoint fields carry the documented hint; a neighbour does not.
        Assert.AreEqual(EndpointHintTxt, TempArgument.GetDedicatedMessageTypeHintForField(Database::"Bifrost Language Model ori", 20), 'Base URL (20) hint.');
        Assert.AreEqual(EndpointHintTxt, TempArgument.GetDedicatedMessageTypeHintForField(Database::"Bifrost Language Model ori", 24), 'Chat Path (24) hint.');
        Assert.AreEqual(EndpointHintTxt, TempArgument.GetDedicatedMessageTypeHintForField(Database::"Bifrost Language Model ori", 25), 'Models Path (25) hint.');
        Assert.AreEqual('', TempArgument.GetDedicatedMessageTypeHintForField(Database::"Bifrost Language Model ori", 21), 'Model (21) must have no hint.');
    end;

    /// <summary>
    /// Runs Help.Fields.Get for the given field numbers of Bifrost Language Model ori and returns each field's entry by number.
    /// </summary>
    local procedure GetFieldFlags(FieldNumbersJson: Text; var Flags: Dictionary of [Integer, JsonObject])
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        MessageVersion: Enum "Message Version ori";
        ResponseContentType: Text[100];
        ResponseText: Text;
        ResponseJson: JsonObject;
        ResultToken: JsonToken;
        FieldToken: JsonToken;
    begin
        RequestContent.AddText(StrSubstNo('{"tableNumber":%1,"fieldNumbers":%2}', Format(Database::"Bifrost Language Model ori", 0, 9), FieldNumbersJson));
        Dispatcher.Execute("Message Type ori"::"Help.Fields.Get", MessageVersion::"1.0", '', '', 'text/json', RequestContent, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        Assert.IsTrue(ResponseJson.ReadFrom(ResponseText), ResponseText);
        Assert.IsTrue(ResponseJson.Get('result', ResultToken), 'Help.Fields.Get answers a result: ' + ResponseText);
        foreach FieldToken in ResultToken.AsArray() do
            Flags.Add(FieldToken.AsObject().GetInteger('id'), FieldToken.AsObject());
    end;

    local procedure FlagOf(Flags: Dictionary of [Integer, JsonObject]; FieldNo: Integer; FlagName: Text): Boolean
    begin
        Assert.IsTrue(Flags.ContainsKey(FieldNo), StrSubstNo('Help.Fields.Get lists field %1.', FieldNo));
        exit(Flags.Get(FieldNo).GetBoolean(FlagName));
    end;
}
