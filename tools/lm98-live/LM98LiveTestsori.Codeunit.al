namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>Explicit live spike batch, never included in ordinary CI: requires authorized preconfigured models and one unused allowance.</summary>
codeunit 96055 "LM98 Live Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    TestHttpRequestPolicy = AllowOutboundFromHandler;

    var
        Budget: Codeunit "LM98 Live Budget ori";
        Fixtures: Codeunit "LM98 Fixtures ori";
        Probe: Codeunit "LM98 Probe ori";
        Assert: Codeunit "Library Assert";

    /// <summary>Runs both authorized providers over three own customers twice, with a single total forty-HTTP allowance.</summary>
    [Test]
    [HandlerFunctions('AllowCountedModelRequest')]
    procedure LivePostingSetupBatch()
    var
        OpenAI: Record "Bifrost Language Model ori";
        Anthropic: Record "Bifrost Language Model ori";
        Report: JsonObject;
        Rows: JsonArray;
        Completed: Boolean;
        CleanupCount: Integer;
        Row: JsonToken;
    begin
        // No key access here. The authorized live verifier configures these codes using existing tooling.
        OpenAI.Get('BIFT-OPENAI');
        OpenAI.TestField("Chat Provider", OpenAI."Chat Provider"::OpenAI);
        Anthropic.Get('BIFT-CLAUDE');
        Anthropic.TestField("Chat Provider", Anthropic."Chat Provider"::Anthropic);
        Budget.BeginRun();
        Completed := TryBatch(Rows);
        // Do not export GetLastErrorText: provider errors may contain response content.
        CleanupCount := Fixtures.Cleanup();
        Report.Add('batchReturned', Completed);
        Report.Add('rows', Rows);
        Report.Add('fixtureManifest', Fixtures.Manifest());
        Report.Add('ownedFixtureRecordsDeleted', CleanupCount);
        Report.Add('ownedFixtureCleanupVerified', true);
        Report.Add('historyCompactionFactLoss', 'not assessed: requires private verifier comparison');
        Budget.FinishRun(Report);
        Assert.IsTrue(Completed, 'LM98 live batch failed; inspect the sanitized receipt. Never rerun without explicit budget disposition.');
        Assert.AreEqual(12, Rows.Count(), 'Both providers, three customers, two runs each');
        foreach Row in Rows do begin
            Assert.AreEqual('reply', Row.AsObject().GetText('stopReason'), 'Final reply required; sanitized receipt retained');
            Assert.AreEqual(Row.AsObject().GetText('expectedVerdict'), Row.AsObject().GetText('verdict'), 'Posting setup verdict; sanitized receipt retained');
        end;
    end;

    [TryFunction]
    local procedure TryBatch(var Rows: JsonArray)
    var
        Request: JsonObject;
        Result: JsonObject;
        ProviderIndex: Integer;
        CustomerIndex: Integer;
        RunIndex: Integer;
        BeforeCalls: Integer;
    begin
        Fixtures.Create();
        Budget.SaveFixtureManifest(Fixtures.Manifest());
        Commit(); // Isolate owned fixture setup; no commit is inserted inside a measured split loop.
        // Alternate providers so the shared cap cannot consume every attempt on OpenAI first.
        for CustomerIndex := 1 to 3 do
            for RunIndex := 1 to 2 do
                for ProviderIndex := 1 to 2 do begin
                    if Budget.Count() >= 40 then
                        exit;
                    Clear(Request);
                    if ProviderIndex = 1 then
                        Request.Add('code', 'BIFT-OPENAI')
                    else
                        Request.Add('code', 'BIFT-CLAUDE');
                    Request.Add('customer', Fixtures.CustomerCode(CustomerIndex));
                    BeforeCalls := Budget.Count();
                    Result := Probe.Live(Request);
                    Result.Add('scenario', CustomerIndex);
                    Result.Add('run', RunIndex);
                    Result.Add('actualHttpCalls', Budget.Count() - BeforeCalls);
                    if Budget.Count() > BeforeCalls then
                        Result.Add('apiPath', Budget.LastApiPath())
                    else
                        Result.Add('apiPath', 'not called');
                    if CustomerIndex = 1 then
                        Result.Add('expectedVerdict', 'pass')
                    else
                        Result.Add('expectedVerdict', 'fail');
                    Rows.Add(Result);
                    Commit(); // Separate measured runs; never alter the transaction between send, tool and continue.
                end;
    end;

    /// <summary>Native interception counts actual requests without reading headers, secrets, body or customer content.</summary>
    [HttpClientHandler]
    procedure AllowCountedModelRequest(Request: TestHttpRequestMessage; var Response: TestHttpResponseMessage): Boolean
    begin
        Budget.BeforeRequest(Request.Path);
        // The selected existing providers own their endpoint; no new endpoint or credential is configured by this probe.
        exit(true);
    end;
}
