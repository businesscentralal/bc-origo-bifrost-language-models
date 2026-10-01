namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;

/// <summary>
/// Tests for the Data.Records field-write restrictions on Bifrost Language Model ori's endpoint
/// fields (Base URL 20, Chat Path 24, Models Path 25) added by "LangModel Field Restrict ori"
/// (language-models#49, core#344). The endpoint holds the address that the provider API key is
/// sent to, so the generic data API must not let a caller point it elsewhere. Reading stays open
/// and the neighbouring fields are untouched.
/// </summary>
codeunit 96004 "LangModel Field Restrict Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    local procedure Initialize()
    begin
    end;

    [Test]
    procedure FieldRestrict_ThreeEndpointFieldsWriteRestricted()
    var
        Argument: Record "Message Argument ori";
    begin
        // [SCENARIO] TC001 / AC01: the three endpoint fields are write-restricted.
        Initialize();

        // [WHEN] the generic data API checks the endpoint fields for write access
        // [THEN] Base URL, Chat Path and Models Path are all restricted
        Assert.IsTrue(Argument.IsFieldWriteRestrictedForDataRecords(Database::"Bifrost Language Model ori", 20), 'Base URL (20) should be write-restricted.');
        Assert.IsTrue(Argument.IsFieldWriteRestrictedForDataRecords(Database::"Bifrost Language Model ori", 24), 'Chat Path (24) should be write-restricted.');
        Assert.IsTrue(Argument.IsFieldWriteRestrictedForDataRecords(Database::"Bifrost Language Model ori", 25), 'Models Path (25) should be write-restricted.');
    end;

    [Test]
    procedure FieldRestrict_EndpointFieldsNotReadRestricted()
    var
        Argument: Record "Message Argument ori";
    begin
        // [SCENARIO] TC002 / AC02: the same three fields stay readable.
        Initialize();

        // [WHEN] the generic data API checks the endpoint fields for read access
        // [THEN] none of the three is read-restricted
        Assert.IsFalse(Argument.IsFieldReadRestrictedForDataRecords(Database::"Bifrost Language Model ori", 20), 'Base URL (20) must stay readable.');
        Assert.IsFalse(Argument.IsFieldReadRestrictedForDataRecords(Database::"Bifrost Language Model ori", 24), 'Chat Path (24) must stay readable.');
        Assert.IsFalse(Argument.IsFieldReadRestrictedForDataRecords(Database::"Bifrost Language Model ori", 25), 'Models Path (25) must stay readable.');
    end;

    [Test]
    procedure FieldRestrict_NeighbourFieldsNotRestricted()
    var
        Argument: Record "Message Argument ori";
    begin
        // [SCENARIO] TC003 / AC03: the fields next to the endpoint are not affected.
        Initialize();

        // [WHEN] the generic data API checks the neighbouring fields
        // [THEN] Code, Chat Provider, Model and Timeout Seconds are all still writable and readable
        Assert.IsFalse(Argument.IsFieldWriteRestrictedForDataRecords(Database::"Bifrost Language Model ori", 1), 'Code (1) must stay writable.');
        Assert.IsFalse(Argument.IsFieldWriteRestrictedForDataRecords(Database::"Bifrost Language Model ori", 12), 'Chat Provider (12) must stay writable.');
        Assert.IsFalse(Argument.IsFieldWriteRestrictedForDataRecords(Database::"Bifrost Language Model ori", 21), 'Model (21) must stay writable.');
        Assert.IsFalse(Argument.IsFieldWriteRestrictedForDataRecords(Database::"Bifrost Language Model ori", 22), 'Timeout Seconds (22) must stay writable.');
    end;

    [Test]
    procedure FieldRestrict_TableLevelChecksStayFalse()
    var
        Argument: Record "Message Argument ori";
    begin
        // [SCENARIO] TC004 / AC04: the restrictions are field-level only.
        Initialize();

        // [WHEN] the generic data API checks the table-level access for Bifrost Language Model ori
        // [THEN] neither the table read nor the table write is restricted
        Assert.IsFalse(Argument.IsTableReadRestrictedForDataRecords(Database::"Bifrost Language Model ori"), 'Table read must stay open.');
        Assert.IsFalse(Argument.IsTableWriteRestrictedForDataRecords(Database::"Bifrost Language Model ori"), 'Table write must stay open.');
    end;

    [Test]
    procedure FieldRestrict_HintForEndpointFieldsEmptyForNeighbour()
    var
        Argument: Record "Message Argument ori";
    begin
        // [SCENARIO] TC005 / AC05: the endpoint fields carry the documented hint; a neighbour does not.
        Initialize();

        // [WHEN] the generic data API asks for the dedicated message-type hint
        // [THEN] each endpoint field returns the setup-surface hint and field 21 (Model) returns ''
        Assert.AreEqual('Use the Language Model card or setup page to change the endpoint fields.', Argument.GetDedicatedMessageTypeHintForField(Database::"Bifrost Language Model ori", 20), 'Base URL (20) hint.');
        Assert.AreEqual('Use the Language Model card or setup page to change the endpoint fields.', Argument.GetDedicatedMessageTypeHintForField(Database::"Bifrost Language Model ori", 24), 'Chat Path (24) hint.');
        Assert.AreEqual('Use the Language Model card or setup page to change the endpoint fields.', Argument.GetDedicatedMessageTypeHintForField(Database::"Bifrost Language Model ori", 25), 'Models Path (25) hint.');
        Assert.AreEqual('', Argument.GetDedicatedMessageTypeHintForField(Database::"Bifrost Language Model ori", 21), 'Model (21) must have no hint.');
    end;
}
