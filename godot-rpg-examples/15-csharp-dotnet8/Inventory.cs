using Godot;
using Godot.Collections; // <-- ESTE namespace para lo que cruza al engine (exports/senales)

public partial class Inventory : Node
{
    // CORRECTO: Variant-compatible, aparece en el inspector y se serializa.
    // Si usaras System.Collections.Generic.List<int> aqui -> GD0102 (no soportado en [Export]).
    [Export] public Array<ItemResource> Items { get; set; } = new();
    [Export] public Dictionary<string, int> Counts { get; set; } = new();

    // Logica interna pura que NO cruza a Godot: usa System.Collections a tope (rapido, GC normal).
    private readonly System.Collections.Generic.List<int> _cache = new();

    public int TotalItems()
    {
        // En un loop caliente, copia a un tipo de System antes de iterar:
        // cada acceso a Godot.Collections.Array paga marshalling Variant.
        var local = new int[Items.Count];
        for (int i = 0; i < Items.Count; i++)
            local[i] = Items[i]?.Quantity ?? 0;

        int total = 0;
        foreach (int q in local) total += q;
        return total;
    }

    // Metodo generico que toca Variant -> el parametro DEBE llevar [MustBeVariant] (si no -> GD0302).
    public void AddAll<[MustBeVariant] T>(Array<T> source, Array<T> dest)
    {
        foreach (T item in source) dest.Add(item);
    }

    public void Bump(string key, int by)
    {
        // Trampa de copia (GH-42484): leer un value-type de un Godot Dictionary puede devolver
        // una COPIA. Lee, muta, REESCRIBE.
        int current = Counts.TryGetValue(key, out int v) ? v : 0;
        Counts[key] = current + by;
    }
}

// Data como Resource: autogestion por refcount, reserva Node para el arbol de escena.
public partial class ItemResource : Resource
{
    [Export] public string Name { get; set; } = "";
    [Export] public int Quantity { get; set; } = 1;
}
