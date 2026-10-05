namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests the LLM.Prompt.Complete discovery and message contract.
/// </summary>
codeunit 96019 "LLM Prompt Contract Tests"
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
    procedure Contract_NamesBothPermissionSets()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        ContractText: Text;
    begin
        // [SCENARIO] #32: the contract names Foundation's BIFROST Chat ori and this app's BIFROST LLM Chat ori for providers other than Copilot
        Assert.IsTrue(ContractMgt.GetContract("Message Type ori"::"LLM.Prompt.Complete", Contract), 'hasContract');
        Contract.WriteTo(ContractText);
        Assert.IsTrue(ContractText.Contains('BIFROST Chat ori'), 'Foundation''s chat permission set is named');
        Assert.IsTrue(ContractText.Contains('BIFROST LLM Chat ori'), 'The provider permission set is named');
        Assert.IsTrue(ContractText.Contains('not Copilot'), 'The Copilot nuance is stated');
    end;

    [Test]
    procedure Execute_MissingPrompt_IsCodedMissingParameter()
    var
        ResponseJson: JsonObject;
    begin
        // [SCENARIO] Foundation's error standard: a missing prompt answers MissingParameter on prompt with expected and nextStep
        ResponseJson := Execute('{"system":"x"}');
        AssertCodedError(ResponseJson, 'MissingParameter', 'prompt');
    end;

    [Test]
    procedure Execute_UnknownRoleCode_IsCodedRecordNotFound()
    var
        ResponseJson: JsonObject;
    begin
        // [SCENARIO] an unknown roleCode answers RecordNotFound on roleCode, with the received value
        ResponseJson := Execute('{"prompt":"Hello","roleCode":"BIFT-NOPE"}');
        AssertCodedError(ResponseJson, 'RecordNotFound', 'roleCode');
        Assert.AreEqual('BIFT-NOPE', ResponseJson.GetText('received'), 'received');
    end;

    [Test]
    procedure Execute_RoleCodeLongerThanACode_IsRecordNotFoundNotCut()
    var
        ResponseJson: JsonObject;
    begin
        // [SCENARIO] a roleCode longer than a language model code is not cut to 20 characters and matched
        ResponseJson := Execute('{"prompt":"Hello","roleCode":"BIFT-A-CODE-THAT-IS-LONGER-THAN-TWENTY"}');
        AssertCodedError(ResponseJson, 'RecordNotFound', 'roleCode');
        Assert.AreEqual('BIFT-A-CODE-THAT-IS-LONGER-THAN-TWENTY', ResponseJson.GetText('received'), 'received is the whole value');
    end;

    local procedure Execute(RequestBody: Text) ResponseJson: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        MessageVersion: Enum "Message Version ori";
        ResponseContentType: Text[100];
        ResponseText: Text;
    begin
        RequestContent.AddText(RequestBody);
        Dispatcher.Execute("Message Type ori"::"LLM.Prompt.Complete", MessageVersion::"1.0", '', '', 'text/json', RequestContent, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        Assert.IsTrue(ResponseJson.ReadFrom(ResponseText), ResponseText);
    end;

    local procedure AssertCodedError(ResponseJson: JsonObject; ExpectedCode: Text; ExpectedParameter: Text)
    var
        ResponseText: Text;
    begin
        ResponseJson.WriteTo(ResponseText);
        Assert.AreEqual('Error', ResponseJson.GetText('status'), ResponseText);
        Assert.AreEqual(ExpectedCode, ResponseJson.GetText('code'), ResponseText);
        Assert.AreEqual(ExpectedParameter, ResponseJson.GetText('parameter'), ResponseText);
        Assert.AreNotEqual('', ResponseJson.GetText('expected'), 'expected: ' + ResponseText);
        Assert.AreNotEqual('', ResponseJson.GetText('nextStep'), 'nextStep: ' + ResponseText);
    end;
}
