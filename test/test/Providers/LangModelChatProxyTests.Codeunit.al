namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests the decision to resend a chat request with reasoning_effort none: tools plus the provider's
/// "set reasoning_effort to 'none'" error, and the two cases that must not retry.
/// </summary>
codeunit 96029 "LangModel Chat Proxy Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        ReasoningOffErrTxt: Label 'Function tools with reasoning_effort are not supported. Set reasoning_effort to ''none''.', Locked = true;

    /// <summary>
    /// A tool request retries when the provider asks for reasoning_effort none.
    /// </summary>
    [Test]
    procedure NeedsReasoningOff_ToolsAndMatchingError_IsTrue()
    var
        Proxy: Codeunit "LangModel Chat Proxy ori";
        RequestBody: JsonObject;
    begin
        // [SCENARIO] a refused tool request whose error asks for reasoning_effort 'none' is resent once
        RequestBody.Add('tools', ToolArray());

        Assert.IsTrue(Proxy.NeedsReasoningOff(RequestBody, ReasoningOffErrTxt), 'Tools plus the reasoning_effort none error');
    end;

    /// <summary>
    /// A request without tools does not retry with reasoning_effort none.
    /// </summary>
    [Test]
    procedure NeedsReasoningOff_NoTools_IsFalse()
    var
        Proxy: Codeunit "LangModel Chat Proxy ori";
        RequestBody: JsonObject;
    begin
        // [SCENARIO] a request without tools never receives reasoning_effort, even when the error mentions it
        RequestBody.Add('model', 'gpt-6-sol');

        Assert.IsFalse(Proxy.NeedsReasoningOff(RequestBody, ReasoningOffErrTxt), 'No tools');
    end;

    /// <summary>
    /// A request with reasoning_effort already set does not retry.
    /// </summary>
    [Test]
    procedure NeedsReasoningOff_AlreadySet_IsFalse()
    var
        Proxy: Codeunit "LangModel Chat Proxy ori";
        RequestBody: JsonObject;
    begin
        // [SCENARIO] a request that already carries reasoning_effort is not resent
        RequestBody.Add('tools', ToolArray());
        RequestBody.Add('reasoning_effort', 'none');

        Assert.IsFalse(Proxy.NeedsReasoningOff(RequestBody, ReasoningOffErrTxt), 'reasoning_effort already set');
    end;

    /// <summary>
    /// An unrelated provider error does not trigger a reasoning retry.
    /// </summary>
    [Test]
    procedure NeedsReasoningOff_UnrelatedError_IsFalse()
    var
        Proxy: Codeunit "LangModel Chat Proxy ori";
        RequestBody: JsonObject;
    begin
        // [SCENARIO] a tool request that failed for another reason is not resent with reasoning_effort
        RequestBody.Add('tools', ToolArray());

        Assert.IsFalse(Proxy.NeedsReasoningOff(RequestBody, 'LLM API returned status 429.'), 'Unrelated error');
    end;

    local procedure ToolArray() Tools: JsonArray
    var
        Tool: JsonObject;
    begin
        Tool.Add('type', 'function');
        Tools.Add(Tool);
    end;
}
