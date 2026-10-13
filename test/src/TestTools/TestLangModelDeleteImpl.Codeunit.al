namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;

/// <summary>
/// Test.LanguageModel.Delete - deletes the named language models and their stored API keys. Request:
/// { "codes": ["BIFT-OPENAI", ...] }. A code that does not exist is reported as not found and skipped.
/// Test app only; refused in SaaS production.
/// </summary>
codeunit 96025 "Test LangModel Delete Impl" implements "Msg Interface ori"
{
    Access = Internal;

    var
        Tools: Codeunit "LangModel Test Tools";
        MissingCodesErr: Label 'Send "codes", an array of language model codes.', Locked = true;

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
