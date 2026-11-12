namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.Utilities;

/// <summary>Self-contained MCP fixture probe for issue 116. Dispatches the real prompt types and cleans its own model and uploads.</summary>
codeunit 96070 "LLM116 Probe ori" implements "Msg Interface ori"
{
    Access = Internal;

    /// <summary>Enables the sandbox-only test helper.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>No table filter is exposed.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Describes the fixture probe.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit('Runs a mock-provider staged attachment scenario through Ask or Complete and cleans its fixtures.');
    end;

    /// <summary>Returns the outbound message direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>Seeds owned files, invokes a real prompt message and reports mock observations plus cleanup.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Model: Record "Bifrost Language Model ori";
        Tools: Codeunit "LangModel Test Tools";
        Mock: Codeunit "Mock Bifrost Chat Provider";
        Staging: Codeunit "Blob Staging ori";
        Blob: Codeunit "Temp Blob";
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        Request: JsonObject;
        Data: JsonObject;
        Item: JsonObject;
        Items: JsonArray;
        Result: JsonObject;
        PromptResponse: JsonObject;
        Payload: JsonObject;
        MessageType: Enum "Message Type ori";
        Output: OutStream;
        Input: InStream;
        FirstId: Guid;
        SecondId: Guid;
        EmptyId: Guid;
        MessageId: Guid;
        ModelCode: Code[20];
        Scenario: Text;
        ContentType: Text;
        ResponseText: Text;
        ResponseTime: Duration;
        ResponseContentType: Text[100];
        HadFirst: Boolean;
        HadSecond: Boolean;
        Token: JsonToken;
    begin
        if not Tools.AssertNotProduction(Argument) then
            exit;
        Request := Argument.GetRequestJson();
        Scenario := Tools.GetText(Request, 'scenario');
        if Scenario = 'cleanupForeign' then begin
            CleanupForeignFixture(Argument);
            exit;
        end;
        MessageType := Enum::"Message Type ori"::"LLM.Prompt.Complete";
        if Tools.GetText(Request, 'type') = 'LLM.Prompt.Ask' then
            MessageType := Enum::"Message Type ori"::"LLM.Prompt.Ask";
        ModelCode := CopyStr('T116-' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(ModelCode));
        Model.Code := ModelCode;
        Model."Chat Provider" := Enum::"Bifrost LangModel Prov. ori"::Mock;
        if Scenario = 'limit' then
            Model."Attachment Limit Bytes" := 1;
        Model.Insert(false); // Mock-only fixture has no secret registration or value.
        Mock.Reset();
        Mock.SetIsConfigured(true);
        Mock.SetSendResponse('{"type":"reply","reply":"fixture accepted"}');
        Mock.SetCompleteResponse('{"reply":"fixture accepted"}');
        ContentType := 'text/plain';
        if Scenario = 'mime' then
            ContentType := 'application/zip';
        Blob.CreateOutStream(Output, TextEncoding::UTF8);
        Output.WriteText('LM116 owned fixture');
        Blob.CreateInStream(Input);
        FirstId := Staging.Create(Input, 'lm116.txt', ContentType, 'LM116 MCP');
        Item.Add('stagingId', Format(FirstId, 0, 4));
        if Scenario = 'unknown' then
            Item.Replace('stagingId', Format(CreateGuid(), 0, 4));
        if Scenario = 'consumed' then
            Staging.Take(FirstId, Blob);
        if Scenario = 'foreign' then
            Item.Replace('stagingId', Format(ForeignFixtureId(), 0, 4));
        if Scenario = 'extra' then
            Item.Add('data', 'forbidden');
        Items.Add(Item);
        if Scenario = 'multiple' then begin
            Blob.CreateOutStream(Output, TextEncoding::UTF8);
            Output.WriteText('second file');
            Blob.CreateInStream(Input);
            SecondId := Staging.Create(Input, 'second.txt', 'text/plain', 'LM116 MCP');
            Clear(Item);
            Item.Add('stagingId', Format(SecondId, 0, 4));
            Items.Add(Item);
        end;
        Data.Add('attachments', Items);
        Data.Add('roleCode', ModelCode);
        if MessageType = Enum::"Message Type ori"::"LLM.Prompt.Ask" then
            Data.Add('question', 'Read the attached file')
        else
            Data.Add('prompt', 'Read the attached file');
        Data.WriteTo(ResponseText);
        RequestContent.AddText(ResponseText);
        Dispatcher.EnqueueAndProcess(MessageType, Enum::"Message Version ori"::"1.0", '', '', 'text/json', RequestContent, EmptyId, GlobalLanguage(), MessageId, ResponseContent, ResponseContentType, ResponseTime);
        ResponseContent.GetSubText(ResponseText, 1);
        PromptResponse.ReadFrom(ResponseText);
        if MessageType = Enum::"Message Type ori"::"LLM.Prompt.Ask" then
            ResponseText := Mock.GetLastSendPayload()
        else
            ResponseText := Mock.GetLastCompletePayload();
        if ResponseText <> '' then
            if not Payload.ReadFrom(ResponseText) then
                Clear(Payload);
        Result.Add('promptResponse', PromptResponse);
        Result.Add('providerCalled', Mock.WasCompletePromptCalled() or Mock.WasSendChatMessageCalled());
        if Payload.Get('files', Token) then
            Result.Add('providerFiles', Token);
        HadFirst := Staging.Exists(FirstId);
        HadSecond := Staging.Exists(SecondId);
        Result.Add('firstConsumed', not HadFirst);
        if HadFirst then
            Staging.Take(FirstId, Blob);
        if HadSecond then
            Staging.Take(SecondId, Blob);
        Model.Get(ModelCode);
        Model.Delete(false);
        Result.Add('cleanupVerified', not Staging.Exists(FirstId) and not Staging.Exists(SecondId) and not Model.Get(ModelCode));
        Result.Add('status', 'Success');
        Argument.SetResponseJson(Result);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
    local procedure ForeignFixtureId(): Guid
    var
        Rows: RecordRef;
        FixtureField: FieldRef;
        StagingId: Guid;
        OwnerId: Guid;
    begin
        Rows.Open(10078382);
        Rows.ReadIsolation := IsolationLevel::ReadCommitted;
        FixtureField := Rows.Field(6);
        FixtureField.SetRange('LM116 synthetic foreign fixture');
        if not Rows.FindFirst() then
            Error('The LM116 foreign fixture has not been installed.');
        FixtureField := Rows.Field(Rows.SystemCreatedByNo());
        OwnerId := FixtureField.Value();
        if OwnerId = UserSecurityId() then
            Error('The LM116 fixture must have a different persisted creator.');
        FixtureField := Rows.Field(Rows.SystemIdNo());
        StagingId := FixtureField.Value();
        Rows.Close();
        exit(StagingId);
    end;

    local procedure CleanupForeignFixture(var Argument: Record "Message Argument ori")
    var
        Rows: RecordRef;
        FixtureField: FieldRef;
        Result: JsonObject;
        Deleted: Integer;
    begin
        Rows.Open(10078382);
        Rows.ReadIsolation := IsolationLevel::UpdLock;
        Rows.FilterGroup(2);
        FixtureField := Rows.Field(6);
        FixtureField.SetRange('LM116 synthetic foreign fixture');
        FixtureField := Rows.Field(3);
        FixtureField.SetRange('LM116-PRIVATE-FOREIGN.txt');
        Rows.FilterGroup(0);
        if Rows.FindSet() then
            repeat
                Rows.Delete(false);
                Deleted += 1;
            until Rows.Next() = 0;
        Result.Add('cleanupVerified', Rows.IsEmpty());
        Result.Add('deleted', Deleted);
        Result.Add('status', 'Success');
        Rows.Close();
        Argument.SetResponseJson(Result);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

}
