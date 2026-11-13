namespace Origo.Bifrost.LanguageModels.Test;

/// <summary>Covers the internal fixture table so AppSourceCop can see a matching permission set. Tests do not assign it.</summary>
permissionset 96172 "LLM116 Fixture ori"
{
    Access = Internal;
    Assignable = false;
    Caption = 'LLM116 Fixture', Locked = true;
    Permissions = table "LLM116 Fixture Seed ori" = X,
                  tabledata "LLM116 Fixture Seed ori" = RIMD;
}
