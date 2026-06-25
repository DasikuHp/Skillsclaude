using Godot;

// Locomoción RPG en Godot 4.6 con .NET 8.
// AnimationTree (BlendSpace2D + StateMachine), root motion vía accumulator,
// e IK de pie con TwoBoneIK3D (API por índice sobre setting_count).
public partial class PlayerLocomotion : CharacterBody3D
{
    [Export] public float MoveSpeed { get; set; } = 4.0f;
    [Export] public NodePath TreePath { get; set; }

    [Signal] public delegate void AttackStartedEventHandler();

    // En C# los string literales se convierten IMPLÍCITAMENTE a StringName (cast
    // asignante), por lo que esto compila. Cachear en `static readonly StringName` es por
    // RENDIMIENTO: evitar alocar un StringName nuevo por frame (en _PhysicsProcess). El
    // issue #64171 (falta de autoconversión) es de GDScript, no de C#. En 4.6 (GH-110767)
    // las propiedades de NOMBRE de animación de AnimationPlayer (current_animation,
    // assigned_animation, autoplay, get_queue()) pasaron a StringName: leerlas como
    // `string` rompe a nivel de fuente.
    private static readonly StringName BlendParam = "parameters/Locomotion/blend_position";
    private static readonly StringName AttackState = "attack";

    private AnimationTree _tree;
    private AnimationNodeStateMachinePlayback _sm;
    private TwoBoneIK3D _footIkL;
    private Marker3D _footTargetL;
    private RayCast3D _footRayL;

    public override void _Ready()
    {
        _tree = GetNode<AnimationTree>(TreePath);
        _tree.Active = true;
        _sm = (AnimationNodeStateMachinePlayback)_tree.Get("parameters/playback");

        _footIkL = GetNode<TwoBoneIK3D>("Visual/Skeleton3D/FootIK_L");
        _footTargetL = GetNode<Marker3D>("Visual/Skeleton3D/FootTarget_L");
        _footRayL = GetNode<RayCast3D>("FootRay_L");

        // API por índice: primero setting_count, luego los setters de la cadena 0.
        _footIkL.SetSettingCount(1);
        _footIkL.SetRootBoneName(0, "UpperLeg.L");
        _footIkL.SetMiddleBoneName(0, "LowerLeg.L");
        _footIkL.SetEndBoneName(0, "Foot.L");
        _footIkL.SetTargetNode(0, _footIkL.GetPathTo(_footTargetL));
        _footIkL.Active = false;
    }

    public override void _PhysicsProcess(double delta)
    {
        Vector2 input = Input.GetVector("left", "right", "back", "forward");
        _tree.Set(BlendParam, input);
        ApplyRootMotion((float)delta);
        MoveAndSlide();
        UpdateFootIk();
    }

    private void ApplyRootMotion(float delta)
    {
        // Patrón canónico: corrige la posición local por el accumulator de rotación;
        // válido con cross-fade (evita el bug incremental #93821 / #95688).
        Quaternion rotAcc = _tree.GetRootMotionRotationAccumulator(); // struct por valor
        Vector3 pos = _tree.GetRootMotionPosition();                  // delta local
        Vector3 local = (rotAcc.Inverse() * Quaternion) * pos;
        Velocity = delta > 0f ? (Transform.Basis * local) / delta : Vector3.Zero;
    }

    private void UpdateFootIk()
    {
        if (_footRayL.IsColliding())
        {
            _footTargetL.GlobalPosition = _footRayL.GetCollisionPoint();
            _footIkL.Active = true;
        }
        else
        {
            _footIkL.Active = false;
        }
    }

    public void Attack()
    {
        _sm.Travel(AttackState);
        EmitSignal(SignalName.AttackStarted);
    }
}
