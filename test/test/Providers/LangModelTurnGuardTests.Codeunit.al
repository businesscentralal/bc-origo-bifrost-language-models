namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests of the turn rules shared by every provider path (#40): the history budget from the model's context size,
/// the repair of tool messages that lost their partner, and the one follow-up for figures stated without a tool call.
/// </summary>
codeunit 96022 "LangModel Turn Guard Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TurnGuard: Codeunit "LangModel Turn Guard ori";

    [Test]
    procedure HistoryBudget_FollowsTheContextSize()
    var
        NoTools: JsonArray;
    begin
        // [SCENARIO] AC1: a 32k model gets a budget from its own context size, a 200k model a larger one
        // [WHEN] the budget is computed for 32,000 and 200,000 context tokens with 4,096 reply tokens
        // [THEN] it is (context - reply) x 3.5 x 0.9 characters
        Assert.AreEqual(Round((32000 - 4096) * 3.5 * 0.9, 1, '<'), TurnGuard.HistoryBudgetChars(32000, 4096, NoTools), '32k budget');
        Assert.AreEqual(Round((200000 - 4096) * 3.5 * 0.9, 1, '<'), TurnGuard.HistoryBudgetChars(200000, 4096, NoTools), '200k budget');
        Assert.AreNotEqual(80000, TurnGuard.HistoryBudgetChars(32000, 4096, NoTools), 'The fixed 80000 is gone');
    end;

    [Test]
    procedure HistoryBudget_ZeroContextUsesTheFallback()
    var
        NoTools: JsonArray;
    begin
        // [SCENARIO] AC1: a model without a context size uses 32,000 tokens
        Assert.AreEqual(TurnGuard.HistoryBudgetChars(32000, 1000, NoTools), TurnGuard.HistoryBudgetChars(0, 1000, NoTools), 'Fallback is 32,000 tokens');
    end;

    [Test]
    procedure HistoryBudget_ToolDefinitionsAndTinyContextKeepAFloor()
    var
        Tools: JsonArray;
        NoTools: JsonArray;
        Tool: JsonObject;
    begin
        // [SCENARIO] the tool definitions take their share of the context, and the budget never drops below 2,000 tokens
        Tool.Add('name', PadStr('', 3500, 'x'));
        Tools.Add(Tool);
        Assert.IsTrue(TurnGuard.HistoryBudgetChars(32000, 1000, Tools) < TurnGuard.HistoryBudgetChars(32000, 1000, NoTools), 'Tools reduce the budget');
        Assert.AreEqual(Round(2000 * 3.5 * 0.9, 1, '<'), TurnGuard.HistoryBudgetChars(4000, 8000, NoTools), 'Floor of 2,000 tokens');
    end;

    [Test]
    procedure RemoveOrphanedToolMessages_LeadingToolMessageIsRemoved()
    var
        Messages: JsonArray;
        First: JsonToken;
    begin
        // [SCENARIO] AC3: after a trim, no request starts (after system) with a tool message whose call is gone
        Messages.Add(Msg('system', 'rules'));
        Messages.Add(ToolMsg('call_gone', '{"rows":1}'));
        Messages.Add(Msg('user', 'what is total outstanding?'));

        TurnGuard.RemoveOrphanedToolMessages(Messages);

        Assert.AreEqual(2, Messages.Count(), 'The orphaned tool message is removed');
        Messages.Get(1, First);
        Assert.AreEqual('user', First.AsObject().GetText('role'), 'The user question follows the system message');
    end;

    [Test]
    procedure RemoveOrphanedToolMessages_PairedCallsAreKept()
    var
        Messages: JsonArray;
    begin
        // [SCENARIO] a complete tool call and its result stay
        Messages.Add(Msg('user', 'how many customers?'));
        Messages.Add(AssistantCall('call_1'));
        Messages.Add(ToolMsg('call_1', '{"count":5}'));

        TurnGuard.RemoveOrphanedToolMessages(Messages);

        Assert.AreEqual(3, Messages.Count(), 'Nothing is removed');
    end;

    [Test]
    procedure RemoveOrphanedToolMessages_CallWithoutResultIsDropped()
    var
        Messages: JsonArray;
    begin
        // [SCENARIO] an assistant tool call whose result was trimmed away is removed (it has no text)
        Messages.Add(Msg('user', 'question'));
        Messages.Add(AssistantCall('call_lost'));
        Messages.Add(Msg('user', 'next question'));

        TurnGuard.RemoveOrphanedToolMessages(Messages);

        Assert.AreEqual(2, Messages.Count(), 'The unanswered tool call is removed');
    end;

    [Test]
    procedure RemoveOrphanedResponsesItems_DropsUnpairedItems()
    var
        Input: JsonArray;
    begin
        // [SCENARIO] AC4: the Responses input keeps only function_call / function_call_output pairs
        Input.Add(Msg('user', 'question'));
        Input.Add(ResponsesItem('function_call', 'c1'));
        Input.Add(ResponsesItem('function_call_output', 'c1'));
        Input.Add(ResponsesItem('function_call_output', 'c_orphan'));
        Input.Add(ResponsesItem('function_call', 'c_unanswered'));

        TurnGuard.RemoveOrphanedResponsesItems(Input);

        Assert.AreEqual(3, Input.Count(), 'Only the pair and the message stay');
    end;

    [Test]
    procedure NeedsFigureCheck_FiguresWithoutToolCall_IsTrue()
    var
        Messages: JsonArray;
    begin
        // [SCENARIO] AC6: a balance stated without any tool call in the turn is caught
        Messages.Add(Msg('user', 'what is the total outstanding?'));
        Messages.Add(Msg('assistant', 'The total outstanding is 6,283,771.42 ISK.'));

        Assert.IsTrue(TurnGuard.NeedsFigureCheck(Messages, 'The total outstanding is 6,283,771.42 ISK.'), 'Figures without a tool call need the check');
    end;

    [Test]
    procedure NeedsFigureCheck_FiguresAfterToolCall_IsFalse()
    var
        Messages: JsonArray;
    begin
        // [SCENARIO] figures that follow a tool call in the turn are not questioned
        Messages.Add(Msg('user', 'what is the total outstanding?'));
        Messages.Add(AssistantCall('call_1'));
        Messages.Add(ToolMsg('call_1', '{"balance":234687.5}'));
        Messages.Add(Msg('assistant', 'The total outstanding is 234,687.50 ISK.'));

        Assert.IsFalse(TurnGuard.NeedsFigureCheck(Messages, 'The total outstanding is 234,687.50 ISK.'), 'A tool was called');
    end;

    [Test]
    procedure NeedsFigureCheck_ToolCallInAnEarlierTurn_DoesNotCount()
    var
        Messages: JsonArray;
    begin
        // [SCENARIO] a tool call of an earlier turn does not cover figures in the current turn
        Messages.Add(Msg('user', 'how many customers?'));
        Messages.Add(AssistantCall('call_1'));
        Messages.Add(ToolMsg('call_1', '{"count":5}'));
        Messages.Add(Msg('assistant', 'There are 5 customers.'));
        Messages.Add(Msg('user', 'and the total outstanding?'));
        Messages.Add(Msg('assistant', 'It is 1.250.000 kr.'));

        Assert.IsTrue(TurnGuard.NeedsFigureCheck(Messages, 'It is 1.250.000 kr.'), 'The current turn called no tool');
    end;

    [Test]
    procedure NeedsFigureCheck_AfterTheFollowUp_IsFalse()
    var
        Messages: JsonArray;
    begin
        // [SCENARIO] the follow-up is sent at most once per turn (no loop)
        Messages.Add(Msg('user', 'what is the total outstanding?'));
        Messages.Add(Msg('assistant', 'It is 6,283,771.42 ISK.'));
        Messages.Add(Msg('user', TurnGuard.GetVerifyFiguresPrompt()));
        Messages.Add(Msg('assistant', 'I estimate 6,000,000 ISK.'));

        Assert.IsFalse(TurnGuard.NeedsFigureCheck(Messages, 'I estimate 6,000,000 ISK.'), 'The follow-up was already sent in this turn');
    end;

    [Test]
    procedure NeedsFigureCheck_AnthropicToolUseBlocksCount()
    var
        Messages: JsonArray;
        Blocks: JsonArray;
        Block: JsonObject;
        Assistant: JsonObject;
    begin
        // [SCENARIO] the Anthropic format's tool_use block counts as a tool call
        Messages.Add(Msg('user', 'what is the total outstanding?'));
        Block.Add('type', 'tool_use');
        Block.Add('id', 'tu_1');
        Blocks.Add(Block);
        Assistant.Add('role', 'assistant');
        Assistant.Add('content', Blocks);
        Messages.Add(Assistant);

        Assert.IsFalse(TurnGuard.NeedsFigureCheck(Messages, 'It is 234,687.50 ISK.'), 'tool_use counts');
    end;

    [Test]
    procedure ContainsFigures_RecognisesAmountsOnly()
    begin
        // [SCENARIO] four digits or a separator is an amount; small counts are not
        Assert.IsTrue(TurnGuard.ContainsFigures('Balance 6283771'), 'Seven digits');
        Assert.IsTrue(TurnGuard.ContainsFigures('Balance 234,687.50'), 'Thousands and decimals');
        Assert.IsTrue(TurnGuard.ContainsFigures('12,50 kr.'), 'Decimal comma');
        Assert.IsFalse(TurnGuard.ContainsFigures('There are 5 customers.'), 'A small count');
        Assert.IsFalse(TurnGuard.ContainsFigures('I cannot verify that.'), 'No number');
        Assert.IsFalse(TurnGuard.ContainsFigures(''), 'Empty reply');
    end;

    local procedure Msg(Role: Text; Content: Text) Message: JsonObject
    begin
        Message.Add('role', Role);
        Message.Add('content', Content);
    end;

    local procedure ToolMsg(CallId: Text; Content: Text) Message: JsonObject
    begin
        Message.Add('role', 'tool');
        Message.Add('tool_call_id', CallId);
        Message.Add('content', Content);
    end;

    local procedure AssistantCall(CallId: Text) Message: JsonObject
    var
        Calls: JsonArray;
        Call: JsonObject;
    begin
        Call.Add('id', CallId);
        Call.Add('type', 'function');
        Calls.Add(Call);
        Message.Add('role', 'assistant');
        Message.Add('content', '');
        Message.Add('tool_calls', Calls);
    end;

    local procedure ResponsesItem(ItemType: Text; CallId: Text) Item: JsonObject
    begin
        Item.Add('type', ItemType);
        Item.Add('call_id', CallId);
    end;
}
