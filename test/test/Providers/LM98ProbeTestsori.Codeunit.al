namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>Native checks for the private LM98 probe; no live credentials or providers are used.</summary>
codeunit 96052 "LM98 Probe Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Probe: Codeunit "LM98 Probe ori";

    /// <summary>AC04: replacement preserves text after the first empty line and removes the stale clock.</summary>
    [Test]
    procedure AC04_ReplaceCachedBlockPreservesSuffix()
    var
        Prompt: TextBuilder;
        Replacement: TextBuilder;
        Actual: Text;
    begin
        Prompt.AppendLine('Synthetic prefix');
        Prompt.AppendLine('SESSION TIME (cached):');
        Prompt.AppendLine('- Now UTC: 2020-01-01T00:00:00Z');
        Prompt.AppendLine('- Today: old');
        Prompt.AppendLine();
        Prompt.AppendLine('Synthetic suffix');
        Replacement.AppendLine('SESSION TIME (fresh):');
        Replacement.AppendLine('- Now UTC: 2026-11-01T00:00:00Z');
        Actual := Probe.ReplaceTimeBlock(Prompt.ToText(), Replacement.ToText());
        Assert.AreEqual(1, Probe.CountTimeBlocks(Actual), 'Exactly one block');
        Assert.IsFalse(Actual.Contains('2020-01-01'), 'No stale clock');
        Assert.IsTrue(Actual.Contains('Synthetic prefix'), 'Preserve prefix');
        Assert.IsTrue(Actual.Contains('Synthetic suffix'), 'Preserve suffix');
        Assert.IsTrue(Actual.Contains('2026-11-01'), 'Replacement clock');
    end;

    /// <summary>AC04: absent block is a failed precondition rather than a fabricated replacement pass.</summary>
    [Test]
    procedure AC04_MissingBlockRefused()
    begin
        asserterror Probe.ReplaceTimeBlock('No clock here.', 'SESSION TIME (new)');
        Assert.ExpectedError('exactly one source SESSION TIME block');
    end;

    /// <summary>AC04: duplicate clock blocks cannot be silently accepted.</summary>
    [Test]
    procedure AC04_DuplicateBlocksRefused()
    var
        Prompt: TextBuilder;
    begin
        Prompt.AppendLine('SESSION TIME (first)');
        Prompt.AppendLine();
        Prompt.AppendLine('SESSION TIME (second)');
        asserterror Probe.ReplaceTimeBlock(Prompt.ToText(), 'SESSION TIME (new)');
        Assert.ExpectedError('exactly one source SESSION TIME block');
    end;

    /// <summary>AC04: a header mentioned inside a sentence is not a block boundary.</summary>
    [Test]
    procedure AC04_QuotedHeaderIsNotABlock()
    begin
        Assert.AreEqual(0, Probe.CountTimeBlocks('Text says SESSION TIME (cached)'), 'Line-start header only');
    end;

    /// <summary>AC07: probes the native bootstrap and split loop under the exact API plus chat role combination.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure AC07_ApiAndChatRoles()
    begin
        VerifyPermissionCombination('BIFROST API ori');
    end;

    /// <summary>AC07: probes the same real execution path with the Foundation Read role.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure AC07_ReadAndChatRoles()
    begin
        VerifyPermissionCombination('BIFROST Read ori');
    end;

    /// <summary>AC07: probes the same real execution path with the Foundation Full role.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure AC07_FullAndChatRoles()
    begin
        VerifyPermissionCombination('BIFROST Full ori');
    end;

    local procedure VerifyPermissionCombination(BaseRole: Code[20])
    var
        Model: Record "Bifrost Language Model ori";
        Mock: Codeunit "Mock Bifrost Chat Provider";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        TestContext: Codeunit "Bifrost LangModel Test Ctx ori";
        Result: JsonObject;
        Request: JsonObject;
        ResultText: Text;
        FailureText: Text;
        Succeeded: Boolean;
        OwnedId: Guid;
    begin
        // Test role changes are in-memory test permissions, never Access Control writes.
        // Fixture creation/cleanup use the test administrator; the measured path resets to the exact three sets.
        LowerPermissions.SetOutsideO365Scope();
        if Model.Get('BIFT-LM98-MOCK') then
            Error('LM98 mock fixture collision; retain the existing record.');
        Model.Init();
        Model.Code := 'BIFT-LM98-MOCK';
        Model."Chat Provider" := Model."Chat Provider"::Mock;
        Model.Model := 'lm98-native-mock';
        Model.Insert(false);
        OwnedId := Model.SystemId;
        Commit(); // Fixture setup is outside the transaction being probed.
        Mock.Reset();
        Mock.SetIsConfigured(true);
        Mock.SetSendResponse('{"type":"tool_calls","conversationState":"{}","toolCalls":[{"id":"lm98-1","name":"get_fields","arguments":{"tableName":"Customer"}}]}');
        Mock.SetContinueResponse('{"type":"reply","reply":"{\"verdict\":\"pass\"}"}');
        Request.Add('code', Model.Code);
        Request.Add('customer', 'BIFT-A');
        LowerPermissions.SetExactPermissionSet(BaseRole);
        LowerPermissions.AddPermissionSet('BIFROST Chat ori');
        LowerPermissions.AddPermissionSet('BIFROST LLM Chat ori');
        ClearLastError();
        Succeeded := TryPermissionLoop(Request, Result);
        FailureText := GetLastErrorText();
        LowerPermissions.SetOutsideO365Scope();
        TestContext.ClearLanguageModel();
        if Model.GetBySystemId(OwnedId) then
            Model.Delete(false);
        Mock.Reset();
        Commit(); // Retain cleanup even when the measured permission assertion fails.
        Assert.IsTrue(Succeeded, 'Exact role combination ' + BaseRole + ': ' + FailureText);
        Result.WriteTo(ResultText);
        Assert.AreEqual('reply', Result.GetText('stopReason'), ResultText);
        Assert.AreEqual(1, Result.GetInteger('toolCalls'), ResultText);
        Assert.AreEqual(0, Result.GetInteger('toolErrors'), ResultText);
    end;

    [TryFunction]
    local procedure TryPermissionLoop(Request: JsonObject; var Result: JsonObject)
    var
        BootstrapResult: JsonObject;
    begin
        BootstrapResult := Probe.NestedTool();
        if BootstrapResult.GetBoolean('nestedToolError') then
            Error(BootstrapResult.GetText('bcError'));
        Result := Probe.Live(Request);
    end;
}
