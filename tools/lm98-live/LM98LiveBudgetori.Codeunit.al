namespace Origo.Bifrost.LanguageModels.Test;

/// <summary>Single-session HTTP accounting activated only by the guarded native live test.</summary>
codeunit 96053 "LM98 Live Budget ori"
{
    Access = Internal;
    SingleInstance = true;
    var
        Active: Boolean;
        Calls: Integer;
        LastPath: Text;
        PathCounts: Dictionary of [Text, Integer];

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LM98 Probe ori", 'OnReadReceipt', '', false, false)]
    local procedure ReadReceipt(ReceiptKey: Text; var Result: JsonObject)
    var
        Receipt: Record "LM98 Receipt ori";
    begin
        if not ((ReceiptKey = 'LM98-LIVE') or ReceiptKey.StartsWith('R1-')) then
            Error('LM98 unknown receipt key.');
        Receipt.Get(CopyStr(ReceiptKey, 1, MaxStrLen(Receipt.Id)));
        Result := Receipt.GetReport();
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LM98 Probe ori", 'OnAuthorizeLive', '', false, false)]
    local procedure AuthorizeLive(var Allowed: Boolean)
    begin
        AssertActive();
        Allowed := true;
    end;

    /// <summary>Reserves this issue's entire live allowance before any model request. Existing receipts prohibit retries.</summary>
    procedure BeginRun()
    var
        Receipt: Record "LM98 Receipt ori";
    begin
        if Receipt.Get('LM98-LIVE') then
            Error('LM98 live allowance already consumed or reserved. Inspect the retained receipt; do not repeat the run.');
        Receipt.Init();
        Receipt.Id := 'LM98-LIVE';
        Receipt."Started At" := CurrentDateTime();
        Receipt.Insert();
        Commit(); // Durable reservation precedes fixture setup and all measured provider/transaction operations.
        Calls := 0;
        Clear(LastPath);
        Clear(PathCounts);
        Active := true;
    end;

    /// <summary>Refuses unguarded direct live calls; mocks require no live allowance.</summary>
    procedure AssertActive()
    begin
        if not Active then
            Error('LM98 real provider calls require the guarded native live batch.');
    end;

    /// <summary>Counts every actual HTTP request, including internal retries and figure follow-ups.</summary>
    procedure BeforeRequest(RequestPath: Text)
    var
        PathCount: Integer;
    begin
        AssertActive();
        if Calls >= 40 then
            Error('LM98 total live HTTP cap reached; request not sent.');
        case true of
            RequestPath.EndsWith('/chat/completions'): LastPath := 'chat completions';
            RequestPath.EndsWith('/responses'): LastPath := 'Responses';
            RequestPath.EndsWith('/messages'): LastPath := 'Messages';
            else Error('LM98 refused an HTTP path outside the three authorized model endpoints.');
        end;
        Calls += 1;
        if PathCounts.Get(LastPath, PathCount) then
            PathCounts.Set(LastPath, PathCount + 1)
        else
            PathCounts.Add(LastPath, 1);
    end;

    /// <summary>Reports a fixed endpoint category only, never a URL, query, header or key.</summary>
    procedure LastApiPath(): Text
    begin
        exit(LastPath);
    end;

    /// <summary>Reads actual outbound requests admitted by the native handler.</summary>
    procedure Count(): Integer
    begin
        exit(Calls);
    end;

    /// <summary>Persists owned identities in the same transaction as fixture creation; no commit occurs here.</summary>
    procedure SaveFixtureManifest(Manifest: JsonArray)
    var
        Receipt: Record "LM98 Receipt ori";
        Report: JsonObject;
    begin
        Receipt.Get('LM98-LIVE');
        Report.Add('fixtureManifest', Manifest);
        Report.Add('ownedFixtureCleanupVerified', false);
        Receipt.Finished := false;
        Receipt.SetReport(Report);
        Receipt.Modify();
    end;

    /// <summary>Closes the active window and records measurements even when the batch did not reach its expected verdicts.</summary>
    procedure FinishRun(Report: JsonObject)
    var
        Receipt: Record "LM98 Receipt ori";
        Paths: JsonObject;
        PathName: Text;
    begin
        Active := false;
        foreach PathName in PathCounts.Keys() do
            Paths.Add(PathName, PathCounts.Get(PathName));
        Report.Add('actualHttpCallsByPath', Paths);
        Receipt.Get('LM98-LIVE');
        Receipt."HTTP Calls" := Calls;
        Receipt.Finished := true;
        Receipt.SetReport(Report);
        Receipt.Modify();
        Commit(); // Evidence and verified cleanup persist before assertions report observed failures.
    end;
}
