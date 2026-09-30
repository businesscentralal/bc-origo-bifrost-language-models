namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;

/// <summary>
/// Tests the LLM.Prompt.Complete discovery and message contract.
/// </summary>
codeunit 96019 "LLM Prompt Compl Contract Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Contract_HasRequiredChaptersAndValidContent()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
    begin
        // [SCENARIO] LLM.Prompt.Complete exposes its implementation contract as chapters.
        Assert.IsTrue(ContractMgt.GetContract("Message Type ori"::"LLM.Prompt.Complete", Contract), 'hasContract');
        Assert.IsTrue(Contract.Contains('envelope'), 'envelope');
        Assert.IsTrue(Contract.Contains('parameters'), 'parameters');
        Assert.IsTrue(Contract.Contains('response'), 'response');
        Assert.IsTrue(Contract.Contains('errors'), 'errors');
        Assert.IsTrue(Contract.Contains('effect'), 'effect');
        Assert.IsTrue(Contract.Contains('examples'), 'examples');
        Assert.IsTrue(Contract.Contains('overview'), 'overview');
        Assert.IsTrue(Contract.Contains('notes'), 'notes');
        Assert.IsFalse(Contract.Contains('target'), 'target is not declared');
        Assert.IsTrue(Contract.Contains('related'), 'related');
        Assert.IsFalse(Contract.Contains('workflow'), 'workflow is not declared');
    end;

    [Test]
    procedure Discovery_HasLanguageModelSpecificText()
    var
        Discovery: Interface "Msg Discovery ori";
        MessageType: Enum "Message Type ori";
    begin
        // [SCENARIO] The type can be found and distinguished from dedicated message types.
        MessageType := "Message Type ori"::"LLM.Prompt.Complete";
        Discovery := MessageType;
        Assert.IsTrue(Discovery.GetKeywords().Contains('one-shot AI completion'), 'English keywords');
        Assert.IsTrue(Discovery.GetSelectionDescription().Contains('without tools'), 'selection description');
    end;

    [Test]
    procedure CompatibilityMarkdownHelp_IsEmpty()
    var
        Argument: Record "Message Argument ori";
        Implementation: Codeunit "LLM Prompt Compl Impl ori";
    begin
        // [SCENARIO] The current Foundation interface still accepts the legacy help call, but the contract owns the content.
        Implementation.GetMessageHelpAsMarkdownDocument(Argument);
        Assert.AreEqual('', Argument.GetResponseMarkdown(), 'legacy markdown help');
    end;
}