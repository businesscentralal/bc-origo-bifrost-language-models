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
    /// Verifies that tools and the matching provider error make the request eligible for a reasoning-off retry.
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
    /// Verifies that a request without tools is ineligible for a reasoning-off retry even when the provider error matches.
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
    /// Verifies that a request already carrying reasoning_effort is ineligible for another reasoning-off retry.
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
    /// Verifies that a tool request with an unrelated provider error is ineligible for a reasoning-off retry.
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
