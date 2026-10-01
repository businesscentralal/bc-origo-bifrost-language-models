namespace Origo.Bifrost.LanguageModels;

using Origo.Bifrost;

/// <summary>
/// Restricts generic writes to the endpoint fields of Bifrost Language Model ori through
/// Bifrost Foundation's Data.Records field events. Each language model row holds an endpoint
/// (Base URL plus Chat Path and Models Path); the provider API key is stored separately in the
/// secret store and added to every request as a header. A caller who can change the endpoint
/// through Data.Records.Set can make Bifr\u00f6st send that API key to a server of their choice,
/// so the three endpoint fields are write-blocked for the generic data API. Reading the fields
/// stays allowed, and the language model card, list, setup page and the chat/prompt message types
/// (which fill these fields from code) are unaffected - they do not go through Data.Records.Set.
/// </summary>
codeunit 10035408 "LangModel Field Restrict ori"
{
    Access = Internal;

    /// <summary>
    /// Raises the dedicated message-type hint for the endpoint fields so the write-block error
    /// names the card / setup page as the place to change them. No dedicated message type writes
    /// the endpoint, so the hint points at the setup surfaces instead.
    /// </summary>
    var
        EndpointFieldsHintTok: Label 'Use the Language Model card or setup page to change the endpoint fields.', Comment = 'is-IS=Not\u00ed\u00f0u m\u00e1ll\u00edkumort e\u00f0a\u00f0\u00ed\u00f0 \u00e1 st\u00f3r \u00ed\u00f0 uppl\u00f3stings\u00ed\u00f0 \u00e1 st\u00f3r \u00ed\u00f0 endpoint reitarnar.';

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsFieldWriteRestrictedForDataRecords, '', false, false)]
    local procedure OnAfterIsFieldWriteRestricted(TableNo: Integer; FieldNo: Integer; var IsRestricted: Boolean)
    begin
        if (TableNo = Database::"Bifrost Language Model ori") and (FieldNo in [20, 24, 25]) then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnGetDedicatedMessageTypeHintForField, '', false, false)]
    local procedure OnGetDedicatedMessageTypeHintForField(TableNo: Integer; FieldNo: Integer; var Hint: Text)
    begin
        if (TableNo = Database::"Bifrost Language Model ori") and (FieldNo in [20, 24, 25]) then
            Hint := EndpointFieldsHintTok;
    end;
}
