namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;

/// <summary>
/// Lets an install-permission test run "Copilot Install ori" without TableData on
/// "Bifrost Language Model ori" or Foundation "Setup ori". Assigned only by those tests.
/// </summary>
permissionset 96019 "LM Install Exec Tst"
{
    Assignable = true;
    Caption = 'LM Install Execute Test', MaxLength = 30, Comment = 'is-IS=LM uppsetning keyrsla próf';

    Permissions =
        codeunit "Copilot Install ori" = X,
        codeunit "LangModel Secrets ori" = X;
}
