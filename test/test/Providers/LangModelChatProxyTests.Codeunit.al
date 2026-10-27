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

    /// <summary>Verifies the complete production block and its exact ISO values with a fixed clock.</summary>
    [Test]
    procedure SessionTime_ExactFixedBlock()
    var
        Proxy: Codeunit "Copilot Chat Proxy ori";
        Expected: TextBuilder;
    begin
        Expected.AppendLine('SESSION TIME (as of this request; use it for every relative date, never guess today):');
        Expected.AppendLine('- Now UTC: 2026-10-27T10:27:00Z');
        Expected.AppendLine('- Now user time (Test Zone, UTC+01:00): 2026-10-27T11:27:00+01:00');
        Expected.AppendLine('- Today: 2026-10-27 Tuesday');
        Expected.AppendLine('- Work date: 2026-10-28 (differs from today; use it for posting dates the user did not specify)');
        Expected.AppendLine('- Weeks start on Monday. This week = most recent Monday through today. Last N days = N days ending today, inclusive (today minus N-1 through today). This month = the 1st of the current month through today. Last month = the whole previous calendar month. State the exact dates you used in your answer.');
        Expected.AppendLine('- Use ISO dates from this block when you build tableView date filters. Do not call a tool to learn today''s date.');
        Assert.AreEqual(Expected.ToText(), Proxy.BuildSessionTimeBlock(FixedInstant('2026-10-27T10:27:00Z'), 3600000, 'Test Zone', DMY2Date(28, 10, 2026)), 'Exact production block');
    end;

    /// <summary>Unknown zones ignore an unresolved offset and explicitly use the UTC date.</summary>
    [Test]
    procedure SessionTime_UnknownZoneUsesUtc()
    var
        Proxy: Codeunit "Copilot Chat Proxy ori";
        Block: Text;
    begin
        Block := Proxy.BuildSessionTimeBlock(FixedInstant('2026-10-27T23:30:00Z'), 3600000, '', DMY2Date(27, 10, 2026));
        Assert.IsFalse(Block.Contains('Now user time'), 'No invented local time');
        Assert.IsTrue(Block.Contains('- Today: 2026-10-27 Tuesday (UTC; the user''s time zone is unknown)'), 'Explicit UTC fallback');
        Assert.IsFalse(Block.Contains('- Work date:'), 'Equal UTC work date omitted');
    end;

    /// <summary>A work date equal to the local date is omitted, and a different work date is explained.</summary>
    [Test]
    procedure SessionTime_WorkDateConditions()
    var
        Proxy: Codeunit "Copilot Chat Proxy ori";
        Block: Text;
        Instant: DateTime;
    begin
        Instant := FixedInstant('2026-10-27T23:30:00Z');
        Block := Proxy.BuildSessionTimeBlock(Instant, 3600000, 'Test Zone', DMY2Date(28, 10, 2026));
        Assert.IsFalse(Block.Contains('- Work date:'), 'Compare against local Today');
        Block := Proxy.BuildSessionTimeBlock(Instant, 3600000, 'Test Zone', DMY2Date(27, 10, 2026));
        Assert.IsTrue(Block.Contains('- Work date: 2026-10-27 (differs from today; use it for posting dates the user did not specify)'), 'Different work date explained');
    end;

    /// <summary>Positive offsets cross midnight and compute the English weekday from the local date.</summary>
    [Test]
    procedure SessionTime_PositiveMidnight()
    begin
        AssertLocalDate('2026-10-27T23:30:00Z', 3600000, '2026-10-28 Wednesday', '2026-10-28T00:30:00+01:00');
    end;

    /// <summary>Negative offsets cross midnight into the previous local date.</summary>
    [Test]
    procedure SessionTime_NegativeMidnight()
    begin
        AssertLocalDate('2026-10-27T00:30:00Z', -3600000, '2026-10-26 Monday', '2026-10-26T23:30:00-01:00');
    end;

    /// <summary>Month-end conversion uses calendar arithmetic rather than text date increments.</summary>
    [Test]
    procedure SessionTime_MonthEnd()
    begin
        AssertLocalDate('2026-10-31T23:30:00Z', 3600000, '2026-11-01 Sunday', '2026-11-01T00:30:00+01:00');
    end;

    /// <summary>Leap-day conversion includes 29 February in a leap year.</summary>
    [Test]
    procedure SessionTime_LeapDay()
    begin
        AssertLocalDate('2028-02-28T23:30:00Z', 3600000, '2028-02-29 Tuesday', '2028-02-29T00:30:00+01:00');
    end;

    /// <summary>Fractional-hour offsets preserve numeric minutes and seconds precision.</summary>
    [Test]
    procedure SessionTime_FractionalOffset()
    begin
        AssertLocalDate('2026-10-27T10:27:00.123Z', 19800000, '2026-10-27 Tuesday', '2026-10-27T15:57:00+05:30');
    end;

    /// <summary>The same fixed production inputs produce byte-identical output in English and Icelandic.</summary>
    [Test]
    procedure SessionTime_LocaleIndependent()
    var
        Proxy: Codeunit "Copilot Chat Proxy ori";
        OriginalLanguage: Integer;
        EnglishBlock: Text;
        IcelandicBlock: Text;
        Instant: DateTime;
    begin
        Instant := FixedInstant('2026-10-27T10:27:00Z');
        OriginalLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        EnglishBlock := Proxy.BuildSessionTimeBlock(Instant, 3600000, 'Test Zone', DMY2Date(28, 10, 2026));
        GlobalLanguage(1039);
        IcelandicBlock := Proxy.BuildSessionTimeBlock(Instant, 3600000, 'Test Zone', DMY2Date(28, 10, 2026));
        GlobalLanguage(OriginalLanguage);
        Assert.AreEqual(EnglishBlock, IcelandicBlock, 'Invariant block in LCIDs 1033 and 1039');
    end;

    /// <summary>The production assembly seam places one block after Foundation and is idempotent.</summary>
    [Test]
    procedure SessionTime_AppendOnceAfterBootstrap()
    var
        Proxy: Codeunit "Copilot Chat Proxy ori";
        Prompt: Text;
        Instant: DateTime;
        WorkDate: Date;
    begin
        Instant := FixedInstant('2026-10-27T10:27:00Z');
        WorkDate := DMY2Date(27, 10, 2026);
        Prompt := Proxy.AddSessionTimeBlock('FOUNDATION', Instant, 0, 'UTC', WorkDate);
        Assert.AreEqual(1, StrPos(Prompt, 'FOUNDATION'), 'Foundation retained first');
        Assert.IsTrue(StrPos(Prompt, 'SESSION TIME') > StrLen('FOUNDATION'), 'Time block follows Foundation');
        Assert.AreEqual(Prompt, Proxy.AddSessionTimeBlock(Prompt, Instant, 0, 'UTC', WorkDate), 'Second assembly does not stack a block');
        Assert.AreEqual(0, StrPos(CopyStr(Prompt, StrPos(Prompt, 'SESSION TIME') + StrLen('SESSION TIME')), 'SESSION TIME'), 'Exactly one marker');
    end;

    /// <summary>A Foundation-owned block is retained byte-for-byte.</summary>
    [Test]
    procedure SessionTime_FoundationMarkerPreserved()
    var
        Proxy: Codeunit "Copilot Chat Proxy ori";
        Bootstrap: Text;
    begin
        Bootstrap := 'FOUNDATION SESSION TIME existing block';
        Assert.AreEqual(Bootstrap, Proxy.AddSessionTimeBlock(Bootstrap, FixedInstant('2026-10-27T10:27:00Z'), 0, 'UTC', DMY2Date(27, 10, 2026)), 'Foundation owns its marker');
    end;

    /// <summary>Each request uses its explicit clock and emits only the allowed time-related data.</summary>
    [Test]
    procedure SessionTime_RequestRefreshAndNoIdentity()
    var
        Proxy: Codeunit "Copilot Chat Proxy ori";
        FirstPrompt: Text;
        SecondPrompt: Text;
        WorkDate: Date;
    begin
        WorkDate := DMY2Date(27, 10, 2026);
        FirstPrompt := Proxy.AddSessionTimeBlock('', FixedInstant('2026-10-27T10:27:00Z'), 0, 'UTC', WorkDate);
        SecondPrompt := Proxy.AddSessionTimeBlock('', FixedInstant('2026-10-28T10:27:00Z'), 0, 'UTC', WorkDate);
        Assert.IsTrue(FirstPrompt <> SecondPrompt, 'Request clock is recomputed');
        Assert.IsFalse(FirstPrompt.Contains(UserId()), 'No user id');
        Assert.IsFalse(FirstPrompt.Contains(CompanyName()), 'No company name');
        Assert.IsFalse(FirstPrompt.Contains(Format(UserSecurityId(), 0, 4)), 'No security id');
        Assert.IsFalse(FirstPrompt.Contains('@'), 'No email address');
    end;

    local procedure FixedInstant(IsoText: Text) Instant: DateTime
    begin
        Evaluate(Instant, IsoText, 9);
    end;

    local procedure AssertLocalDate(IsoText: Text; Offset: Duration; ExpectedToday: Text; ExpectedLocalTime: Text)
    var
        Proxy: Codeunit "Copilot Chat Proxy ori";
        Block: Text;
    begin
        Block := Proxy.BuildSessionTimeBlock(FixedInstant(IsoText), Offset, 'Test Zone', DMY2Date(27, 10, 2026));
        Assert.IsTrue(Block.Contains('- Today: ' + ExpectedToday), 'Local date and English weekday');
        Assert.IsTrue(Block.Contains(ExpectedLocalTime), 'ISO local timestamp and numeric offset');
    end;

    local procedure ToolArray() Tools: JsonArray
    var
        Tool: JsonObject;
    begin
        Tool.Add('type', 'function');
        Tools.Add(Tool);
    end;
}
