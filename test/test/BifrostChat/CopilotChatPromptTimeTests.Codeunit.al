namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue 85: the Copilot starting system prompt must carry an unambiguous session time block (work date plus
/// current date-time in the user's timezone) so the model can compute relative days and periods without
/// guessing "today".
/// </summary>
codeunit 96039 "Copilot Chat Prompt Time Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        PromptBuilder: Codeunit "Copilot Prompt Test Tools";

    /// <summary>
    /// Verifies that for a fixed work date the built system prompt contains the ISO work date and a current
    /// date-time that falls on that same work date.
    /// </summary>
    [Test]
    procedure BuildSystemPrompt_FixedWorkDate_ContainsWorkDateAndCurrentDateTime()
    var
        WorkDate: Date;
        SystemPrompt: Text;
    begin
        // [SCENARIO] a new Copilot chat session with a fixed work date
        WorkDate := DMY2Date(15, 11, 2026);

        SystemPrompt := PromptBuilder.BuildSystemPrompt(WorkDate, CreatePayload());

        Assert.AreEqual(Format(WorkDate, 0, 9), ExtractLine(SystemPrompt, 'Work date: '), 'ISO work date');
        Assert.IsTrue(SystemPrompt.Contains('Current date-time: '), 'current date-time line present');
        Assert.IsTrue(SystemPrompt.Contains('(') and SystemPrompt.Contains(')'), 'timezone present');
        Assert.IsTrue(SystemPrompt.Contains('SESSION TIME:'), 'session time header present');
    end;

    /// <summary>
    /// Verifies that the system prompt instructs the model to use the given values for relative day and
    /// period math instead of inventing today.
    /// </summary>
    [Test]
    procedure BuildSystemPrompt_InstructsPeriodMathOnGivenValues()
    var
        SystemPrompt: Text;
    begin
        // [SCENARIO] the instruction part of the session time block
        SystemPrompt := PromptBuilder.BuildSystemPrompt(DMY2Date(15, 11, 2026), CreatePayload());

        Assert.IsTrue(SystemPrompt.Contains('relative day and period math'), 'period math instruction');
        Assert.IsTrue(SystemPrompt.Contains('Never invent today'), 'do-not-invent instruction');
        Assert.IsTrue(SystemPrompt.Contains('tableView date FILTERs'), 'date filter guidance');
    end;

    local procedure CreatePayload() Payload: JsonObject
    begin
        Payload.Add('recordContext', '{}');
    end;

    local procedure ExtractLine(SystemPrompt: Text; Prefix: Text) Line: Text
    var
        Position: Integer;
        Rest: Text;
        LineFeed: Char;
        CarriageReturn: Char;
        LineEndPosition: Integer;
    begin
        Position := StrPos(SystemPrompt, Prefix);
        if Position = 0 then
            exit('');
        Rest := CopyStr(SystemPrompt, Position + StrLen(Prefix));
        LineFeed := 10;
        CarriageReturn := 13;
        LineEndPosition := StrPos(Rest, Format(LineFeed));
        if LineEndPosition = 0 then
            exit(Rest);
        exit(DelChr(CopyStr(Rest, 1, LineEndPosition - 1), '>', Format(CarriageReturn)));
    end;
}
