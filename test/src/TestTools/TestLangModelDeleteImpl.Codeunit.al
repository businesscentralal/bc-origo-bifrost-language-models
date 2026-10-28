namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;

/// <summary>
/// Test.LanguageModel.Delete - deletes the named language models and their stored API keys. Request:
/// { "codes": ["BIFT-OPENAI", ...] }. A code that does not exist is reported as not found and skipped.
/// Test app only; refused in SaaS production.
/// </summary>
codeunit 96025 "Test LangModel Delete Impl" implements "Msg Interface ori", "Msg Contract ori"
{
    Access = Internal;

    var
        Tools: Codeunit "LangModel Test Tools";
        MissingCodesErr: Label 'Send "codes", an array of language model codes.', Locked = true;

    /// <summary>
    /// Declares the JSON request envelope of this test-only type.
    /// </summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        Envelope.Add('dataRequired', true);
        exit(true);
    end;

    /// <summary>
    /// Returns false because models are selected by data parameters, not a subject.
    /// </summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>
    /// Declares every supported request key and its actual shape.
    /// </summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('codes', 'array', true, 'Language model codes to delete together with their keys. Unknown codes are reported in notFound.'));
        exit(true);
    end;

    /// <summary>
    /// Describes successful output without exposing credentials.
    /// </summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success after processing the codes.'));
        Fields.Add(ContractMgt.ResponseField('deleted', 'array', 'Codes that were deleted.'));
        Fields.Add(ContractMgt.ResponseField('notFound', 'array', 'Codes that did not exist.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>
    /// Describes the coded refusals of the test operation.
    /// </summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Test message types do not run in a SaaS production environment.', 'The environment is SaaS production.', 'Use a sandbox or development container.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'Send codes, an array of language model codes.', 'codes is absent or is not an array.', 'Supply the codes array.'));
        exit(true);
    end;

    /// <summary>
    /// States the actual writes, external effects and commit behavior.
    /// </summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Deletes the named language models and clears their shared and caller personal key values. Unknown codes are reported. No explicit commit.');
        Effect.Add('idempotent', true);
        exit(true);
    end;

    /// <summary>
    /// Uses Foundation metering without additional declarations.
    /// </summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>
    /// Returns false because no related chapter is supplied.
    /// </summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>
    /// Returns false because this test tool has no workflow chapter.
    /// </summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>
    /// Returns false because usage examples are in the test tooling.
    /// </summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>
    /// Describes this test-only operation.
    /// </summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := GetDescription();
        exit(true);
    end;

    /// <summary>
    /// States the test-only environment and data boundaries.
    /// </summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Test app only. Refused in SaaS production. Runs with the caller permissions; never use customer fixtures or send real credentials through MCP.';
        exit(true);
    end;

    /// <summary>
    /// Reports that this test-only message type is enabled.
    /// </summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>
    /// Returns the language model table number used by this test-only message type.
    /// </summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Bifrost Language Model ori");
    end;

    /// <summary>
    /// Describes the test-only language model delete operation.
    /// </summary>
    procedure GetDescription(): Text[250]
    begin
        exit('TEST ONLY: deletes language models and their stored API keys.');
    end;

    /// <summary>
    /// Returns Inbound for this test-only message type.
    /// </summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>
    /// Deletes the requested language models and reports unknown codes after refusing production execution.
    /// </summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        LanguageModel: Record "Bifrost Language Model ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        CodesToken: JsonToken;
        CodeToken: JsonToken;
        Deleted: JsonArray;
        NotFound: JsonArray;
        ModelCode: Text;
    begin
        if not Tools.AssertNotProduction(Argument) then
            exit;

        RequestJson := Argument.GetRequestJson();
        if not (RequestJson.Get('codes', CodesToken) and CodesToken.IsArray()) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingCodesErr, 'codes', '', 'an array of language model codes', '');
            exit;
        end;

        foreach CodeToken in CodesToken.AsArray() do begin
            ModelCode := UpperCase(Argument.TokenAsText(CodeToken));
            if (StrLen(ModelCode) <= MaxStrLen(LanguageModel.Code)) and LanguageModel.Get(CopyStr(ModelCode, 1, MaxStrLen(LanguageModel.Code))) then begin
                LanguageModel.Delete(true);
                Deleted.Add(ModelCode);
            end else
                NotFound.Add(ModelCode);
        end;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('deleted', Deleted);
        ResponseJson.Add('notFound', NotFound);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
