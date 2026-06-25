using Godot;
using System.Text.Json;

/// <summary>
/// Sistema de guardado por slots en C# / .NET 8 para Godot 4.6.
/// Usa System.Text.Json + FileAccess (no el JSON de Godot). El progreso del
/// jugador se persiste como datos planos bajo user://, sin GodotObject.
///
/// Gotcha 4.6: los nombres de tracks de AnimationPlayer pasaron de String a
/// StringName (breaking 4.5->4.6). Recompila el proyecto C# tras actualizar y
/// revisa cualquier dato de animacion serializado por nombre.
///
/// Registralo como Autoload con el nombre "SaveManager".
/// </summary>
public partial class SaveManager : Node
{
    [Signal] public delegate void GameSavedEventHandler(int slot);
    [Signal] public delegate void GameLoadedEventHandler(int slot);
    [Signal] public delegate void SaveFailedEventHandler(int slot, int error);

    private const int SaveVersion = 2;
    private const string SaveDir = "user://saves";

    // System.Text.Json NO serializa Vector3/Color/GodotObject: usa primitivas
    // (un record con float[]) y reconstruye los tipos Godot al cargar.
    private record SaveData(int Version, float Hp, float[] Pos);

    private static string SlotPath(int slot) => $"{SaveDir}/slot_{slot}.json";

    public Error SaveGame(int slot, Node3D player)
    {
        DirAccess.MakeDirRecursiveAbsolute(SaveDir);

        Vector3 pos = player.GlobalPosition;
        var data = new SaveData(SaveVersion, 80f, new[] { pos.X, pos.Y, pos.Z });
        string json = JsonSerializer.Serialize(
            data, new JsonSerializerOptions { WriteIndented = true });

        using var f = FileAccess.Open(SlotPath(slot), FileAccess.ModeFlags.Write);
        if (f is null)
        {
            Error err = FileAccess.GetOpenError();
            GD.PushError($"No se pudo abrir el save: {err}");
            EmitSignal(SignalName.SaveFailed, slot, (int)err);
            return err;
        }

        f.StoreString(json);
        EmitSignal(SignalName.GameSaved, slot);
        return Error.Ok;
    }

    public SaveData LoadGame(int slot)
    {
        string path = SlotPath(slot);
        if (!FileAccess.FileExists(path))
            return null;

        using var f = FileAccess.Open(path, FileAccess.ModeFlags.Read);
        if (f is null)
            return null;

        SaveData data = JsonSerializer.Deserialize<SaveData>(f.GetAsText());
        data = Migrate(data);
        EmitSignal(SignalName.GameLoaded, slot);
        return data;
    }

    /// <summary>Reconstruye el Vector3 desde el array [x, y, z] guardado.</summary>
    public static Vector3 ReadPosition(SaveData data) =>
        new(data.Pos[0], data.Pos[1], data.Pos[2]);

    private static SaveData Migrate(SaveData data)
    {
        if (data.Version < SaveVersion)
            return data with { Version = SaveVersion };
        return data;
    }
}
