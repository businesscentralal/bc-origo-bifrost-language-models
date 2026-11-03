namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests that the Ask tool policy runs for a session that holds only BIFROST API ori, BIFROST Chat ori and BIFROST LLM Chat ori (language-models#100 AC10).
/// </summary>
codeunit 96043 "LLM Ask Tool Policy Perm Tests"
{
    Subtype = Test;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Policy_RunsWithTheLlmChatBaseline_1033()
    begin
        VerifyPolicyRuns(1033);
    end;

    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Policy_RunsWithTheLlmChatBaseline_1039()
    begin
        VerifyPolicyRuns(1039);
    end;

    local procedure VerifyPolicyRuns(LanguageId: Integer)
    var
        Policy: Codeunit "LLM Ask Tool Policy ori";
        Server: Codeunit "MCP Tool Server ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
        ServerTools: JsonArray;
        Caller: JsonObject;
        Arguments: JsonObject;
        Allowed: List of [Text];
        Warnings: List of [Text];
        Filtered: JsonArray;
        Reason: Text;
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        LibraryLowerPermissions.SetO365Basic();
        LibraryLowerPermissions.AddPermissionSet('BIFROST API ori');
        LibraryLowerPermissions.AddPermissionSet('BIFROST Chat ori');
        LibraryLowerPermissions.AddPermissionSet('BIFROST LLM Chat ori');

        Server.ListTools(ServerTools);
        Policy.GetAllowedToolNames(ServerTools, Caller, Allowed, Warnings);
        Policy.FilterToolDefinitions(ServerTools, Allowed, Filtered);
        Assert.IsTrue(Filtered.Count() > 0, 'Tools are offered');
        Arguments.Add('type', 'Help.WhoAmI.Get');
        Assert.IsTrue(Policy.CheckToolCall('invoke_message_type', Arguments, Caller, Reason), 'A read type passes the call-time check: ' + Reason);
        Clear(Arguments);
        Assert.IsFalse(Policy.CheckToolCall('set_records', Arguments, Caller, Reason), 'A write tool is denied');

        GlobalLanguage(PreviousLanguage);
    end;
}
