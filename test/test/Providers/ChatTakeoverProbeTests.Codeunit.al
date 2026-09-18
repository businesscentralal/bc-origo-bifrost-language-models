namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;
using System.Reflection;
using System.TestLibraries.Utilities;

/// <summary>
/// AC01–AC03 coverage for permission-tolerant install-time chat providers take-over
/// (language-models#8). Uses the install probe seam (<c>Chat Takeover State ori</c> probe
/// denial) which matches the production <c>OnInstallAppPerCompany</c> path — same pattern as
/// Foundation core#43 / treasury#14. No <c>Test No Source Read</c> permission set: tests are
/// not Restrictive (standing HARD 2026-09-15). No Access Control role pairs are moved, so
/// there is no AC write-denial case.
/// </summary>
codeunit 96017 "Chat Takeover Probe Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure AC01_ProbeDenied_SkipsTakeOverWithoutError()
    var
        Takeover: Codeunit "Chat Providers Install ori";
        TakeoverState: Codeunit "Chat Takeover State ori";
        Succeeded: Boolean;
        DeniedTableId: Integer;
        CapturedDenied: Integer;
        CapturedError: Text;
    begin
        // [SCENARIO] AC01: legacy table present but read denied → skip, no error, telemetry names the table
        Initialize();
        DeniedTableId := 10035495; // CE Chat Service Gate ori
        TakeoverState.SetProbeDenial(DeniedTableId);

        Succeeded := Takeover.TryRunTakeOverAtInstall();

        Assert.IsFalse(Succeeded, 'Take-over must report skipped when the install probe denies a table.');
        Assert.IsTrue(
            TakeoverState.TryGetLastSkip(CapturedDenied, CapturedError),
            'Skip telemetry capture must record the denial.');
        Assert.AreEqual(DeniedTableId, CapturedDenied, 'Denied table id must be the probed legacy table.');
        Assert.IsTrue(
            CapturedError.Contains('Read denied'),
            'Skip error text must report Read denied for a legacy source table.');
    end;

    [Test]
    procedure AC02_ProbeOk_RunsTakeOverWithoutError()
    var
        Takeover: Codeunit "Chat Providers Install ori";
        Succeeded: Boolean;
        DeniedTableId: Integer;
    begin
        // [SCENARIO] AC02: probe passes (legacy absent or readable) → TryRunTakeOverAtInstall succeeds
        Initialize();

        Assert.IsTrue(
            Takeover.TryProbeTakeOverPermissions(DeniedTableId),
            'Probe must pass when no denial is forced and legacy tables are absent or readable.');
        Assert.AreEqual(0, DeniedTableId, 'DeniedTableId must stay 0 when the probe passes.');

        Succeeded := Takeover.TryRunTakeOverAtInstall();

        Assert.IsTrue(Succeeded, 'Install take-over must succeed when the probe passes.');
    end;

    [Test]
    procedure AC03_LegacyAbsent_NoOpWithoutError()
    var
        Takeover: Codeunit "Chat Providers Install ori";
        TableMetadata: Record "Table Metadata";
        Succeeded: Boolean;
    begin
        // [SCENARIO] AC03: legacy CE Chat Service Gate absent → take-over is a no-op, no error
        Initialize();
        Assert.IsFalse(
            TableMetadata.Get(10035495),
            'W1 unit host must not have CE Chat Service Gate ori (10035495).');

        Succeeded := Takeover.TryRunTakeOverAtInstall();

        Assert.IsTrue(Succeeded, 'Absent legacy tables must no-op successfully (probe passes, copy exits early).');
    end;

    local procedure Initialize()
    var
        TakeoverState: Codeunit "Chat Takeover State ori";
    begin
        TakeoverState.ClearProbeDenial();
        TakeoverState.ClearLastSkip();
    end;
}
