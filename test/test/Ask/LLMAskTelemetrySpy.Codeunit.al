namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;

/// <summary>
/// Records the ORI-LM-ASK-* events that "LLM Ask Telemetry ori" logs (#102), through its test seam. Bind it with
/// BindSubscription; it reads and writes nothing in the database.
/// </summary>
codeunit 96067 "LLM Ask Telemetry Spy"
{
    EventSubscriberInstance = Manual;

    var
        EventIds: List of [Text];
        EventVerbosities: List of [Text];
        EventDimensions: List of [Dictionary of [Text, Text]];

    procedure Count(): Integer
    begin
        exit(EventIds.Count());
    end;

    procedure GetId(Index: Integer): Text
    begin
        exit(EventIds.Get(Index));
    end;

    procedure GetVerbosity(Index: Integer): Text
    begin
        exit(EventVerbosities.Get(Index));
    end;

    procedure GetDimensions(Index: Integer): Dictionary of [Text, Text]
    begin
        exit(EventDimensions.Get(Index));
    end;

    procedure GetIds(): List of [Text]
    begin
        exit(EventIds);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LLM Ask Telemetry ori", 'OnAfterEmit', '', false, false)]
    local procedure OnAfterEmit(EventId: Text; EventVerbosity: Verbosity; Dimensions: Dictionary of [Text, Text])
    begin
        EventIds.Add(EventId);
        EventVerbosities.Add(Format(EventVerbosity));
        EventDimensions.Add(Dimensions);
    end;
}
