namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Runs all eight R1 cells in separate sessions and restores the original debug setting.</summary>
codeunit 96057 "LM98 R1 Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Uses the real Setup page for the debug toggle; no internal Foundation field or permission is bypassed.</summary>
    [Test]
    [HandlerFunctions('ObserveNotification')]
    procedure R1FreshSessionMatrix()
    var
        Setup: Record "Setup ori";
        OriginalDebug: Boolean;
        Succeeded: Boolean;
        FailureText: Text;
    begin
        if not Setup.TryGetSetup(Setup) then
            Error('LM98 requires existing configured Foundation Setup; no setup installation is performed.');
        OriginalDebug := Setup.GetRequestDebugMode();
        Succeeded := TryMatrix();
        FailureText := GetLastErrorText();
        SetDebugMode(OriginalDebug);
        Assert.IsTrue(Succeeded, 'R1 orchestration failed: ' + FailureText);
        // Observed transaction failures belong in the matrix; orchestration success is not a GO.
    end;

    [TryFunction]
    local procedure TryMatrix()
    var
        DebugIndex: Integer;
        CommitIndex: Integer;
        CacheIndex: Integer;
    begin
        for DebugIndex := 0 to 1 do begin
            SetDebugMode(DebugIndex = 1);
            for CommitIndex := 0 to 1 do
                for CacheIndex := 0 to 1 do
                    RunCell(DebugIndex, CommitIndex, CacheIndex);
        end;
    end;

    local procedure RunCell(DebugIndex: Integer; CommitIndex: Integer; CacheIndex: Integer)
    var
        Receipt: Record "LM98 Receipt ori";
        SessionId: Integer;
        Attempts: Integer;
        Result: JsonObject;
        CellKeyTok: Label 'R1-%1-%2-%3', Locked = true;
    begin
        Receipt.Id := CopyStr(StrSubstNo(CellKeyTok, DebugIndex, CommitIndex, CacheIndex), 1, MaxStrLen(Receipt.Id));
        if Receipt.Get(Receipt.Id) then
            Error('R1 receipt already exists; inspect actual evidence rather than replaying this cell.');
        Receipt."Omit Commit" := CommitIndex = 1;
        Receipt."Cached Bootstrap" := CacheIndex = 1;
        Receipt."Started At" := CurrentDateTime();
        Receipt.Insert();
        Commit();
        if not Session.StartSession(SessionId, Codeunit::"LM98 R1 Session ori", CompanyName(), Receipt) then
            Error('R1 owned background session could not start.');
        for Attempts := 1 to 1200 do begin
            SelectLatestVersion();
            Receipt.Get(Receipt.Id);
            if Receipt.Finished then begin
                Result := Receipt.GetReport();
                Assert.AreEqual(DebugIndex = 1, Result.GetBoolean('requestDebugMode'), 'Actual debug mode must match the matrix cell');
                exit;
            end;
            Sleep(100);
        end;
        // Only this probe's session may be stopped; preserve its incomplete receipt for diagnosis.
        Session.StopSession(SessionId, 'LM98 owned R1 cell timed out.');
        Error('R1 cell timed out; retained incomplete receipt, no result claimed.');
    end;
    local procedure SetDebugMode(Enabled: Boolean)
    var
        SetupPage: TestPage "Setup ori";
    begin
        SetupPage.OpenEdit();
        SetupPage."Request Debug Mode".SetValue(Enabled);
        SetupPage.Close();
        Commit();
    end;

    /// <summary>Handles the real setup page's notifications without changing the warned-about settings.</summary>
    [SendNotificationHandler]
    procedure ObserveNotification(var Notification: Notification): Boolean
    begin
        exit(true);
    end;
}
