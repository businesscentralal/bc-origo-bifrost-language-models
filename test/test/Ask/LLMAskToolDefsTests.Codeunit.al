namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests that the three request builders (chat completions, Responses, Anthropic) send only the allowed tools, in the
/// first round and, through the conversation state, in the later rounds, and send all tools when no list is given
/// (language-models#100 AC01, AC02). The provider is answered by LLM 100 HTTP Mock; nothing leaves the service.
/// </summary>
codeunit 96045 "LLM Ask Tool Defs Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure ChatCompletions_AllowedToolsFilterRoundOneAndTwo()
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Proxy: Codeunit "LangModel Chat Proxy ori";
        Mock: Codeunit "LLM 100 HTTP Mock";
        State: Text;
        Response: Text;
    begin
        BindMock(Mock, ChatToolCallAnswer());
        SetUpArgument(TempArgument);

        Response := Proxy.SendChatMessage(TempArgument, Payload(true), 'Authorization');
        Assert.AreEqual(1, Mock.GetCallCount(), 'One provider request');
        AssertOnlyTwoTools(Mock, 1);

        State := StateOf(Response);
        Mock.Configure(ChatTextAnswer());
        Proxy.ContinueWithToolResults(TempArgument, State, ToolResults(), 'Authorization');
        Assert.AreEqual(1, Mock.GetCallCount(), 'One more request');
        AssertOnlyTwoTools(Mock, 1);
        UnbindMock(Mock);
    end;

    [Test]
    procedure ChatCompletions_WithoutAllowedTools_SendsTheFullList_RegistryUntouched()
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Proxy: Codeunit "LangModel Chat Proxy ori";
        Server: Codeunit "MCP Tool Server ori";
        Mock: Codeunit "LLM 100 HTTP Mock";
        ServerTools: JsonArray;
        Count: Integer;
        Index: Integer;
    begin
        Count := Server.GetToolCount();
        BindMock(Mock, ChatTextAnswer());
        SetUpArgument(TempArgument);
        Proxy.SendChatMessage(TempArgument, Payload(false), 'Authorization');
        Server.ListTools(ServerTools);
        Assert.AreEqual(ServerTools.Count(), Mock.GetToolNames(1).Count(), 'Full ListTools list');

        // A filtered request does not change the registry
        for Index := 1 to 3 do begin
            Mock.Configure(ChatTextAnswer());
            Proxy.SendChatMessage(TempArgument, Payload(true), 'Authorization');
        end;
        Assert.AreEqual(Count, Server.GetToolCount(), 'GetToolCount unchanged');
        UnbindMock(Mock);
    end;

    [Test]
    procedure Responses_AllowedToolsFilterRoundOneAndTwo()
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Proxy: Codeunit "LangModel Chat Proxy ori";
        Mock: Codeunit "LLM 100 HTTP Mock";
        State: Text;
        Response: Text;
        Extras: JsonObject;
    begin
        BindMock(Mock, ResponsesToolCallAnswer());
        SetUpArgument(TempArgument);

        Response := Proxy.SendChatMessageResponses(TempArgument, Payload(true), 'Authorization', Extras);
        AssertOnlyTwoTools(Mock, 1);

        State := StateOf(Response);
        Mock.Configure(ResponsesTextAnswer());
        Proxy.ContinueWithToolResultsResponses(TempArgument, State, ToolResults(), 'Authorization', Extras);
        AssertOnlyTwoTools(Mock, 1);
        UnbindMock(Mock);
    end;

    [Test]
    procedure Responses_WithoutAllowedTools_SendsTheFullList()
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Proxy: Codeunit "LangModel Chat Proxy ori";
        Server: Codeunit "MCP Tool Server ori";
        Mock: Codeunit "LLM 100 HTTP Mock";
        ServerTools: JsonArray;
        Extras: JsonObject;
    begin
        BindMock(Mock, ResponsesTextAnswer());
        SetUpArgument(TempArgument);
        Proxy.SendChatMessageResponses(TempArgument, Payload(false), 'Authorization', Extras);
        Server.ListTools(ServerTools);
        Assert.AreEqual(ServerTools.Count(), Mock.GetToolNames(1).Count(), 'Full ListTools list');
        UnbindMock(Mock);
    end;

    [Test]
    procedure Anthropic_AllowedToolsFilterRoundOneAndTwo()
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Proxy: Codeunit "Anthropic LangModel Proxy ori";
        Mock: Codeunit "LLM 100 HTTP Mock";
        State: Text;
        Response: Text;
    begin
        BindMock(Mock, AnthropicToolUseAnswer());
        SetUpArgument(TempArgument);

        Response := Proxy.SendChatMessage(TempArgument, Payload(true));
        AssertOnlyTwoTools(Mock, 1);

        State := StateOf(Response);
        Mock.Configure(AnthropicTextAnswer());
        Proxy.ContinueWithToolResults(TempArgument, State, ToolResults());
        AssertOnlyTwoTools(Mock, 1);
        UnbindMock(Mock);
    end;

    [Test]
    procedure Anthropic_WithoutAllowedTools_SendsTheFullList()
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Proxy: Codeunit "Anthropic LangModel Proxy ori";
        Server: Codeunit "MCP Tool Server ori";
        Mock: Codeunit "LLM 100 HTTP Mock";
        ServerTools: JsonArray;
    begin
        BindMock(Mock, AnthropicTextAnswer());
        SetUpArgument(TempArgument);
        Proxy.SendChatMessage(TempArgument, Payload(false));
        Server.ListTools(ServerTools);
        Assert.AreEqual(ServerTools.Count(), Mock.GetToolNames(1).Count(), 'Full ListTools list');
        UnbindMock(Mock);
    end;

    [Test]
    procedure EmptyAllowedTools_SendsNoTools()
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Proxy: Codeunit "LangModel Chat Proxy ori";
        Mock: Codeunit "LLM 100 HTTP Mock";
        PayloadObject: JsonObject;
        NoTools: JsonArray;
        PayloadText: Text;
    begin
        BindMock(Mock, ChatTextAnswer());
        SetUpArgument(TempArgument);
        PayloadObject.Add('messages', MessagesArray());
        PayloadObject.Add('model', 'test-model');
        PayloadObject.Add('allowedTools', NoTools);
        PayloadObject.WriteTo(PayloadText);
        Proxy.SendChatMessage(TempArgument, PayloadText, 'Authorization');
        Assert.AreEqual(0, Mock.GetToolNames(1).Count(), 'allowedTools [] offers no tools');
        UnbindMock(Mock);
    end;

    local procedure AssertOnlyTwoTools(var Mock: Codeunit "LLM 100 HTTP Mock"; Index: Integer)
    var
        Names: List of [Text];
    begin
        Names := Mock.GetToolNames(Index);
        Assert.AreEqual(2, Names.Count(), 'Exactly the allowed tools');
        Assert.IsTrue(Names.Contains('get_records'), 'get_records');
        Assert.IsTrue(Names.Contains('get_fields'), 'get_fields');
    end;

    local procedure BindMock(var Mock: Codeunit "LLM 100 HTTP Mock"; Answer: Text)
    begin
        Mock.Configure(Answer);
        BindSubscription(Mock);
    end;

    local procedure UnbindMock(var Mock: Codeunit "LLM 100 HTTP Mock")
    begin
        UnbindSubscription(Mock);
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

    local procedure Payload(WithAllowedTools: Boolean) PayloadText: Text
    var
        PayloadObject: JsonObject;
        Allowed: JsonArray;
    begin
        PayloadObject.Add('messages', MessagesArray());
        PayloadObject.Add('model', 'test-model');
        if WithAllowedTools then begin
            Allowed.Add('get_records');
            Allowed.Add('get_fields');
            PayloadObject.Add('allowedTools', Allowed);
        end;
        PayloadObject.WriteTo(PayloadText);
    end;

    local procedure MessagesArray() Messages: JsonArray
    var
        Message: JsonObject;
    begin
        Message.Add('role', 'user');
        Message.Add('content', 'hello');
        Messages.Add(Message);
    end;

    local procedure StateOf(ResponseText: Text): Text
    var
        ResponseObject: JsonObject;
        StateToken: JsonToken;
    begin
        ResponseObject.ReadFrom(ResponseText);
        Assert.IsTrue(ResponseObject.Get('conversationState', StateToken), 'The answer is a tool_calls answer with state: ' + ResponseText);
        exit(StateToken.AsValue().AsText());
    end;

    local procedure ToolResults(): Text
    begin
        exit('[{"id":"c1","name":"get_records","result":"{}","isError":false}]');
    end;

    local procedure ChatToolCallAnswer(): Text
    begin
        exit('{"choices":[{"finish_reason":"tool_calls","message":{"role":"assistant","content":null,"tool_calls":[{"id":"c1","type":"function","function":{"name":"get_records","arguments":"{}"}}]}}]}');
    end;

    local procedure ChatTextAnswer(): Text
    begin
        exit('{"choices":[{"finish_reason":"stop","message":{"role":"assistant","content":"done"}}]}');
    end;

    local procedure ResponsesToolCallAnswer(): Text
    begin
        exit('{"output":[{"type":"function_call","call_id":"c1","name":"get_records","arguments":"{}"}]}');
    end;

    local procedure ResponsesTextAnswer(): Text
    begin
        exit('{"output":[{"type":"message","content":[{"type":"output_text","text":"done"}]}]}');
    end;

    local procedure AnthropicToolUseAnswer(): Text
    begin
        exit('{"stop_reason":"tool_use","content":[{"type":"tool_use","id":"c1","name":"get_records","input":{}}]}');
    end;

    local procedure AnthropicTextAnswer(): Text
    begin
        exit('{"stop_reason":"end_turn","content":[{"type":"text","text":"done"}]}');
    end;
}
