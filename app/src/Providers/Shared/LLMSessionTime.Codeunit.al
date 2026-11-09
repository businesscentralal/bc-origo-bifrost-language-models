namespace Origo.Bifrost.LanguageModels;

using Origo.Bifrost;

/// <summary>
/// Gives every language model prompt exactly one fresh SESSION TIME block. The block text comes only from
/// Foundation's MCP Tool Server ori.GetSessionTimeBlock(); this codeunit reads no clock, formats no date and
/// resolves no time zone (Gunnar, 31.10.2026: Foundation code is never copied). It only swaps the block into
/// a prompt and reads the three response values back out of the block that was sent.
/// </summary>
codeunit 10035431 "LLM Session Time ori"
{
    Access = Internal;

    var
        HeaderMarkerTok: Label 'SESSION TIME (', Locked = true;
        NowUtcPrefixTok: Label '- Now UTC: ', Locked = true;
        UserTimePrefixTok: Label '- Now user time (', Locked = true;
        TodayPrefixTok: Label '- Today: ', Locked = true;
        WorkDatePrefixTok: Label '- Work date: ', Locked = true;
        ZoneSeparatorTok: Label ', UTC', Locked = true;
        SessionTimeKeyTok: Label 'sessionTime', Locked = true;
        UnavailableWarningTok: Label 'sessionTimeUnavailable', Locked = true;

    /// <summary>
    /// Gets a fresh block from Foundation. Returns false, with Block empty, when Foundation cannot supply one
    /// (missing permission, dispatch error or an open write transaction), so callers can fail open.
    /// </summary>
    procedure GetBlock(var Block: Text): Boolean
    begin
        Block := '';
        if not TryGetBlock(Block) then begin
            ClearLastError();
            Block := '';
            exit(false);
        end;
        exit(Block <> '');
    end;

    [TryFunction]
    local procedure TryGetBlock(var Block: Text)
    var
        ToolServer: Codeunit "MCP Tool Server ori";
        Handled: Boolean;
    begin
        OnBeforeGetSessionTimeBlock(Block, Handled);
        if not Handled then
            Block := ToolServer.GetSessionTimeBlock();
    end;

    /// <summary>Test seam: a subscriber can supply the block, or raise an error to simulate Foundation failing.</summary>
    [IntegrationEvent(false, false)]
    local procedure OnBeforeGetSessionTimeBlock(var Block: Text; var Handled: Boolean)
    begin
    end;

    /// <summary>
    /// Replaces the first block in Prompt with Block, or appends Block after one empty line when Prompt has none.
    /// A block is the run of lines from the first line that starts with the header marker up to, not including,
    /// the first empty line after it. Text before and after the run is kept byte for byte.
    /// </summary>
    procedure ReplaceOrAppend(Prompt: Text; Block: Text): Text
    var
        Result: TextBuilder;
        Lines: List of [Text];
        Index: Integer;
        StartIndex: Integer;
        EndIndex: Integer;
    begin
        if Prompt = '' then
            exit(Block);
        Lines := Prompt.Split(GetLf());
        StartIndex := FindBlockStart(Lines);
        if StartIndex = 0 then begin
            Result.Append(Prompt);
            Result.AppendLine();
            Result.AppendLine();
            Result.Append(Block);
            exit(Result.ToText());
        end;

        EndIndex := Lines.Count() + 1;
        for Index := StartIndex to Lines.Count() do
            if IsEmptyLine(Lines.Get(Index)) then begin
                EndIndex := Index;
                break;
            end;

        for Index := 1 to StartIndex - 1 do begin
            Result.Append(Lines.Get(Index));
            Result.Append(GetLf());
        end;
        Result.Append(Block);
        if EndIndex <= Lines.Count() then begin
            // Keep the line ending of the replaced run so CRLF text stays CRLF.
            if Lines.Get(EndIndex - 1).EndsWith(GetCr()) then
                Result.Append(GetCr());
            for Index := EndIndex to Lines.Count() do begin
                Result.Append(GetLf());
                Result.Append(Lines.Get(Index));
            end;
        end;
        exit(Result.ToText());
    end;

    /// <summary>Swaps the session-start block in Foundation's Bootstrap text for a fresh one; returns the text unchanged when no fresh block is available.</summary>
    procedure WithFreshBlock(BootstrapPrompt: Text): Text
    var
        Block: Text;
    begin
        if GetBlock(Block) then
            exit(ReplaceOrAppend(BootstrapPrompt, Block));
        exit(BootstrapPrompt);
    end;

    /// <summary>Reports whether Prompt already holds a block (a line that starts with the header marker).</summary>
    procedure HasBlock(Prompt: Text): Boolean
    var
        Lines: List of [Text];
    begin
        if Prompt = '' then
            exit(false);
        Lines := Prompt.Split(GetLf());
        exit(FindBlockStart(Lines) > 0);
    end;

    /// <summary>
    /// Puts Block first in a Complete system prompt, removing any stale blocks from the caller's text.
    /// An unavailable fresh block leaves only the caller's instructions; an empty caller text yields Block alone.
    /// </summary>
    procedure ForSystemPrompt(CallerSystem: Text; Block: Text): Text
    var
        Result: TextBuilder;
    begin
        if HasBlock(CallerSystem) then
            CallerSystem := WithoutBlocks(CallerSystem);
        if Block = '' then
            exit(CallerSystem);
        if CallerSystem = '' then
            exit(Block);
        Result.Append(Block);
        Result.AppendLine();
        Result.AppendLine();
        Result.Append(CallerSystem);
        exit(Result.ToText());
    end;

    /// <summary>
    /// Reads nowUtc, workDate and, when Foundation knew the zone, timeZone out of the block that was sent.
    /// workDate is the Work date line when present, otherwise the Today date (the two are equal then).
    /// </summary>
    procedure GetSummary(Block: Text): JsonObject
    var
        Summary: JsonObject;
        Lines: List of [Text];
        Line: Text;
        Clean: Text;
        NowUtc: Text;
        TodayDate: Text;
        WorkDate: Text;
        ZoneName: Text;
        ZoneEnd: Integer;
    begin
        Lines := Block.Split(GetLf());
        foreach Line in Lines do begin
            Clean := DelChr(Line, '=', GetCr());
            if Clean.StartsWith(NowUtcPrefixTok) then
                NowUtc := CopyStr(Clean, StrLen(NowUtcPrefixTok) + 1);
            if Clean.StartsWith(UserTimePrefixTok) then begin
                ZoneEnd := Clean.IndexOf(ZoneSeparatorTok);
                if ZoneEnd > StrLen(UserTimePrefixTok) then
                    ZoneName := CopyStr(Clean, StrLen(UserTimePrefixTok) + 1, ZoneEnd - StrLen(UserTimePrefixTok) - 1);
            end;
            if Clean.StartsWith(TodayPrefixTok) then
                TodayDate := CopyStr(Clean, StrLen(TodayPrefixTok) + 1, 10);
            if Clean.StartsWith(WorkDatePrefixTok) then
                WorkDate := CopyStr(Clean, StrLen(WorkDatePrefixTok) + 1, 10);
        end;
        if WorkDate = '' then
            WorkDate := TodayDate;
        if NowUtc = '' then
            exit(Summary);
        Summary.Add('nowUtc', NowUtc);
        Summary.Add('workDate', WorkDate);
        if ZoneName <> '' then
            Summary.Add('timeZone', ZoneName);
        exit(Summary);
    end;

    /// <summary>Adds the sessionTime object to a Complete response, or the unavailable warning when no block was sent.</summary>
    procedure AddToResponse(var ResponseJson: JsonObject; Block: Text)
    var
        Warnings: JsonArray;
        Existing: JsonToken;
        Summary: JsonObject;
    begin
        if Block <> '' then begin
            Summary := GetSummary(Block);
            if Summary.Keys().Count() > 0 then begin
                ResponseJson.Add(SessionTimeKeyTok, Summary);
                exit;
            end;
        end;
        if ResponseJson.Get('warnings', Existing) then begin
            if Existing.IsArray() then
                Warnings := Existing.AsArray();
            Warnings.Add(UnavailableWarningTok);
            ResponseJson.Replace('warnings', Warnings);
        end else begin
            Warnings.Add(UnavailableWarningTok);
            ResponseJson.Add('warnings', Warnings);
        end;
    end;

    local procedure WithoutBlocks(Prompt: Text): Text
    var
        Lines: List of [Text];
        KeptLines: List of [Text];
        LastLine: Text;
        Result: TextBuilder;
        Index: Integer;
        Line: Text;
    begin
        Lines := Prompt.Split(GetLf());
        Index := 1;
        while Index <= Lines.Count() do
            if Lines.Get(Index).StartsWith(HeaderMarkerTok) then begin
                // A block ends at the next empty line. Consume that separator with the block;
                // keep the surrounding instructions, including their original line endings.
                while Index <= Lines.Count() do begin
                    if IsEmptyLine(Lines.Get(Index)) then
                        break;
                    Index += 1;
                end;
                if Index > Lines.Count() then begin
                    if KeptLines.Count() > 0 then
                        if IsEmptyLine(KeptLines.Get(KeptLines.Count())) then
                            KeptLines.RemoveAt(KeptLines.Count());
                    if KeptLines.Count() > 0 then begin
                        // The last retained CR was part of the separator before the removed block,
                        // not part of the caller's instruction text.
                        LastLine := KeptLines.Get(KeptLines.Count());
                        if LastLine.EndsWith(GetCr()) then
                            KeptLines.Set(KeptLines.Count(), CopyStr(LastLine, 1, StrLen(LastLine) - 1));
                    end;
                end;
                Index += 1;
            end else begin
                KeptLines.Add(Lines.Get(Index));
                Index += 1;
            end;
        Index := 0;
        foreach Line in KeptLines do begin
            if Index > 0 then
                Result.Append(GetLf());
            Result.Append(Line);
            Index += 1;
        end;
        exit(Result.ToText());
    end;

    local procedure FindBlockStart(Lines: List of [Text]): Integer
    var
        Index: Integer;
    begin
        for Index := 1 to Lines.Count() do
            if Lines.Get(Index).StartsWith(HeaderMarkerTok) then
                exit(Index);
        exit(0);
    end;

    local procedure IsEmptyLine(Line: Text): Boolean
    begin
        exit(DelChr(Line, '=', GetCr()) = '');
    end;

    local procedure GetLf(): Text
    var
        LineFeed: Char;
    begin
        LineFeed := 10;
        exit(Format(LineFeed));
    end;

    local procedure GetCr(): Text
    var
        CarriageReturn: Char;
    begin
        CarriageReturn := 13;
        exit(Format(CarriageReturn));
    end;
}
