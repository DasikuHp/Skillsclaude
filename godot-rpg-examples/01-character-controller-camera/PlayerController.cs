// PlayerController.cs
// Controlador de personaje + camara 3a persona para Godot 4.6 (.NET 8).
// Misma jerarquia de escena que player_controller.gd:
//   Player (CharacterBody3D) <- este script
//   |-- CollisionShape3D (CapsuleShape3D)
//   |-- Visual (Node3D)
//   `-- CameraPivot (Node3D)
//       `-- SpringArm3D
//           `-- Camera3D
//
// Gotchas C# 4.6:
//   - Velocity/Rotation son struct por valor: copiar -> mutar -> reasignar.
//   - _PhysicsProcess recibe double: castear a (float) para Vector3.
//   - Breaking 4.6 (afecta a la seccion de animacion, no a este script):
//     la API expuesta de AnimationPlayer paso de String a StringName (GH-110767);
//     revisa los literales string que pasas a APIs de animacion (puede requerir
//     StringName explicito). La recompilacion del ensamblado es automatica al build con 4.6.
using Godot;

public partial class PlayerController : CharacterBody3D
{
    [Signal] public delegate void JumpedEventHandler();
    [Signal] public delegate void LandedEventHandler();

    [Export] public float Speed { get; set; } = 5.0f;
    [Export] public float JumpVelocity { get; set; } = 4.5f;
    [Export(PropertyHint.Range, "0.0005,0.01,0.0001")]
    public float MouseSens { get; set; } = 0.003f;
    [Export] public float PitchMin { get; set; } = -1.2f;
    [Export] public float PitchMax { get; set; } = 0.4f;
    [Export] public float CameraDistance { get; set; } = 4.0f;

    // StringName cacheados: evita allocs por frame al consultar acciones.
    private static readonly StringName MoveLeft = "move_left";
    private static readonly StringName MoveRight = "move_right";
    private static readonly StringName MoveForward = "move_forward";
    private static readonly StringName MoveBack = "move_back";
    private static readonly StringName Jump = "jump";
    private static readonly StringName UiCancel = "ui_cancel";

    private Node3D _cameraPivot = null!;
    private SpringArm3D _springArm = null!;
    private float _pitch;
    private bool _wasOnFloor = true;

    public override void _Ready()
    {
        _cameraPivot = GetNode<Node3D>("CameraPivot");
        _springArm = GetNode<SpringArm3D>("CameraPivot/SpringArm3D");

        Input.MouseMode = Input.MouseModeEnum.Captured;

        FloorSnapLength = 0.5f;
        FloorMaxAngle = Mathf.DegToRad(46.0f);
        FloorStopOnSlope = true;

        _springArm.SpringLength = CameraDistance;
        _springArm.Margin = 0.2f;
        _springArm.AddExcludedObject(GetRid());

        var s = new SphereShape3D { Radius = 0.3f };
        _springArm.Shape = s;
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event is InputEventMouseMotion mm
            && Input.MouseMode == Input.MouseModeEnum.Captured)
        {
            _cameraPivot.RotateY(-mm.Relative.X * MouseSens);
            _pitch = Mathf.Clamp(_pitch - mm.Relative.Y * MouseSens, PitchMin, PitchMax);

            Vector3 rot = _cameraPivot.Rotation;
            rot.X = _pitch;
            _cameraPivot.Rotation = rot;
        }
        else if (@event.IsActionPressed(UiCancel))
        {
            Input.MouseMode = Input.MouseModeEnum.Visible;
        }
    }

    public override void _PhysicsProcess(double delta)
    {
        float dt = (float)delta;
        Vector3 velocity = Velocity;

        if (!IsOnFloor())
            velocity += GetGravity() * dt;

        if (Input.IsActionJustPressed(Jump) && IsOnFloor())
        {
            velocity.Y = JumpVelocity;
            EmitSignal(SignalName.Jumped);
        }

        Vector2 input = Input.GetVector(MoveLeft, MoveRight, MoveForward, MoveBack);
        Vector3 dir = _cameraPivot.GlobalBasis * new Vector3(input.X, 0.0f, input.Y);
        dir.Y = 0.0f;
        dir = dir.Normalized();

        if (dir != Vector3.Zero)
        {
            velocity.X = dir.X * Speed;
            velocity.Z = dir.Z * Speed;
        }
        else
        {
            velocity.X = Mathf.MoveToward(velocity.X, 0.0f, Speed);
            velocity.Z = Mathf.MoveToward(velocity.Z, 0.0f, Speed);
        }

        Velocity = velocity;
        MoveAndSlide();

        bool grounded = IsOnFloor();
        if (grounded && !_wasOnFloor)
            EmitSignal(SignalName.Landed);
        _wasOnFloor = grounded;
    }
}
