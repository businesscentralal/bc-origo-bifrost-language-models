namespace Origo.Bifrost.LanguageModels.Test;

using System.TestTools.TestRunner;

/// <summary>
/// Runs the full Language Models suite in Icelandic with standard codeunit isolation and result reporting.
/// Select this runner on the command line test page for the 1039 release-verification run.
/// </summary>
codeunit 96081 "LM Icelandic Test Runner ori"
{
    Subtype = TestRunner;
    TableNo = "Test Method Line";
    TestIsolation = Codeunit;
    Permissions = tabledata "AL Test Suite" = rimd,
                  tabledata "Test Method Line" = rimd;

    trigger OnRun()
    begin
        PreviousLanguage := GlobalLanguage();
        CurrentTestMethodLine.Copy(Rec);
        TestRunnerMgt.RunTests(Rec);
        GlobalLanguage(PreviousLanguage);
    end;

    trigger OnBeforeTestRun(CodeunitID: Integer; CodeunitName: Text; FunctionName: Text; FunctionTestPermissions: TestPermissions): Boolean
    begin
        GlobalLanguage(1039);
        exit(TestRunnerMgt.PlatformBeforeTestRun(
            CodeunitID, CopyStr(CodeunitName, 1, 30), CopyStr(FunctionName, 1, 128), FunctionTestPermissions,
            CurrentTestMethodLine."Test Suite", CurrentTestMethodLine.GetFilter("Line No.")));
    end;

    trigger OnAfterTestRun(CodeunitID: Integer; CodeunitName: Text; FunctionName: Text; FunctionTestPermissions: TestPermissions; IsSuccess: Boolean)
    begin
        TestRunnerMgt.PlatformAfterTestRun(
            CodeunitID, CopyStr(CodeunitName, 1, 30), CopyStr(FunctionName, 1, 128), FunctionTestPermissions, IsSuccess,
            CurrentTestMethodLine."Test Suite", CurrentTestMethodLine.GetFilter("Line No."));
        GlobalLanguage(PreviousLanguage);
    end;

    var
        CurrentTestMethodLine: Record "Test Method Line";
        TestRunnerMgt: Codeunit "Test Runner - Mgt";
        PreviousLanguage: Integer;
}
