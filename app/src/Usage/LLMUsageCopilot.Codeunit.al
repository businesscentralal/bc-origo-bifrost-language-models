namespace Origo.Bifrost.LanguageModels;

using System.AI;

/// <summary>One instrumented managed Copilot request, shared by chat and one-shot completions.</summary>
codeunit 10035443 "LLM Usage Copilot ori"
{
    Access = Internal;

    /// <summary>Calls Copilot once and records numeric usage when exposed by the managed response.</summary>
    procedure Generate(var AzureOpenAI: Codeunit "Azure OpenAI"; var Messages: Codeunit "AOAI Chat Messages"; var Parameters: Codeunit "AOAI Chat Completion Params"; var Operation: Codeunit "AOAI Operation Response"): Boolean
    var
        TempEntry: Record "LLM Usage Log ori" temporary;
        Usage: Codeunit "LLM Usage Recorder ori";
        Deployments: Codeunit "AOAI Deployments";
        Response: JsonObject;
        ResponseText: Text;
        Handled: Boolean;
        Success: Boolean;
        Status: Integer;
    begin
        Usage.BeginCall(TempEntry);
        TempEntry."Model ID" := CopyStr(Deployments.GetGPT41Latest(), 1, MaxStrLen(TempEntry."Model ID"));
        OnBeforeGenerate(Handled, Success, Status, ResponseText);
        if not Handled then
            if TryGenerate(AzureOpenAI, Messages, Parameters, Operation) then begin
                Success := Operation.IsSuccess();
                Status := Operation.GetStatusCode();
                ResponseText := Operation.GetResult();
            end;
        if not Response.ReadFrom(ResponseText) then
            Clear(Response);
        Usage.FinishCall(TempEntry, Response, Success, Status);
        exit(Success);
    end;

    [TryFunction]
    local procedure TryGenerate(var AzureOpenAI: Codeunit "Azure OpenAI"; var Messages: Codeunit "AOAI Chat Messages"; var Parameters: Codeunit "AOAI Chat Completion Params"; var Operation: Codeunit "AOAI Operation Response")
    begin
        AzureOpenAI.GenerateChatCompletion(Messages, Parameters, Operation);
    end;

    [InternalEvent(false, false)]
    local procedure OnBeforeGenerate(var Handled: Boolean; var Success: Boolean; var Status: Integer; var ResponseText: Text)
    begin
    end;
}
