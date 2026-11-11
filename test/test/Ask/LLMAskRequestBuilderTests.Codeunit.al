namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests the LLM.Prompt.Ask system prompt of each of the three request builders (chat completions, Responses,
/// Anthropic) on the outgoing request (language-models#101 AC13): Bootstrap once with one fresh SESSION TIME block,
/// the HEADLESS MODE block, the caller instructions, OUTPUT FORMAT only with a schema and RECORD CONTEXT only with a
/// subject; QUESTION and CONTEXT stay in the user message. The provider is answered by LLM 100 HTTP Mock.
/// </summary>
codeunit 96065 "LLM Ask Request Builder Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        ContextMarkerTok: Label 'C-CTX-AC13', Locked = true;
        RecordMarkerTok: Label 'REC-AC13-7f3a', Locked = true;

    [Test]
    procedure ChatCompletions_AskBlocks_WithSchemaAndSubject()
    begin
        // [SCENARIO AC13] chat completions with a schema and a subject
        VerifyBuilder(1, true, true);
    end;

    [Test]
    procedure ChatCompletions_AskBlocks_WithoutSchemaOrSubject()
    begin
        // [SCENARIO AC13] chat completions: no OUTPUT FORMAT and no RECORD CONTEXT when they were not sent
        VerifyBuilder(1, false, false);
    end;

    [Test]
    procedure Responses_AskBlocks_WithSchemaAndSubject()
    begin
        // [SCENARIO AC13] Responses with a schema and a subject
        VerifyBuilder(2, true, true);
    end;

    [Test]
    procedure Responses_AskBlocks_WithoutSchemaOrSubject()
    begin
        // [SCENARIO AC13] Responses without a schema or a subject
        VerifyBuilder(2, false, false);
    end;

    [Test]
    procedure Anthropic_AskBlocks_WithSchemaAndSubject()
    begin
        // [SCENARIO AC13] Anthropic with a schema and a subject
        VerifyBuilder(3, true, true);
    end;

    [Test]
    procedure Anthropic_AskBlocks_WithoutSchemaOrSubject()
    begin
        // [SCENARIO AC13] Anthropic without a schema or a subject
        VerifyBuilder(3, false, false);
    end;

    local procedure VerifyBuilder(Builder: Integer; WithSchema: Boolean; WithSubject: Boolean)
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        ChatProxy: Codeunit "LangModel Chat Proxy ori";
        AnthropicProxy: Codeunit "Anthropic LangModel Proxy ori";
        Mock: Codeunit "LLM 100 HTTP Mock";
        Seam: Codeunit "LLM Session Time Seam";
        Blocks: List of [Text];
        Extras: JsonObject;
        Body: Text;
        PayloadText: Text;
    begin
        // [GIVEN] an Ask-shaped payload: system suffix, user message with QUESTION and CONTEXT, optional record context
        PayloadText := AskPayload(WithSchema, WithSubject);
        SetUpArgument(TempArgument);
        case Builder of
            1:
                Mock.Configure('{"choices":[{"finish_reason":"stop","message":{"role":"assistant","content":"done"}}]}');
            2:
                Mock.Configure('{"output":[{"type":"message","content":[{"type":"output_text","text":"done"}]}]}');
            3:
                Mock.Configure('{"stop_reason":"end_turn","content":[{"type":"text","text":"done"}]}');
        end;
        BindSubscription(Mock);
        Blocks.Add('SESSION TIME (fresh test block):' + Lf() + '- Now UTC: 2026-11-11T01:00:00Z' + Lf() + '- Today: 2026-11-11 Wednesday');
        Seam.Serve(Blocks);
        BindSubscription(Seam);

        // [WHEN] the builder sends the first request
        case Builder of
            1:
                ChatProxy.SendChatMessage(TempArgument, PayloadText, 'Authorization');
            2:
                ChatProxy.SendChatMessageResponses(TempArgument, PayloadText, 'Authorization', Extras);
            3:
                AnthropicProxy.SendChatMessage(TempArgument, PayloadText);
        end;
        UnbindSubscription(Seam);
        UnbindSubscription(Mock);

        // [THEN] the outgoing request carries every block once, and the optional blocks only when sent
        Assert.AreEqual(1, Mock.GetCallCount(), 'one provider request');
        Body := Mock.GetBody(1);
        Assert.AreEqual(1, CountOf(Body, 'IDENTITY:'), 'Bootstrap once: ' + Body);
        Assert.AreEqual(1, CountOf(Body, 'SESSION TIME ('), 'exactly one SESSION TIME block');
        Assert.AreEqual(0, CountOf(Body, 'as of this session start'), 'the SESSION TIME block is fresh, not the cached one');
        Assert.AreEqual(1, CountOf(Body, '- Now UTC: 2026-11-11T01:00:00Z'), 'the fresh clock is sent');
        Assert.AreEqual(1, CountOf(Body, 'HEADLESS MODE:'), 'HEADLESS MODE once');
        Assert.AreEqual(1, CountOf(Body, 'CALLER INSTRUCTIONS:'), 'instructions once');
        Assert.AreEqual(1, CountOf(Body, 'Answer in one line.'), 'the instructions text once');
        if WithSchema then
            Assert.AreEqual(1, CountOf(Body, 'OUTPUT FORMAT:'), 'OUTPUT FORMAT once with a schema')
        else
            Assert.AreEqual(0, CountOf(Body, 'OUTPUT FORMAT:'), 'no OUTPUT FORMAT without a schema');
        if WithSubject then begin
            Assert.AreEqual(1, CountOf(Body, 'RECORD CONTEXT:'), 'RECORD CONTEXT once with a subject');
            Assert.AreEqual(1, CountOf(Body, RecordMarkerTok), 'the record context text once');
        end else
            Assert.AreEqual(0, CountOf(Body, 'RECORD CONTEXT:'), 'no RECORD CONTEXT without a subject');
        Assert.AreEqual(1, CountOf(Body, 'QUESTION:'), 'QUESTION once, in the user message');
        Assert.AreEqual(1, CountOf(Body, 'CONTEXT:\nC-CTX'), 'CONTEXT once, in the user message');
        // The context marker is in the user message; seen once in the whole request, it is not in the system prompt.
        Assert.AreEqual(1, CountOf(Body, ContextMarkerTok), 'the context text is not in the system prompt');
        Assert.IsTrue(CountOf(Body, 'QUESTION:\nQ-AC13\n\nCONTEXT:\nC-CTX-AC13') = 1, 'QUESTION and CONTEXT form the user message');
    end;

    local procedure AskPayload(WithSchema: Boolean; WithSubject: Boolean) PayloadText: Text
    var
        PayloadObject: JsonObject;
        Messages: JsonArray;
        Message: JsonObject;
        RecordContext: JsonObject;
        Allowed: JsonArray;
        Suffix: Text;
    begin
        Message.Add('role', 'user');
        Message.Add('content', 'QUESTION:' + Lf() + 'Q-AC13' + Lf() + Lf() + 'CONTEXT:' + Lf() + ContextMarkerTok);
        Messages.Add(Message);
        PayloadObject.Add('messages', Messages);
        PayloadObject.Add('model', 'test-model');
        Suffix := 'HEADLESS MODE:' + Lf() + 'No human is present.' + Lf() + Lf() + 'CALLER INSTRUCTIONS:' + Lf() + 'Answer in one line.';
        if WithSchema then
            Suffix += Lf() + Lf() + 'OUTPUT FORMAT:' + Lf() + '{"type":"object"}';
        PayloadObject.Add('systemSuffix', Suffix);
        if WithSubject then begin
            RecordContext.Add('table', 'Customer');
            RecordContext.Add('recordSystemId', RecordMarkerTok);
            PayloadObject.Add('recordContext', RecordContext);
        end;
        Allowed.Add('who_am_i');
        PayloadObject.Add('allowedTools', Allowed);
        PayloadObject.WriteTo(PayloadText);
    end;

    local procedure CountOf(Value: Text; Part: Text) Occurrences: Integer
    var
        Position: Integer;
    begin
        Position := StrPos(Value, Part);
        while Position > 0 do begin
            Occurrences += 1;
            Value := CopyStr(Value, Position + StrLen(Part));
            Position := StrPos(Value, Part);
        end;
    end;

    local procedure SetUpArgument(var TempArgument: Record "Bifrost Chat Argument ori" temporary)
    var
        KeyText: Text;
        KeyValue: SecretText;
    begin
        KeyText := 'test-key';
        KeyValue := KeyText;
        TempArgument.Init();
        TempArgument."Base URL" := 'https://mock.test.local';
        TempArgument.Model := 'test-model';
        TempArgument.SetApiKey(KeyValue);
    end;

    local procedure Lf() Value: Text
    begin
        Value[1] := 10;
    end;
}
