namespace Origo.Bifrost.LanguageModels;

using Origo.Bifrost;

/// <summary>
/// Runs one tool call of LLM.Prompt.Ask (#171) through Foundation's MCP Tool Server, so that the runner can call it with
/// "if not Codeunit.Run": a runtime error inside the tool (for example a JSON cast or an overflow) becomes a tool error
/// that the model reads, instead of ending the whole run with an uncoded error.
/// </summary>
codeunit 10035447 "LLM Ask Tool Call ori"
{
    Access = Internal;

    var
        ToolName: Text;
        Arguments: JsonObject;
        ResultText: Text;
        IsError: Boolean;

    trigger OnRun()
    var
        ToolServer: Codeunit "MCP Tool Server ori";
        Handled: Boolean;
    begin
        ResultText := '';
        IsError := false;
        OnBeforeCallTool(ToolName, Arguments, ResultText, IsError, Handled);
        if not Handled then
            ToolServer.CallTool(ToolName, Arguments, ResultText, IsError);
    end;

    /// <summary>
    /// Sets the tool and its arguments for the next run.
    /// </summary>
    /// <param name="NewToolName">The tool the model asked for.</param>
    /// <param name="NewArguments">The tool arguments; always an object (the runner replaces any other JSON type by an empty object).</param>
    procedure SetCall(NewToolName: Text; NewArguments: JsonObject)
    begin
        ToolName := NewToolName;
        Arguments := NewArguments;
    end;

    /// <summary>
    /// Returns the tool result of the last successful run.
    /// </summary>
    /// <param name="ToolResultText">Receives the result text; any JSON type or plain text.</param>
    /// <param name="ToolIsError">Receives true when the tool server marked the result as an error.</param>
    procedure GetResult(var ToolResultText: Text; var ToolIsError: Boolean)
    begin
        ToolResultText := ResultText;
        ToolIsError := IsError;
    end;

    /// <summary>Test hook (#171): answers or fails a tool call instead of the MCP Tool Server.</summary>
    [IntegrationEvent(false, false)]
    local procedure OnBeforeCallTool(CallToolName: Text; CallArguments: JsonObject; var CallResultText: Text; var CallIsError: Boolean; var Handled: Boolean)
    begin
    end;
}
