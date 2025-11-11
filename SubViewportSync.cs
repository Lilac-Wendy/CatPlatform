using Godot;

[Tool]
public partial class SubViewportSync : SubViewport
{
    [Export] public SubViewport TargetViewport { get; set; }
    [Export] public Camera3D SourceCamera3D { get; set; }
    [Export] public Camera2D TargetCamera2D { get; set; }
    [Export] public bool MatchViewportSize = true;

    public override void _Process(double delta)
    {
        if (TargetViewport == null || SourceCamera3D == null)
            return;

        if (MatchViewportSize)
        {
            Vector2 visibleSize = GetViewport().GetVisibleRect().Size;
            TargetViewport.Size = new Vector2I((int)visibleSize.X, (int)visibleSize.Y);
        }

        if (TargetCamera2D != null)
            SyncCamera2DTo3D();
    }

    private void SyncCamera2DTo3D()
    {
        Rect2 visible = GetViewport().GetVisibleRect();
        TargetCamera2D.Position = visible.Size / 2f;
        TargetCamera2D.Zoom = Vector2.One;
    }
}