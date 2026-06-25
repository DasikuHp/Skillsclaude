using Godot;

// Locomoción RPG en Godot 4.6 con .NET 8.
// AnimationTree (BlendSpace2D + StateMachine), root motion vía accumulator,
// e IK de pie con TwoBoneIK3D (API por índice sobre setting_count).
public partial class PlayerLocomotion : CharacterBody3D
{
    [Export] public float MoveSpeed { get; set; } = 4.0f;
    [Export] public NodePath TreePath { get; set; }

    [Signal] public delegate void AttackStartedEventHandler();

    // En 4.6 los nombres de parámetro/track son StringName. String y StringName NO
    // autoconvierten (#64171); cachéalos. Tras migrar a 4.6 hay que RECOMPILAR el
    // ensamblado C# por el cambio String -> StringName en los track names.
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
        Quaternion rot = _tree.GetRootMotionRotationAccumulator(); // struct por valor
        Vector3 pos = _tree.GetRootMotionPosition();               // delta local
        Transform = Transform with { Basis = new Basis(rot) * Transform.Basis.Orthonormalized() };
        Vector3 motion = Transform.Basis * pos;
        Velocity = delta > 0f ? motion / delta : Vector3.Zero;
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
