namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue 85: the Copilot starting system prompt must carry an unambiguous session
/// time block (work date plus current date-time in the user's timezone) so the
/// model can compute relative days and periods without guessing "today".
/// </summary>
codeunit 96039 "Copilot Chat Prompt Time Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        PromptBuilder: Codeunit "Copilot Prompt Builder Test Tools";

    /// <summary>
    /// The block carries the ISO work date, a current date-time on that work date
    /// with the zone name and UTC offset, and the Now UTC line (#85).
    /// </summary>
    [Test]
    procedure SessionTimeBlock_ContainsWorkDateAndCurrentDateTime()
    var
        Block: Text;
    begin
        // [SCENARIO] a new Copilot chat session on a fixed clock
        Block := PromptBuilder.BuildSessionTimeBlock(FixedNowUtc(), FixedUtcOffset(), 'Reykjavik', FixedWorkDate());

        Assert.IsTrue(Block.Contains(Format(FixedWorkDate(), 0, 0, 0, 0, 0, 0, 9)), 'ISO work date present');
        Assert.IsTrue(Block.Contains(Format(FixedNowUtc(), 0, 0, 0, 0, 0, 0, 9)), 'current date-time (work-date noon) present');
        Assert.IsTrue(Block.Contains('Reykjavik'), 'zone name present');
        Assert.IsTrue(Block.Contains('+00:00'), 'UTC offset present');
        Assert.IsTrue(Block.Contains('- Now UTC: ' + Format(FixedNowUtc(), 0, 0, 0, 0, 0, 0, 9) + 'Z'), 'Now UTC line present');
        Assert.IsTrue(Block.Contains('SESSION TIME'), 'session time header present');
        Assert.AreEqual(1, Occurrences(Block, 'SESSION TIME'), 'exactly one session time block');
    end;

    /// <summary>
    /// The block instructs the model to use the given values for relative day and
    /// period math instead of inventing today (#85).
    /// </summary>
    [Test]
    procedure SessionTimeBlock_InstructsPeriodMathOnGivenValues()
    var
        Block: Text;
    begin
        // [SCENARIO] the instruction part of the session time block
        Block := PromptBuilder.BuildSessionTimeBlock(FixedNowUtc(), FixedUtcOffset(), 'Reykjavik', FixedWorkDate());

        Assert.IsTrue(Block.Contains('never guess today'), 'do-not-invent-today instruction');
        Assert.IsTrue(Block.Contains('Weeks start on Monday'), 'Monday week-start rule');
        Assert.IsTrue(Block.Contains('Last N days = N days ending today, inclusive'), 'last N days rule');
        Assert.IsTrue(Block.Contains('This month = the 1st of the current month through today'), 'this month rule');
        Assert.IsTrue(Block.Contains('Last month = the whole previous calendar month'), 'last month rule');
        Assert.IsTrue(Block.Contains('State the exact dates you used'), 'state-dates-used instruction');
        Assert.IsTrue(Block.Contains('Do not call a tool to learn today'), 'no date tool call instruction');
    end;

    /// <summary>
    /// The block is identical under the en-US (1033) and is-IS (1039) languages,
    /// so the model instruction never drifts by locale (#85).
    /// </summary>
    [Test]
    procedure SessionTimeBlock_IsIdenticalAcrossLanguages()
    var
        EnglishBlock: Text;
        IcelandicBlock: Text;
        SavedLanguage: Integer;
    begin
        // [SCENARIO] the same fixed clock rendered under both supported languages
        SavedLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        EnglishBlock := PromptBuilder.BuildSessionTimeBlock(FixedNowUtc(), FixedUtcOffset(), 'Reykjavik', FixedWorkDate());
        GlobalLanguage(1039);
        IcelandicBlock := PromptBuilder.BuildSessionTimeBlock(FixedNowUtc(), FixedUtcOffset(), 'Reykjavik', FixedWorkDate());
        GlobalLanguage(SavedLanguage);

        Assert.AreEqual(EnglishBlock, IcelandicBlock, 'block text is language-neutral');
        Assert.IsTrue(EnglishBlock.Contains('Tuesday'), 'English weekday name (2026-11-17 is a Tuesday)');
    end;

    /// <summary>
    /// An unknown time zone renders the UTC fallback wording and no local line
    /// (#85).
    /// </summary>
    [Test]
    procedure SessionTimeBlock_UnknownZone_RendersUtcFallback()
    var
        Block: Text;
    begin
        // [SCENARIO] GetTimezone() returned empty for the session
        Block := PromptBuilder.BuildSessionTimeBlock(FixedNowUtc(), CreateDuration(0, 0, 0, 0), '', FixedWorkDate());

        Assert.IsTrue(Block.Contains('the user''s time zone is unknown'), 'unknown-zone wording present');
        Assert.IsFalse(Block.Contains('- Now user time'), 'no local time line for unknown zone');
        Assert.IsTrue(Block.Contains('Tuesday'), 'UTC weekday name present');
    end;

    /// <summary>
    /// A work date that differs from today is reported as a separate line with the
    /// use-it-for-posting-dates instruction (#85).
    /// </summary>
    [Test]
    procedure SessionTimeBlock_WorkDateDiffersFromToday_ShowsWorkDateLine()
    var
        Block: Text;
    begin
        // [SCENARIO] WorkDate is set to a day other than the session date
        Block := PromptBuilder.BuildSessionTimeBlock(FixedNowUtc(), FixedUtcOffset(), 'Reykjavik', DMY2Date(15, 11, 2026));

        Assert.IsTrue(Block.Contains('- Work date: ' + Format(DMY2Date(15, 11, 2026), 0, 0, 0, 0, 0, 0, 9)), 'differing work date line present');
        Assert.IsTrue(Block.Contains('differs from today'), 'differs-from-today wording present');
        Assert.IsTrue(Block.Contains('Monday'), 'work date weekday name (2026-11-15 is a Monday)');
    end;

    /// <summary>
    /// A work date equal to today is not repeated as a separate line (#85).
    /// </summary>
    [Test]
    procedure SessionTimeBlock_WorkDateEqualsToday_SkipsWorkDateLine()
    var
        Block: Text;
    begin
        // [SCENARIO] WorkDate matches the session date
        Block := PromptBuilder.BuildSessionTimeBlock(FixedNowUtc(), FixedUtcOffset(), 'Reykjavik', FixedWorkDate());

        Assert.IsFalse(Block.Contains('- Work date:'), 'no separate work date line when it equals today');
    end;

    /// <summary>
    /// A DST-offset zone converts the UTC instant to the user's local date and
    /// time correctly, including the offset sign (#85).
    /// </summary>
    [Test]
    procedure SessionTimeBlock_DstOffset_ConvertsToLocalTime()
    var
        Block: Text;
    begin
        // [SCENARIO] 2026-11-17 22:00Z with a -05:00 zone is 2026-11-17 17:00 local
        Block := PromptBuilder.BuildSessionTimeBlock(FixedNowUtc(), CreateDuration(-5, 0, 0, 0), 'New York', FixedWorkDate());

        Assert.IsTrue(Block.Contains('-05:00'), 'negative UTC offset rendered');
        Assert.IsTrue(Block.Contains('- Now user time (New York, -05:00): ' + Format(CreateDateTime(DMY2Date(17, 11, 2026), DT2Time(17, 0, 0, 0)), 0, 0, 0, 0, 0, 0, 9)), 'local time rendered');
        Assert.IsTrue(Block.Contains('- Today: ' + Format(DMY2Date(17, 11, 2026), 0, 0, 0, 0, 0, 0, 9) + ' Tuesday'), 'local today rendered');
    end;

    /// <summary>
    /// The starting system prompt carries exactly one session time block between
    /// the Bootstrap and the record context, built from the fixed inputs (#85).
    /// </summary>
    [Test]
    procedure BuildSystemPrompt_ContainsSingleSessionTimeBlock()
    var
        SystemPrompt: Text;
        Block: Text;
    begin
        // [SCENARIO] a new Copilot chat session with a fixed clock and work date
        SystemPrompt := PromptBuilder.BuildSystemPrompt(FixedNowUtc(), FixedUtcOffset(), 'Reykjavik', FixedWorkDate(), CreatePayload());
        Block := PromptBuilder.BuildSessionTimeBlock(FixedNowUtc(), FixedUtcOffset(), 'Reykjavik', FixedWorkDate());

        Assert.AreEqual(1, Occurrences(SystemPrompt, 'SESSION TIME'), 'exactly one session time block in the prompt');
        Assert.IsTrue(SystemPrompt.Contains(Block), 'app block present in the prompt');
        Assert.IsTrue(SystemPrompt.Contains('RECORD CONTEXT:'), 'record context still appended after the block');
        Assert.IsTrue(IndexOf(SystemPrompt, 'SESSION TIME') < IndexOf(SystemPrompt, 'RECORD CONTEXT:'), 'block precedes record context');
    end;

    local function FixedWorkDate() WorkDate: Date
    begin
        exit(DMY2Date(17, 11, 2026));
    end;

    local function FixedNowUtc() NowUtc: DateTime
    begin
        exit(CreateDateTime(FixedWorkDate(), DT2Time(22, 0, 0, 0)));
    end;

    local function FixedUtcOffset() UtcOffset: Duration
    begin
        exit(CreateDuration(0, 0, 0, 0));
    end;

    local procedure CreatePayload() Payload: JsonObject
    begin
        Payload.Add('recordContext', '{"tableId":"5740","recordSystemId":"11111111-1111-1111-1111-111111111111"}');
    end;

    local procedure Occurrences(Text: Text; SubText: Text) Count: Integer
    var
        Position: Integer;
    begin
        while true do begin
            Position := Text.IndexOf(SubText);
            if Position = 0 then
                exit;
            Count += 1;
            Text := CopyStr(Text, Position + StrLen(SubText));
        end;
    end;
}
