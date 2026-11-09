namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests the shared fresh SESSION TIME block of language-models#99: the replace-or-append helper, LLM.Prompt.Complete,
/// the shared, Anthropic and Copilot chat proxies, and the locale. Fixed blocks come from LLM Session Time Seam;
/// the provider is the mock provider or LLM 100 HTTP Mock, so nothing leaves the service.
/// </summary>
codeunit 96060 "LLM Session Time Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        ModelCodeTok: Label 'LM99-TIME', Locked = true;
        HeaderTok: Label 'SESSION TIME (', Locked = true;

    // ---- Pinned wording and helper (AC01, AC02) ----

    /// <summary>Verifies that Foundation's real block starts with the pinned header and has no empty line inside, so a core wording change fails CI.</summary>
    [Test]
    procedure Foundation_BlockStartsWithPinnedHeaderAndHasNoEmptyLine()
    var
        SessionTime: Codeunit "LLM Session Time ori";
        Block: Text;
        Lines: List of [Text];
        Line: Text;
    begin
        // [SCENARIO] the replace-or-append helper depends on Foundation's header and on a block without an empty line
        Assert.IsTrue(SessionTime.GetBlock(Block), 'Foundation supplies a block');
        Assert.IsTrue(Block.StartsWith(HeaderTok), 'Block starts with the pinned header');
        Lines := Block.Split(Lf());
        foreach Line in Lines do
            Assert.AreNotEqual('', DelChr(Line, '=', Cr()), 'No empty line inside the block');
        Assert.IsTrue(Block.Contains('- Now UTC: '), 'Now UTC line');
        Assert.IsTrue(Block.Contains('- Today: '), 'Today line');
    end;

    /// <summary>Verifies that a block in the middle of a Bootstrap-shaped text is replaced and the text around it is kept.</summary>
    [Test]
    procedure ReplaceOrAppend_BlockInTheMiddle_TextAroundIsKept()
    var
        SessionTime: Codeunit "LLM Session Time ori";
    begin
        Assert.AreEqual(
            Join3(Join2('BOOT', ''), NewBlock(), Join2('', Join2('USER INSTRUCTIONS:', 'keep me'))),
            SessionTime.ReplaceOrAppend(Join3(Join2('BOOT', ''), OldBlock(false), Join2('', Join2('USER INSTRUCTIONS:', 'keep me'))), NewBlock()),
            'Only the block run is replaced');
    end;

    /// <summary>Verifies that a block at the very end is replaced.</summary>
    [Test]
    procedure ReplaceOrAppend_BlockAtTheEnd_IsReplaced()
    var
        SessionTime: Codeunit "LLM Session Time ori";
    begin
        Assert.AreEqual(
            Join2(Join2('BOOT', ''), NewBlock()),
            SessionTime.ReplaceOrAppend(Join2(Join2('BOOT', ''), OldBlock(false)), NewBlock()),
            'Block at the end');
    end;

    /// <summary>Verifies that a text without a block gets the block after one empty line.</summary>
    [Test]
    procedure ReplaceOrAppend_NoBlock_AppendsAfterOneEmptyLine()
    var
        SessionTime: Codeunit "LLM Session Time ori";
    begin
        Assert.AreEqual(
            Join3('Just a system prompt.', '', NewBlock()),
            SessionTime.ReplaceOrAppend('Just a system prompt.', NewBlock()),
            'Appended after one empty line');
        Assert.AreEqual(NewBlock(), SessionTime.ReplaceOrAppend('', NewBlock()), 'Empty text yields the block');
    end;

    /// <summary>Verifies that with two blocks only the first is replaced (documented behaviour).</summary>
    [Test]
    procedure ReplaceOrAppend_TwoBlocks_OnlyTheFirstIsReplaced()
    var
        SessionTime: Codeunit "LLM Session Time ori";
        Result: Text;
    begin
        Result := SessionTime.ReplaceOrAppend(Join3(OldBlock(false), '', OldBlock(true)), NewBlock());
        Assert.AreEqual(Join3(NewBlock(), '', OldBlock(true)), Result, 'First replaced, second untouched');
    end;

    /// <summary>Verifies that applying the same block twice gives the same text.</summary>
    [Test]
    procedure ReplaceOrAppend_SameCallTwice_IsIdempotent()
    var
        SessionTime: Codeunit "LLM Session Time ori";
        Once: Text;
    begin
        Once := SessionTime.ReplaceOrAppend('Plain text', NewBlock());
        Assert.AreEqual(Once, SessionTime.ReplaceOrAppend(Once, NewBlock()), 'Second call changes nothing');
        Once := SessionTime.ReplaceOrAppend(Join3('A', '', OldBlock(true)), NewBlock());
        Assert.AreEqual(Once, SessionTime.ReplaceOrAppend(Once, NewBlock()), 'Second call changes nothing (replace path)');
    end;

    /// <summary>Verifies that a block with the work-date line and one without it replace each other cleanly.</summary>
    [Test]
    procedure ReplaceOrAppend_WorkDateLine_IsReplacedBothWays()
    var
        SessionTime: Codeunit "LLM Session Time ori";
        Result: Text;
    begin
        Result := SessionTime.ReplaceOrAppend(Join3('BOOT', '', OldBlock(true)), NewBlock());
        Assert.IsFalse(Result.Contains('- Work date:'), 'The old work date line is gone');
        Result := SessionTime.ReplaceOrAppend(Join3('BOOT', '', OldBlock(false)), NewBlockWithWorkDate());
        Assert.IsTrue(Result.Contains('- Work date: 2026-11-09'), 'The new work date line is present');
        Assert.AreEqual(1, CountBlocks(Result), 'One block');
    end;

    /// <summary>Verifies the system text order: block first, one empty line, the caller's text; an existing block is replaced.</summary>
    [Test]
    procedure ForSystemPrompt_PutsTheBlockFirstAndNeverDoubles()
    var
        SessionTime: Codeunit "LLM Session Time ori";
    begin
        Assert.AreEqual(NewBlock(), SessionTime.ForSystemPrompt('', NewBlock()), 'No caller text');
        Assert.AreEqual(Join3(NewBlock(), '', 'Answer with one word.'), SessionTime.ForSystemPrompt('Answer with one word.', NewBlock()), 'Block first');
        Assert.AreEqual(Join3(NewBlock(), '', 'Tail'), SessionTime.ForSystemPrompt(Join3(OldBlock(false), '', 'Tail'), NewBlock()), 'Existing block replaced');
        Assert.AreEqual(Join3(NewBlock(), '', 'Before'), SessionTime.ForSystemPrompt(Join3('Before', '', OldBlock(false)), NewBlock()), 'A terminal block moves ahead of caller instructions');
        Assert.AreEqual(Join3(NewBlock(), '', Join3('Before', '', 'After')), SessionTime.ForSystemPrompt(Join3(Join3('Before', '', OldBlock(false)), '', 'After'), NewBlock()), 'A middle block moves first and both instructions stay');
    end;

    /// <summary>Complete normalizes multiple caller blocks without changing ReplaceOrAppend's first-block contract.</summary>
    [Test]
    procedure Scenario_AC03_MultipleCallerBlocks_OneFreshBlockFirst()
    var
        SessionTime: Codeunit "LLM Session Time ori";
        CallerSystem: Text;
        Result: Text;
    begin
        // Story #99, AC03 | Time: fixed block seam; no clock read | Risk: None
        CallerSystem := Join3(Join3('Before', '', OldBlock(false)), '', Join3(OldBlock(true), '', 'After'));
        Result := SessionTime.ForSystemPrompt(CallerSystem, NewBlock());
        Assert.AreEqual(Join3(NewBlock(), '', Join3('Before', '', 'After')), Result, 'One fresh block first; caller instructions stay');
        Assert.AreEqual(1, CountBlocks(Result), 'Exactly one block');
        Assert.AreEqual(Result, SessionTime.ForSystemPrompt(Result, NewBlock()), 'Normalization is idempotent');
        Assert.AreEqual(Join3('Before', '', 'After'), SessionTime.ForSystemPrompt(CallerSystem, ''), 'Fail open drops stale blocks');
    end;

    /// <summary>Verifies that the response summary is read from the block, with timeZone left out when the zone is unknown.</summary>
    [Test]
    procedure GetSummary_ReadsTheBlockThatWasSent()
    var
        SessionTime: Codeunit "LLM Session Time ori";
        Summary: JsonObject;
    begin
        Summary := SessionTime.GetSummary(NewBlockWithWorkDate());
        Assert.AreEqual('2026-11-06T10:00:00Z', Summary.GetText('nowUtc'), 'nowUtc');
        Assert.AreEqual('2026-11-09', Summary.GetText('workDate'), 'workDate from the Work date line');
        Assert.AreEqual('GMT Standard Time', Summary.GetText('timeZone'), 'timeZone');

        Summary := SessionTime.GetSummary(NewBlock());
        Assert.AreEqual('2026-11-06', Summary.GetText('workDate'), 'workDate equals today without a Work date line');

        Summary := SessionTime.GetSummary(UnknownZoneBlock());
        Assert.AreEqual('2026-11-06T10:00:00Z', Summary.GetText('nowUtc'), 'nowUtc, zone unknown');
        Assert.IsFalse(Summary.Contains('timeZone'), 'No timeZone key when the zone is unknown');
    end;

    // ---- LLM.Prompt.Complete (AC03, AC06, AC07, AC08, AC11) ----

    /// <summary>Verifies that Complete without system sends exactly one block as the system text.</summary>
    [Test]
    procedure Complete_NoSystem_SendsExactlyOneBlock()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        System: Text;
    begin
        Initialize();
        Complete('{"prompt":"Hello","roleCode":"' + ModelCodeTok + '"}', 1033);
        System := SystemPromptOf(MockProvider.GetLastCompletePayload());
        Assert.AreEqual(1, CountBlocks(System), 'One block');
        Assert.IsTrue(System.StartsWith(HeaderTok), 'The block comes first');
    end;

    /// <summary>Verifies that Complete with a caller system sends the block first, then one empty line, then the caller's text.</summary>
    [Test]
    procedure Complete_WithSystem_BlockFirstThenCallerText()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        Seam: Codeunit "LLM Session Time Seam";
        Blocks: List of [Text];
        System: Text;
    begin
        Initialize();
        Blocks.Add(NewBlock());
        Seam.Serve(Blocks);
        BindSubscription(Seam);
        Complete('{"prompt":"Hello","system":"Answer with one word.","roleCode":"' + ModelCodeTok + '"}', 1033);
        UnbindSubscription(Seam);
        System := SystemPromptOf(MockProvider.GetLastCompletePayload());
        Assert.AreEqual(Join3(NewBlock(), '', 'Answer with one word.'), System, 'Block, one empty line, caller system');
    end;

    /// <summary>Verifies that a block inside the caller's system is replaced by the fresh one, not duplicated.</summary>
    [Test]
    procedure Complete_SystemWithBlock_IsReplacedNotDoubled()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        Seam: Codeunit "LLM Session Time Seam";
        Blocks: List of [Text];
        System: Text;
        Request: JsonObject;
        RequestText: Text;
    begin
        Initialize();
        Blocks.Add(NewBlock());
        Seam.Serve(Blocks);
        BindSubscription(Seam);
        Request.Add('prompt', 'Hello');
        Request.Add('roleCode', ModelCodeTok);
        Request.Add('system', Join3('Be brief.', '', OldBlock(false)));
        Request.WriteTo(RequestText);
        Complete(RequestText, 1033);
        UnbindSubscription(Seam);
        System := SystemPromptOf(MockProvider.GetLastCompletePayload());
        Assert.AreEqual(1, CountBlocks(System), 'One block');
        Assert.IsFalse(System.Contains('old test block'), 'The caller''s block is gone');
        Assert.IsTrue(System.Contains('fresh test block'), 'The fresh block is there');
        Assert.IsTrue(System.Contains('Be brief.'), 'The caller text is kept');
        Assert.IsTrue(System.StartsWith(HeaderTok), 'AC03: the fresh block comes first even when the old block was at the end');
    end;

    /// <summary>Verifies that the Work date line appears only when the work date differs from today, with Foundation's real block.</summary>
    [Test]
    procedure Complete_WorkDate_ShownOnlyWhenItDiffersFromToday()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        SessionTime: Codeunit "LLM Session Time ori";
        Block: Text;
        LocalToday: Date;
        Other: Date;
        PreviousWorkDate: Date;
    begin
        // Foundation's block cannot be read inside an open write transaction, so read it before the fixture is written.
        Assert.IsTrue(SessionTime.GetBlock(Block), 'Foundation supplies a block');
        Initialize();
        PreviousWorkDate := WorkDate();
        Assert.IsTrue(Evaluate(LocalToday, CopyStr(Block, Block.IndexOf('- Today: ') + 9, 10), 9), 'Today line: ' + Block);
        Assert.AreNotEqual(0D, LocalToday, 'Parsed today: ' + CopyStr(Block, Block.IndexOf('- Today: ') + 9, 10));

        Other := CalcDate('<+3D>', LocalToday);
        WorkDate(Other);
        Complete('{"prompt":"Hello","roleCode":"' + ModelCodeTok + '"}', 1033);
        Assert.IsTrue(SystemPromptOf(MockProvider.GetLastCompletePayload()).Contains('- Work date: ' + Format(Other, 0, 9)), 'Different work date is shown');

        WorkDate(LocalToday);
        Complete('{"prompt":"Hello","roleCode":"' + ModelCodeTok + '"}', 1033);
        WorkDate(PreviousWorkDate);
        Assert.IsFalse(SystemPromptOf(MockProvider.GetLastCompletePayload()).Contains('- Work date:'), 'Equal work date is not shown');
    end;

    /// <summary>Verifies that the response carries sessionTime read from the block sent, and omits timeZone when the zone is unknown.</summary>
    [Test]
    procedure Complete_Response_CarriesSessionTimeFromTheBlockSent()
    var
        Seam: Codeunit "LLM Session Time Seam";
        Blocks: List of [Text];
        Response: JsonObject;
        SessionTimeToken: JsonToken;
        SessionTime: JsonObject;
    begin
        Initialize();
        Blocks.Add(NewBlockWithWorkDate());
        Seam.Serve(Blocks);
        BindSubscription(Seam);
        Response := Complete('{"prompt":"Hello","roleCode":"' + ModelCodeTok + '"}', 1033);
        UnbindSubscription(Seam);
        Assert.AreEqual('Success', Response.GetText('status'), 'Status');
        Response.Get('sessionTime', SessionTimeToken);
        SessionTime := SessionTimeToken.AsObject();
        Assert.AreEqual('2026-11-06T10:00:00Z', SessionTime.GetText('nowUtc'), 'nowUtc');
        Assert.AreEqual('2026-11-09', SessionTime.GetText('workDate'), 'workDate');
        Assert.AreEqual('GMT Standard Time', SessionTime.GetText('timeZone'), 'timeZone');
        Assert.IsFalse(Response.Contains('warnings'), 'No warnings');

        Clear(Blocks);
        Blocks.Add(UnknownZoneBlock());
        Seam.Serve(Blocks);
        BindSubscription(Seam);
        Response := Complete('{"prompt":"Hello","roleCode":"' + ModelCodeTok + '"}', 1033);
        UnbindSubscription(Seam);
        Response.Get('sessionTime', SessionTimeToken);
        Assert.IsFalse(SessionTimeToken.AsObject().Contains('timeZone'), 'timeZone is absent when the zone is unknown');
    end;

    /// <summary>Verifies that Complete fails open when Foundation cannot supply the block: success, no sessionTime, a warning, no block in the prompt.</summary>
    [Test]
    procedure Complete_FoundationFails_SucceedsWithWarningAndNoBlock()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        Seam: Codeunit "LLM Session Time Seam";
        Response: JsonObject;
        WarningsToken: JsonToken;
        System: Text;
    begin
        Initialize();
        Seam.Fail();
        BindSubscription(Seam);
        Response := Complete('{"prompt":"Hello","system":"Be brief.","roleCode":"' + ModelCodeTok + '"}', 1033);
        UnbindSubscription(Seam);
        Assert.AreEqual('Success', Response.GetText('status'), 'Complete still succeeds');
        Assert.IsFalse(Response.Contains('sessionTime'), 'No sessionTime');
        Response.Get('warnings', WarningsToken);
        Assert.AreEqual(1, WarningsToken.AsArray().Count(), 'One warning');
        Assert.AreEqual('sessionTimeUnavailable', GetArrayText(WarningsToken.AsArray(), 0), 'Warning text');
        System := SystemPromptOf(MockProvider.GetLastCompletePayload());
        Assert.AreEqual('Be brief.', System, 'The prompt is sent as the caller wrote it, without a block');
    end;

    /// <summary>Fail-open Complete never sends a stale clock from the caller's system prompt.</summary>
    [Test]
    procedure Scenario_AC08_FoundationFails_CallerBlockIsRemoved()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        Seam: Codeunit "LLM Session Time Seam";
        Request: JsonObject;
        Response: JsonObject;
        Warnings: JsonToken;
        RequestText: Text;
    begin
        // Story #99, AC08 | Time: forced Foundation failure; no stale clock | Risk: None
        Initialize();
        Request.Add('prompt', 'Hello');
        Request.Add('roleCode', ModelCodeTok);
        Request.Add('system', Join3('Be brief.', '', OldBlock(false)));
        Request.WriteTo(RequestText);
        Seam.Fail();
        BindSubscription(Seam);
        Response := Complete(RequestText, 1033);
        UnbindSubscription(Seam);
        Assert.AreEqual('Success', Response.GetText('status'), 'Complete still succeeds');
        Assert.IsFalse(Response.Contains('sessionTime'), 'No sessionTime');
        Response.Get('warnings', Warnings);
        Assert.AreEqual('sessionTimeUnavailable', GetArrayText(Warnings.AsArray(), 0), 'Warning');
        Assert.AreEqual('Be brief.', SystemPromptOf(MockProvider.GetLastCompletePayload()), 'Caller instructions stay without the stale block');
    end;

    /// <summary>Verifies that the Complete system text, with the clock lines masked, is the same in session languages 1033 and 1039.</summary>
    [Test]
    procedure Complete_SystemText_IsLocaleIndependent()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        English: Text;
        Icelandic: Text;
    begin
        Initialize();
        Complete('{"prompt":"Hello","system":"Be brief.","roleCode":"' + ModelCodeTok + '"}', 1033);
        English := MaskClock(SystemPromptOf(MockProvider.GetLastCompletePayload()));
        Complete('{"prompt":"Hello","system":"Be brief.","roleCode":"' + ModelCodeTok + '"}', 1039);
        Icelandic := MaskClock(SystemPromptOf(MockProvider.GetLastCompletePayload()));
        Assert.AreEqual(English, Icelandic, 'Byte-identical with the clock lines masked');
        Assert.IsTrue(English.Contains('SESSION TIME ('), 'The block is there');
    end;

    // ---- Chat proxies (AC04, AC05) ----

    /// <summary>Verifies that the shared proxy's chat completions request holds exactly one block, the fresh one, and that a second request gets a later clock.</summary>
    [Test]
    procedure ChatCompletions_OneFreshBlock_AndLaterRequestGetsLaterClock()
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Proxy: Codeunit "LangModel Chat Proxy ori";
        Mock: Codeunit "LLM 100 HTTP Mock";
        Seam: Codeunit "LLM Session Time Seam";
        ToolServer: Codeunit "MCP Tool Server ori";
        Cached: Text;
        First: Text;
        Second: Text;
    begin
        Cached := ToolServer.Bootstrap('');
        BindSeam(Seam, TwoClocks());
        Mock.Configure('{"choices":[{"finish_reason":"stop","message":{"role":"assistant","content":"done"}}]}');
        BindSubscription(Mock);
        SetUpArgument(TempArgument);
        Proxy.SendChatMessage(TempArgument, ChatPayload(), 'Authorization');
        First := ChatCompletionsSystem(Mock.GetBody(1));
        Proxy.SendChatMessage(TempArgument, ChatPayload(), 'Authorization');
        Second := ChatCompletionsSystem(Mock.GetBody(2));
        UnbindSubscription(Mock);
        UnbindSubscription(Seam);
        AssertFreshOneBlock(First, '2026-11-06T10:00:00Z');
        AssertFreshOneBlock(Second, '2026-11-06T10:01:00Z');
        Assert.AreEqual(Cached, ToolServer.Bootstrap(''), 'The cached Bootstrap text is unchanged');
    end;

    /// <summary>Verifies that the Responses request holds exactly one block, the fresh one.</summary>
    [Test]
    procedure Responses_OneFreshBlock()
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Proxy: Codeunit "LangModel Chat Proxy ori";
        Mock: Codeunit "LLM 100 HTTP Mock";
        Seam: Codeunit "LLM Session Time Seam";
        Request: JsonObject;
        InputToken: JsonToken;
        ItemToken: JsonToken;
        ContentToken: JsonToken;
        Extras: JsonObject;
    begin
        BindSeam(Seam, TwoClocks());
        Mock.Configure('{"output":[{"type":"message","content":[{"type":"output_text","text":"done"}]}]}');
        BindSubscription(Mock);
        SetUpArgument(TempArgument);
        Proxy.SendChatMessageResponses(TempArgument, ChatPayload(), 'Authorization', Extras);
        UnbindSubscription(Mock);
        UnbindSubscription(Seam);
        Request.ReadFrom(Mock.GetBody(1));
        Request.Get('input', InputToken);
        InputToken.AsArray().Get(0, ItemToken);
        ItemToken.AsObject().Get('content', ContentToken);
        AssertFreshOneBlock(ContentToken.AsValue().AsText(), '2026-11-06T10:00:00Z');
    end;

    /// <summary>Verifies that the Anthropic request holds exactly one block, the fresh one.</summary>
    [Test]
    procedure Anthropic_OneFreshBlock()
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Proxy: Codeunit "Anthropic LangModel Proxy ori";
        Mock: Codeunit "LLM 100 HTTP Mock";
        Seam: Codeunit "LLM Session Time Seam";
        Request: JsonObject;
        SystemToken: JsonToken;
    begin
        BindSeam(Seam, TwoClocks());
        Mock.Configure('{"stop_reason":"end_turn","content":[{"type":"text","text":"done"}]}');
        BindSubscription(Mock);
        SetUpArgument(TempArgument);
        Proxy.SendChatMessage(TempArgument, ChatPayload());
        UnbindSubscription(Mock);
        UnbindSubscription(Seam);
        Request.ReadFrom(Mock.GetBody(1));
        Request.Get('system', SystemToken);
        AssertFreshOneBlock(SystemToken.AsValue().AsText(), '2026-11-06T10:00:00Z');
    end;

    /// <summary>Verifies that the Copilot system prompt holds exactly one block, the fresh one, and Foundation's text stays.</summary>
    [Test]
    procedure Copilot_OneFreshBlock()
    var
        Proxy: Codeunit "Copilot Chat Proxy ori";
        Seam: Codeunit "LLM Session Time Seam";
        ToolServer: Codeunit "MCP Tool Server ori";
        Payload: JsonObject;
        System: Text;
    begin
        BindSeam(Seam, TwoClocks());
        System := Proxy.BuildSystemPrompt(Payload);
        UnbindSubscription(Seam);
        AssertFreshOneBlock(System, '2026-11-06T10:00:00Z');
        Assert.IsTrue(System.Contains('IDENTITY:'), 'Foundation''s Bootstrap text around the block is kept');
        Assert.IsTrue(ToolServer.Bootstrap('').Contains('as of this session start'), 'The cached Bootstrap still holds the session-start block');
    end;

    /// <summary>Verifies that chat proxies keep Foundation's own block when no fresh one is available.</summary>
    [Test]
    procedure Copilot_FoundationFails_KeepsTheCachedBlock()
    var
        Proxy: Codeunit "Copilot Chat Proxy ori";
        Seam: Codeunit "LLM Session Time Seam";
        Payload: JsonObject;
        System: Text;
    begin
        Seam.Fail();
        BindSubscription(Seam);
        System := Proxy.BuildSystemPrompt(Payload);
        UnbindSubscription(Seam);
        Assert.AreEqual(1, CountBlocks(System), 'Foundation''s cached block remains, once');
    end;

    // ---- helpers ----

    local procedure Lf(): Text
    var
        LineFeed: Char;
    begin
        LineFeed := 10;
        exit(Format(LineFeed));
    end;

    local procedure Cr(): Text
    var
        CarriageReturn: Char;
    begin
        CarriageReturn := 13;
        exit(Format(CarriageReturn));
    end;

    local procedure Initialize()
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
    begin
        MockProvider.Reset();
        MockProvider.SetIsConfigured(true);
        MockProvider.SetCompleteResponse('{"text":"mock completion"}');
        if BifrostLanguageModel.Get(ModelCodeTok) then
            BifrostLanguageModel.Delete(true);
        BifrostLanguageModel.Init();
        BifrostLanguageModel.Code := ModelCodeTok;
        BifrostLanguageModel."Chat Provider" := Enum::"Bifrost LangModel Prov. ori"::Mock;
        BifrostLanguageModel.Insert(true);
    end;

    local procedure Complete(RequestBody: Text; LanguageId: Integer) ResponseJson: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        EmptyTaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
        ResponseContentType: Text[100];
        ResponseText: Text;
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        RequestContent.AddText(RequestBody);
        Dispatcher.EnqueueAndProcess("Message Type ori"::"LLM.Prompt.Complete", "Message Version ori"::"1.0", '', '', 'text/json', RequestContent, EmptyTaskId, LanguageId, MessageId, ResponseContent, ResponseContentType, ResponseTime);
        GlobalLanguage(PreviousLanguage);
        ResponseContent.GetSubText(ResponseText, 1);
        Assert.IsTrue(ResponseJson.ReadFrom(ResponseText), ResponseText);
    end;

    local procedure SystemPromptOf(PayloadText: Text): Text
    var
        Payload: JsonObject;
        SystemToken: JsonToken;
    begin
        Assert.IsTrue(Payload.ReadFrom(PayloadText), 'The provider received a payload');
        if Payload.Get('systemPrompt', SystemToken) then
            exit(SystemToken.AsValue().AsText());
        exit('');
    end;

    local procedure CountBlocks(Text: Text) Count: Integer
    var
        Lines: List of [Text];
        Line: Text;
    begin
        Lines := Text.Split(Lf());
        foreach Line in Lines do
            if Line.StartsWith(HeaderTok) then
                Count += 1;
    end;

    local procedure MaskClock(Text: Text) Masked: Text
    var
        Lines: List of [Text];
        Line: Text;
        Result: TextBuilder;
        First: Boolean;
    begin
        First := true;
        Lines := Text.Split(Lf());
        foreach Line in Lines do begin
            if not First then
                Result.Append(Lf());
            First := false;
            if Line.StartsWith('- Now UTC: ') or Line.StartsWith('- Now user time (') or Line.StartsWith('- Today: ') or Line.StartsWith('- Work date: ') then
                Result.Append('<clock>')
            else
                Result.Append(Line);
        end;
        Masked := Result.ToText();
    end;

    local procedure AssertFreshOneBlock(System: Text; ExpectedNowUtc: Text)
    begin
        Assert.AreEqual(1, CountBlocks(System), 'Exactly one SESSION TIME block');
        Assert.IsTrue(System.Contains('- Now UTC: ' + ExpectedNowUtc), 'The fresh clock is sent');
        Assert.IsFalse(System.Contains('as of this session start'), 'Not the cached Bootstrap block');
    end;

    local procedure BindSeam(var Seam: Codeunit "LLM Session Time Seam"; Blocks: List of [Text])
    begin
        Seam.Serve(Blocks);
        BindSubscription(Seam);
    end;

    local procedure TwoClocks() Blocks: List of [Text]
    begin
        Blocks.Add(FreshBlockAt('10:00:00'));
        Blocks.Add(FreshBlockAt('10:01:00'));
    end;

    local procedure FreshBlockAt(Clock: Text): Text
    begin
        exit(Join3('SESSION TIME (fresh test block):', '- Now UTC: 2026-11-06T' + Clock + 'Z', '- Today: 2026-11-06 Friday'));
    end;

    local procedure NewBlock(): Text
    begin
        exit(Join3(Join2('SESSION TIME (fresh test block):', '- Now UTC: 2026-11-06T10:00:00Z'),
            '- Now user time (GMT Standard Time, UTC+00:00): 2026-11-06T10:00:00+00:00',
            Join2('- Today: 2026-11-06 Friday', '- Weeks start on Monday.')));
    end;

    local procedure NewBlockWithWorkDate(): Text
    begin
        exit(Join3(Join2('SESSION TIME (fresh test block):', '- Now UTC: 2026-11-06T10:00:00Z'),
            '- Now user time (GMT Standard Time, UTC+00:00): 2026-11-06T10:00:00+00:00',
            Join3('- Today: 2026-11-06 Friday', '- Work date: 2026-11-09', '- Weeks start on Monday.')));
    end;

    local procedure UnknownZoneBlock(): Text
    begin
        exit(Join3(Join2('SESSION TIME (fresh test block):', '- Now UTC: 2026-11-06T10:00:00Z'),
            '- User time zone: unknown; using UTC for Today.',
            Join2('- Today: 2026-11-06 Friday', '- Weeks start on Monday.')));
    end;

    local procedure OldBlock(WithWorkDate: Boolean): Text
    begin
        if WithWorkDate then
            exit(Join3('SESSION TIME (old test block):', '- Now UTC: 2026-01-01T00:00:00Z', Join2('- Today: 2026-01-01 Thursday', '- Work date: 2026-02-02')));
        exit(Join3('SESSION TIME (old test block):', '- Now UTC: 2026-01-01T00:00:00Z', '- Today: 2026-01-01 Thursday'));
    end;

    local procedure Join2(First: Text; Second: Text): Text
    var
        Result: TextBuilder;
    begin
        Result.Append(First);
        Result.AppendLine();
        Result.Append(Second);
        exit(Result.ToText());
    end;

    local procedure Join3(First: Text; Second: Text; Third: Text): Text
    begin
        exit(Join2(Join2(First, Second), Third));
    end;

    local procedure GetArrayText(Items: JsonArray; Index: Integer): Text
    var
        ItemToken: JsonToken;
    begin
        Items.Get(Index, ItemToken);
        exit(ItemToken.AsValue().AsText());
    end;

    local procedure ChatPayload() PayloadText: Text
    var
        PayloadObject: JsonObject;
        Messages: JsonArray;
        Message: JsonObject;
    begin
        Message.Add('role', 'user');
        Message.Add('content', 'hello');
        Messages.Add(Message);
        PayloadObject.Add('messages', Messages);
        PayloadObject.Add('model', 'test-model');
        PayloadObject.WriteTo(PayloadText);
    end;

    local procedure ChatCompletionsSystem(Body: Text): Text
    var
        Request: JsonObject;
        MessagesToken: JsonToken;
        MessageToken: JsonToken;
        ContentToken: JsonToken;
    begin
        Request.ReadFrom(Body);
        Request.Get('messages', MessagesToken);
        MessagesToken.AsArray().Get(0, MessageToken);
        MessageToken.AsObject().Get('content', ContentToken);
        exit(ContentToken.AsValue().AsText());
    end;

    local procedure SetUpArgument(var TempArgument: Record "Bifrost Chat Argument ori" temporary)
    begin
        TempArgument.Init();
        TempArgument."Base URL" := 'https://mock.test.local';
        TempArgument.Model := 'test-model';
        TempArgument.SetApiKey(AsSecret('test-key'));
    end;

    local procedure AsSecret(Value: Text) Secret: SecretText
    begin
        Secret := Value;
    end;
}
