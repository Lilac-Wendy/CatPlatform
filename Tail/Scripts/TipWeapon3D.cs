using System.Collections.Generic;
using Godot;
namespace CatPlatform.Tail.Scripts;

public partial class TipWeapon3D : Area3D
{
    [ExportGroup("Stats")]
    [Export] public float Damage = 10f;
    [Export] public float KnockbackForce = 500f;

    [ExportGroup("Cooldown")]
    [Export(PropertyHint.Range, "0.1, 2.0, 0.01")] 
    public float HitCooldown = 0.5f;

    [ExportGroup("Feedback")]
    [Export] public PackedScene HitEffectScene;
    [Export] public AudioStreamPlayer3D HitSound;

    private bool _isActive = true;
    private List<Node3D> _targetsOnCooldown = new List<Node3D>();

    public override void _Ready()
    {
        BodyEntered += OnTargetEntered;
        CollisionLayer = 8;  // tail_weapon
        CollisionMask = 2;   // enemies
    }

    private void OnTargetEntered(Node3D body)
    {
        if (!_isActive || _targetsOnCooldown.Contains(body))
            return;

        if (ShouldIgnoreTarget(body))
            return;

        ApplyHit(body);
    }

    private bool ShouldIgnoreTarget(Node3D target)
    {
        return target.IsInGroup("player") || target == GetParent();
    }

    private void ApplyHit(Node3D target)
    {
        GD.Print($"🎯 Tail Weapon hit: {target.Name}");

        if (target.HasMethod("TakeDamage"))
            target.Call("TakeDamage", Damage);

        if (target is RigidBody3D rb)
        {
            Vector3 dir = (rb.GlobalPosition - GlobalPosition).Normalized();
            rb.ApplyImpulse(dir * KnockbackForce);
        }

        // VFX/SFX?
        AddTargetToCooldown(target);
    }

    private async void AddTargetToCooldown(Node3D target)
    {
        _targetsOnCooldown.Add(target);
        await ToSignal(GetTree().CreateTimer(HitCooldown), "timeout");
        
        if (IsInstanceValid(target) && _targetsOnCooldown.Contains(target))
            _targetsOnCooldown.Remove(target);
    }

    public void SetActive(bool value)
    {
        _isActive = value;
        Monitoring = value;
    }
}