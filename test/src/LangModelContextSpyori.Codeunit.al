namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;

/// <summary>
/// Manually bound, test-only observation of the arguments forwarded to Foundation's context setter.
/// Records values in the bound local instance without changing production state or page execution.
/// </summary>
codeunit 96029 "LangModel Context Spy ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        CaptureCount: Integer;
        CapturedTableId: Integer;
        CapturedSystemId: Guid;
        CapturedCaption: Text;

    /// <summary>
    /// Clears the bound instance's in-memory observations between actions.
    /// </summary>
    internal procedure Reset()
    begin
        Clear(CaptureCount);
        Clear(CapturedTableId);
        Clear(CapturedSystemId);
        Clear(CapturedCaption);
    end;

    /// <summary>
    /// Returns the bound instance's observation without accessing Foundation's private state.
    /// </summary>
    /// <param name="Count">Number of setter-return events captured since reset.</param>
    /// <param name="TableId">Last forwarded table number.</param>
    /// <param name="RecordSystemId">Last forwarded record identity.</param>
    /// <param name="DataCaption">Last forwarded caption.</param>
    internal procedure ReadCapture(var Count: Integer; var TableId: Integer; var RecordSystemId: Guid; var DataCaption: Text)
    begin
        Count := CaptureCount;
        TableId := CapturedTableId;
        RecordSystemId := CapturedSystemId;
        DataCaption := CapturedCaption;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LangModel Chat Provider ori", 'OnAfterSetRecordContext', '', false, false)]
    local procedure OnAfterSetRecordContext(TableId: Integer; RecordSystemId: Guid; DataCaption: Text)
    begin
        CaptureCount += 1;
        CapturedTableId := TableId;
        CapturedSystemId := RecordSystemId;
        CapturedCaption := DataCaption;
    end;
}
