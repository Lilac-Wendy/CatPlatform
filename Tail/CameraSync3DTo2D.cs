using Godot;

public partial class CameraSync3DTo2D : Camera2D
{
    [Export] public Camera3D SourceCamera { get; set; }
    [Export] public Camera2D TargetCamera2D { get; set; }
    [Export] public SubViewport TargetViewport { get; set; }
    
    [Export] public float FixedZoom { get; set; } = 0.5f;

    public override void _Process(double delta)
    {
        if (SourceCamera == null || TargetCamera2D == null || TargetViewport == null)
            return;

        TargetCamera2D.Position = TargetViewport.Size / (int)2f;
        TargetCamera2D.Zoom = Vector2.One * FixedZoom;
    }
}