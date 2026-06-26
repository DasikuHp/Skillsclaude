using Godot;

// Equivalente C# (.NET 8) del peer connect + RPC. NOTA: C# NO corre en web export.
public partial class Net : Node
{
    private const int Port = 7777;

    public override void _Ready()
    {
        // Señales de la API, no del peer.
        Multiplayer.PeerConnected += OnPeerConnected;
        Multiplayer.PeerDisconnected += OnPeerDisconnected;
        Multiplayer.ConnectedToServer += () => GD.Print($"connected, id={Multiplayer.GetUniqueId()}");
        Multiplayer.ConnectionFailed += () => GD.PushError("connection_failed");
    }

    public void HostGame()
    {
        var peer = new ENetMultiplayerPeer();
        Error err = peer.CreateServer(Port, 8);
        if (err != Error.Ok) { GD.PushError($"CreateServer failed: {err}"); return; }
        Multiplayer.MultiplayerPeer = peer;  // host = id 1
        AddPlayer(1);
    }

    public void JoinGame(string ip)
    {
        var peer = new ENetMultiplayerPeer();
        Error err = peer.CreateClient(ip, Port);
        if (err != Error.Ok) { GD.PushError($"CreateClient failed: {err}"); return; }
        Multiplayer.MultiplayerPeer = peer;
    }

    private void OnPeerConnected(long id)
    {
        if (Multiplayer.IsServer())
            AddPlayer((int)id);
    }

    private void OnPeerDisconnected(long id) { /* despawn server-side */ }

    private void AddPlayer(int id) { /* spawner.Spawn(id) en server */ }

    // OJO: default de TransferMode en C# es Reliable (en GDScript es unreliable) - GH-docs#8874.
    [Rpc(MultiplayerApi.RpcMode.AnyPeer, CallLocal = true,
         TransferMode = MultiplayerPeer.TransferModeEnum.Reliable)]
    public void RequestAttack(int targetId)
    {
        if (!Multiplayer.IsServer()) return;
        int sender = Multiplayer.GetRemoteSenderId();  // valida; no confíes en args
        GD.Print($"attack from {sender} -> {targetId}");
        // Invocar con MethodName.X (StringName generado), NO con string literal ni .rpc():
        Rpc(MethodName.ApplyDamage, targetId, 10);          // broadcast desde authority
        // RpcId(1, MethodName.RequestAttack, targetId);    // 1 = solo server (0 = todos menos yo)
    }

    [Rpc(MultiplayerApi.RpcMode.Authority, CallLocal = true,
         TransferMode = MultiplayerPeer.TransferModeEnum.Reliable)]
    public void ApplyDamage(int targetId, int dmg)
    {
        GD.Print($"apply {dmg} to {targetId}");
    }
}
