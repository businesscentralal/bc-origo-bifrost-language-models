namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;

/// <summary>
/// Test tool for issue 85: reproduces the Copilot Chat Proxy starting-prompt assembly (Bootstrap, session
/// time block, record context, skill reference) against a fixed work date and clock, so the prompt text can
/// be asserted deterministically.
/// </summary>
codeunit 96040 "Copilot Prompt Builder Test Tools"
{
    Access = Internal;

    /// <summary>
    /// Builds the starting system prompt exactly as "Copilot Chat Proxy ori".BuildSystemPrompt does, with the
    /// session time block rendered from the given work date and the current date-time snapped to it.
    /// </summary>
    procedure BuildSystemPrompt(FixedWorkDate: Date; PayloadObject: JsonObject) SystemPrompt: Text
    var
        PromptBuilder: TextBuilder;
        ToolServer: Codeunit "MCP Tool Server ori";
        Timezone: Text;
        CurrentDateTime: DateTime;
        RecordContextToken: JsonToken;
        RecordContext: Text;
        UserSkill: Text;
    begin
        Timezone := GetTimezone();
        if Timezone = '' then
            Timezone := 'UTC';
        CurrentDateTime := CreateDateTime(FixedWorkDate, DT2Time(12, 0, 0, 0));

        PromptBuilder.Append(ToolServer.Bootstrap(''));
        PromptBuilder.AppendLine();
        PromptBuilder.AppendLine();
        PromptBuilder.Append(SessionTimeBlock(FixedWorkDate, CurrentDateTime, Timezone));

        if PayloadObject.Get('recordContext', RecordContextToken) then begin
            RecordContextToken.WriteTo(RecordContext);
            if RecordContext <> '' then begin
                PromptBuilder.AppendLine();
                PromptBuilder.AppendLine();
                PromptBuilder.AppendLine('RECORD CONTEXT:');
                PromptBuilder.AppendLine(RecordContext);
                PromptBuilder.AppendLine('When the user refers to the current page record, use its tableId and recordSystemId with get_records to fetch data.');
            end;
        end;

        UserSkill := GetTextProperty(PayloadObject, 'contextSkill');
        if UserSkill <> '' then begin
            PromptBuilder.AppendLine();
            PromptBuilder.AppendLine();
            PromptBuilder.AppendLine('SKILL REFERENCE:');
            PromptBuilder.Append(UserSkill);
        end;

        SystemPrompt := PromptBuilder.ToText();
    end;

    local procedure SessionTimeBlock(FixedWorkDate: Date; CurrentDateTime: DateTime; Timezone: Text) Block: Text
    begin
        Block := 'SESSION TIME:'+
;
        Block += 'Work date: ' + Format(FixedWorkDate, 0, 0, 0, 0, 0, 0, 9)+
;
        Block += 'Current date-time: ' + Format(CurrentDateTime, 0, 0, 0, 0, 0, 0, 9) + ' (' + Timezone + ')'+
;
        Block += 'Use the work date and the current date-time above for all relative day and period math (for example ''last 30 days'', ''this month'' or ''since Monday'') and when building tableView date FILTERs. Never invent today or the current time.';
    end;

    local procedure GetTextProperty(Source: JsonObject; PropertyName: Text) Value: Text
    var
        Token: JsonToken;
    begin
        if Source.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
        exit('');
    end;
}
