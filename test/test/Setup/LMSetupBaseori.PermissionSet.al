namespace Origo.Bifrost.LanguageModels.Test;

using System.Apps;
using System.Environment.Configuration;

/// <summary>
/// Minimal platform baseline for the licence-administrator Setup-open regression.
/// Bifrost roles do not grant Microsoft tables; this fixture supplies Guided Experience
/// view and indirect NAV App Setting read only.
/// </summary>
permissionset 96039 "LM Setup Base ori"
{
    Assignable = true;
    Caption = 'LM Setup Platform', Locked = true;
    IncludedPermissionSets = "Guided Experience - View";
    Permissions = tabledata "NAV App Setting" = r;
}
