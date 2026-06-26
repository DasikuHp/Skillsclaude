using Godot;

// C# (.NET 8). Tr() == tr(), TrN() == tr_n().
// AVISO: C# NO corre en export web (renderer Compatibility, sin .NET).
// AVISO: no confies en que el POT scanner extraiga estos Tr()/TrN().
public partial class HudCsharp : Control
{
    private int _enemyCount = 3;
    private string _playerName = "Cloud";

    public override void _Ready()
    {
        // El nombre propio no debe traducirse.
        GetNode<Label>("PlayerName").AutoTranslateMode = AutoTranslateModeEnum.Disabled;
        RefreshTexts();
    }

    public override void _Notification(int what)
    {
        if (what == NotificationTranslationChanged)
            RefreshTexts();
    }

    private void RefreshTexts()
    {
        GetNode<Label>("Title").Text = Tr("START_GAME");
        GetNode<Label>("OpenBtn").Text = Tr("MENU_OPEN", context: "verb");
        // Plural: TrN(message, pluralMessage, n, context = null)
        // OJO C#: string.Format NO entiende printf (%d); usa composite format ({0}).
        // El msgid en es.po DEBE coincidir exacto, asi que las fuentes usan {0}, no %d.
        string txt = TrN("{0} enemy", "{0} enemies", _enemyCount);
        GetNode<Label>("EnemiesKilled").Text = string.Format(txt, _enemyCount);
        GetNode<Label>("PlayerName").Text = _playerName;
    }

    public void SetLanguage(string locale)
    {
        locale = TranslationServer.StandardizeLocale(locale);
        TranslationServer.SetLocale(locale); // dispara NOTIFICATION_TRANSLATION_CHANGED
    }
}
