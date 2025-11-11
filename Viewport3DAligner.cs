using Godot;

[Tool]
public partial class Viewport3DAligner : SubViewport
{
    [Export] public Camera3D TargetCamera { get; set; }
    [Export] public Vector2 TargetResolution = new(512, 512);
    [Export] public bool AutoAdjustAspect = true;

    public override void _Ready()
    {
        UpdateViewportParams();
    }

    public override void _Process(double delta)
    {
        if (Engine.IsEditorHint())
            UpdateViewportParams();
    }

    private void UpdateViewportParams()
    {

        this.Size = new Vector2I((int)TargetResolution.X, (int)TargetResolution.Y);
        this.TransparentBg = true;
        this.Disable3D = false;

        this.Set("update_mode", 2);

        if (AutoAdjustAspect && TargetCamera != null)
        {
            float aspect = TargetResolution.X / TargetResolution.Y;
            TargetCamera.KeepAspect = Camera3D.KeepAspectEnum.Width;

            float fovRad = Mathf.DegToRad(TargetCamera.Fov);
            TargetCamera.Fov = Mathf.RadToDeg(fovRad * aspect);
        }
    }
}