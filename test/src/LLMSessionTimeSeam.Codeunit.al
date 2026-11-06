namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;

/// <summary>Manually bound test seam for issue 99: serves a queue of fixed blocks, or fails like Foundation would, instead of the live clock.</summary>
codeunit 96062 "LLM Session Time Seam"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        Blocks: List of [Text];
        FailRequested: Boolean;
        Served: Integer;

    /// <summary>Serves the given blocks in order, then repeats the last one.</summary>
    procedure Serve(NewBlocks: List of [Text])
    begin
        Blocks := NewBlocks;
        FailRequested := false;
        Served := 0;
    end;

    /// <summary>Makes every request raise an error, as a Foundation permission or dispatch failure does.</summary>
    procedure Fail()
    begin
        Clear(Blocks);
        FailRequested := true;
        Served := 0;
    end;

    /// <summary>Number of requests answered or failed since Serve or Fail.</summary>
    procedure GetServedCount(): Integer
    begin
        exit(Served);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LLM Session Time ori", 'OnBeforeGetSessionTimeBlock', '', false, false)]
    local procedure OnBeforeGetSessionTimeBlock(var Block: Text; var Handled: Boolean)
    begin
        Served += 1;
        if FailRequested then
            Error('Simulated Foundation failure.');
        if Blocks.Count() = 0 then
            exit;
        if Served <= Blocks.Count() then
            Block := Blocks.Get(Served)
        else
            Block := Blocks.Get(Blocks.Count());
        Handled := true;
    end;
}
