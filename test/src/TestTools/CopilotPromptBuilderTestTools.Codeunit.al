namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;

/// <summary>
/// Test tool for issue 85: renders the app's actual SESSION TIME block
/// (10035393 BuildSessionTimeBlock) from fixed inputs so the starting system
/// prompt can be asserted deterministically, and assembles the starting
/// prompt exactly as the app's private BuildSystemPrompt does (Bootstrap,
/// session time block, record context, skill reference).
/// </summary>
codeunit 96040 "Copilot Prompt Builder Test Tools"
{
    Access = Internal;

    /// <summary>
    /// Renders the app's real session time block for fixed inputs. The 10035393
    /// codeunit is Access = Internal, so only this app and its test app can call it.
    /// </summary>
    procedure BuildSessionTimeBlock(NowUtc: DateTime; UtcOffset: Duration; TimeZoneName: Text; WorkDate: Date) Block: Text
    var
        ChatProxy: Codeunit "Copilot Chat Proxy ori";
    begin
        exit(ChatProxy.BuildSessionTimeBlock(NowUtc, UtcOffset, TimeZoneName, WorkDate));
    end;

    /// <summary>
    /// Builds the starting system prompt with the same assembly order as
    /// 10035393 "Copilot Chat Proxy ori".BuildSystemPrompt: Foundation Bootstrap,
    /// the session time block (skipped when the Bootstrap already carries it),
    /// the record context and the user skill. The block uses the given fixed
    /// UTC instant, offset, timezone name and work date, so tests never depend
    /// on the wall clock (#85).
    /// </summary>
    procedure BuildSystemPrompt(NowUtc: DateTime; UtcOffset: Duration; TimeZoneName: Text; WorkDate: Date; PayloadObject: JsonObject) SystemPrompt: Text
    var
        PromptBuilder: TextBuilder;
        ChatProxy: Codeunit "Copilot Chat Proxy ori";
        ToolServer: Codeunit "MCP Tool Server ori";
        BootstrapPrompt: Text;
        RecordContextToken: JsonToken;
        RecordContext: Text;
        UserSkill: Text;
    begin
        BootstrapPrompt := ToolServer.Bootstrap('');
        PromptBuilder.Append(BootstrapPrompt);
        if StrPos(BootstrapPrompt, 'SESSION TIME') = 0 then begin
            PromptBuilder.AppendLine();
            PromptBuilder.Append(ChatProxy.BuildSessionTimeBlock(NowUtc, UtcOffset, TimeZoneName, WorkDate));
        end;

        if PayloadObject.Get('recordContext', RecordContextToken) then begin
            RecordContextToken.WriteTo(RecordContext);
            if RecordContext <> '' then begin
                PromptBuilder.AppendLine();
                PromptBuilder.AppendLine();
                PromptBuilder.AppendLine('RECORD CONTEXT:');
                PromptBuilder.Append(RecordContext);
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
