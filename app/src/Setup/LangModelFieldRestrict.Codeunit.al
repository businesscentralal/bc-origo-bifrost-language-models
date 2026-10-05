namespace Origo.Bifrost.LanguageModels;

using Origo.Bifrost;

/// <summary>
/// Restricts generic writes to the endpoint fields of Bifrost Language Model ori through
/// Bifrost Foundation's Data.Records field events. Each language model row holds an endpoint
/// (Base URL plus Chat Path and Models Path); the provider API key is stored separately in the
/// secret store and added to every request as a header. A caller who can change the endpoint
/// through Data.Records.Set can make Bifrost send that API key to a server of their choice,
/// so the three endpoint fields are write-blocked for the generic data API, also with force.
/// Reading the fields stays allowed, and the language model card, list, setup page and the
/// install code (which fill these fields directly) are unaffected - they do not go through
/// Data.Records.Set.
/// </summary>
codeunit 10035408 "LangModel Field Restrict ori"
{
    Access = Internal;

    var
        EndpointFieldsHintTxt: Label 'Use the Bifrost Language Model card or the Bifrost Language Models setup page to change the endpoint fields.', Comment = 'is-IS=Notaðu spjald Bifröst mállíkansins eða uppsetningarsíðu Bifröst mállíkana til að breyta slóðarreitunum.';

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsFieldWriteRestrictedForDataRecords, '', false, false)]
    local procedure OnAfterIsFieldWriteRestricted(TableNo: Integer; FieldNo: Integer; var IsRestricted: Boolean)
    begin
        if IsEndpointField(TableNo, FieldNo) then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnGetDedicatedMessageTypeHintForField, '', false, false)]
    local procedure OnGetDedicatedMessageTypeHintForField(TableNo: Integer; FieldNo: Integer; var Hint: Text)
    begin
        // No message type writes the endpoint, so the hint names the pages that do.
        if IsEndpointField(TableNo, FieldNo) then
            Hint := EndpointFieldsHintTxt;
    end;

    local procedure IsEndpointField(TableNo: Integer; FieldNo: Integer): Boolean
    var
        LanguageModel: Record "Bifrost Language Model ori";
    begin
        if TableNo <> Database::"Bifrost Language Model ori" then
            exit(false);
        exit(FieldNo in [LanguageModel.FieldNo("Base URL"), LanguageModel.FieldNo("Chat Path"), LanguageModel.FieldNo("Models Path")]);
    end;
}
