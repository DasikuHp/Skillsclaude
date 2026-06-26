using Godot;

// C# (.NET 8) en Godot 4.6. ResourceUid es accesible (guias viejas que dicen
// lo contrario estan desactualizadas). OJO: C# NO corre en export web.
public partial class ResourceIO : RefCounted
{
    public static Error SaveItem(Resource item, string path)
    {
        Error err = ResourceSaver.Save(item, path);
        if (err != Error.Ok)
            GD.PushError($"save failed: {err}");
        return err;
    }

    public static T LoadByUid<T>(string uidOrPath) where T : Resource
    {
        if (!ResourceLoader.Exists(uidOrPath))
        {
            GD.PushError($"resource not found: {uidOrPath}");
            return null;
        }
        return ResourceLoader.Load<T>(uidOrPath);
    }

    public static string ResolveUid(string uidText)
    {
        long id = ResourceUid.TextToId(uidText);
        return ResourceUid.HasId(id) ? ResourceUid.GetIdPath(id) : string.Empty;
    }
}
