using System.Collections.Generic;
using Godot;
using System.ComponentModel;

namespace CatPlatform.Tail
{
    public partial class Tail : Node2D
    {
        [ExportCategory("=== TAIL STRUCTURE ===")]
        [Export(PropertyHint.Range, "3,50,1")]
        public int SegmentCount { get; set; } = 15;

        [Export(PropertyHint.Range, "10,500,1")]
        public float TailLength { get; set; } = 120f;

        [ExportCategory("=== ELASTICITY & STIFFNESS ===")]
        // SegmentSpacingFactor foi removido.
        
        [Export(PropertyHint.Range, "1,50,1")] // Range aumentado
        public int ConstraintIterations { get; set; } = 10; // Default aumentado

        [Export(PropertyHint.Range, "0.1,5.0,0.1")]
        public float ConstraintStrength { get; set; } = 1.0f;

        [ExportCategory("=== WEIGHT & MOVEMENT ===")]
        [Export(PropertyHint.Range, "0,1000,1")]
        public float VerletGravity { get; set; } = 180f;

        [Export(PropertyHint.Range, "0.0,0.1,0.001")]
        public float VerletDamping { get; set; } = 0.012f;

        [Export(PropertyHint.Range, "0.0,2.0,0.01")]
        public float InertiaFactor { get; set; } = 1.0f; // Agora você pode usar 1.0f

        [ExportCategory("=== FOLLOWING & LAG ===")]
        // BaseLagStrength e LagFalloff foram removidos.
        
        [Export(PropertyHint.Range, "0.0,200.0,1.0")] // Range de 0 permite desligar
        public float TailFollowSpeed { get; set; } = 50f;

        [ExportCategory("=== ADVANCED CONTROL ===")]
        [Export]
        public bool ControlByTip { get; set; } = false;

        [Export(PropertyHint.Range, "0.0,1.0,0.01")]
        public float CurveSmoothness { get; set; } = 0.3f;

        [Export(PropertyHint.Range, "0.0,100.0,1.0")]
        public float ExternalForceResistance { get; set; } = 5.0f;

        [ExportCategory("=== PERFORMANCE ===")]
        [Export]
        public bool PerformanceMode { get; set; } = false;

        [ExportCategory("=== 3D REFERENCES ===")]
        [Export]
        public Node3D TailStart3D { get; set; }

        [Export]
        public Node3D TailEnd3D { get; set; }

        [Export]
        public Camera3D MainCamera { get; set; }

        [Export]
        public SubViewport TargetViewport { get; set; }

        // Variáveis privadas
        private List<Vector2> positions = new();
        private List<Vector2> prevPositions = new();
        private List<bool> locked = new();
        private List<float> segmentLengths = new();
        private bool _isReady;
        private Line2D _line;

        public enum TailPreset
        {
            Custom,
            RealisticCat,
            FloppyFlexible,
            StiffControlled,
            WhipLike,
            HeavyDrag,
            FelineNatural
        }

        [Export]
        public TailPreset CurrentPreset
        {
            get { return TailPreset.Custom; }
            set { ApplyPreset(value); }
        }

        public override void _Ready()
        {
            _line = GetNodeOrNull<Line2D>("Line2D");
            InitializeVerlet();
            _isReady = true;
        }

        private void InitializeVerlet()
        {
            positions.Clear();
            prevPositions.Clear();
            locked.Clear();
            segmentLengths.Clear();

            Vector2 start = TailStart3D != null ? ProjectTo2D(TailStart3D.GlobalPosition) : GlobalPosition;
            Vector2 end = TailEnd3D != null ? ProjectTo2D(TailEnd3D.GlobalPosition) : GlobalPosition + Vector2.Right * TailLength;

            Vector2 dir = (end - start).Normalized();
            
            // --- CORREÇÃO "CORDA" ---
            // O SegmentSpacingFactor foi removido daqui para garantir que o comprimento
            // de descanso da corda seja exatamente o TailLength.
            float segLen = TailLength / (SegmentCount - 1);

            for (int i = 0; i < SegmentCount; i++)
            {
                Vector2 p = start + dir * segLen * i;
                positions.Add(p);
                prevPositions.Add(p);
                segmentLengths.Add(segLen);
                
                if (ControlByTip)
                    locked.Add(i == SegmentCount - 1); 
                else
                    locked.Add(i == 0);
            }
        }

        private void ApplyPreset(TailPreset preset)
        {
            // Atualizando presets para a nova lógica (sem SpacingFactor, LagStrength, etc.)
            switch (preset)
            {
                case TailPreset.RealisticCat:
                    SegmentCount = 15;
                    TailLength = 120f;
                    ConstraintIterations = 8; // Aumentado
                    ConstraintStrength = 1.0f;
                    VerletGravity = 180f;
                    VerletDamping = 0.012f;
                    InertiaFactor = 1.0f;
                    TailFollowSpeed = 50f;
                    CurveSmoothness = 0.3f;
                    ExternalForceResistance = 5.0f;
                    break;

                case TailPreset.FloppyFlexible:
                    SegmentCount = 25;
                    TailLength = 150f;
                    ConstraintIterations = 4; // Baixo para ser molenga
                    ConstraintStrength = 0.7f;
                    VerletGravity = 120f;
                    VerletDamping = 0.005f;
                    InertiaFactor = 1.0f;
                    TailFollowSpeed = 30f;
                    CurveSmoothness = 0.5f;
                    ExternalForceResistance = 1.0f;
                    break;

                case TailPreset.StiffControlled:
                    SegmentCount = 8;
                    TailLength = 100f;
                    ConstraintIterations = 15; // Alto para ser rígido
                    ConstraintStrength = 1.5f;
                    VerletGravity = 250f;
                    VerletDamping = 0.02f;
                    InertiaFactor = 0.7f;
                    TailFollowSpeed = 80f;
                    CurveSmoothness = 0.1f;
                    ExternalForceResistance = 10.0f;
                    break;
                    
                // (Outros presets podem ser ajustados de forma similar)
            }

            if (_isReady)
                InitializeVerlet();
        }

        public override void _PhysicsProcess(double delta)
        {
            if (!_isReady) return;
            float dt = (float)delta;

            // Trava a base (âncora da corda)
            if (!ControlByTip && TailStart3D != null && MainCamera != null && TargetViewport != null)
            {
                Vector2 base2D = ProjectTo2D(TailStart3D.GlobalPosition);
                positions[0] = base2D;
                prevPositions[0] = base2D;
            }

            // Simula a física (inércia e gravidade)
            StepVerlet(dt);
            
            // Guia a ponta (opcional) e trava a ponta (se ControlByTip)
            ApplyTipControl(dt);

            // Suaviza as curvas
            if (CurveSmoothness > 0.01f)
                ApplyCurveSmoothing();

            // Desenha a linha
            UpdateLine();
        }

        private void StepVerlet(float dt)
        {
            float dt2 = dt * dt;
            int iterations = PerformanceMode ? Mathf.Max(1, ConstraintIterations / 2) : ConstraintIterations;

            for (int i = 0; i < positions.Count; i++)
            {
                if (locked[i]) continue;

                Vector2 pos = positions[i];
                Vector2 prev = prevPositions[i];
                Vector2 velocity = (pos - prev) * (1f - VerletDamping) * InertiaFactor;
                
                Vector2 forces = Vector2.Down * VerletGravity;
                if (ExternalForceResistance > 0.01f)
                    forces -= velocity * ExternalForceResistance * dt;
                    
                Vector2 next = pos + velocity + forces * dt2;

                prevPositions[i] = pos;
                positions[i] = next;
            }

            // Aplica as restrições (puxa a corda para ficar firme)
            // Isso agora acontece *depois* da física e *antes* do desenho.
            for (int iter = 0; iter < iterations; iter++)
                SatisfyConstraints();
        }

        private void SatisfyConstraints()
        {
            for (int i = 0; i < positions.Count - 1; i++)
            {
                int j = i + 1;
                Vector2 delta = positions[j] - positions[i];
                float dist = delta.Length();
                float restLength = segmentLengths[i];
                
                if (dist == 0) continue;
                float diff = (dist - restLength) / dist * ConstraintStrength;

                if (locked[i])
                    positions[j] -= delta * diff;
                else if (locked[j])
                    positions[i] += delta * diff;
                else
                {
                    positions[i] += delta * diff * 0.5f;
                    positions[j] -= delta * diff * 0.5f;
                }
            }
        }

        private void ApplyCurveSmoothing()
        {
            for (int i = 1; i < positions.Count - 1; i++)
            {
                Vector2 prev = positions[i - 1];
                Vector2 next = positions[i + 1];
                Vector2 desired = (prev + next) * 0.5f;
                positions[i] = positions[i].Lerp(desired, CurveSmoothness * 0.1f);
            }
        }

        // Renomeado de ApplyFollowLag para ApplyTipControl para ser mais claro
        private void ApplyTipControl(float delta)
        {
            if (MainCamera == null || TargetViewport == null)
                return;

            if (ControlByTip && TailEnd3D != null)
            {
                // Modo: Controlar pela ponta. Trava a ponta.
                Vector2 end2D = ProjectTo2D(TailEnd3D.GlobalPosition);
                positions[^1] = end2D;
                prevPositions[^1] = end2D; // Trava rígida da ponta
            }
            else if (!ControlByTip && TailEnd3D != null && TailFollowSpeed > 0.01f)
            {
                // Modo: Controlar pela base (padrão). 
                // A base JÁ FOI TRAVADA no _PhysicsProcess.
                // Aqui, a ponta "tenta" seguir o TailEnd3D suavemente.
                Vector2 end2D = ProjectTo2D(TailEnd3D.GlobalPosition);
                positions[^1] = positions[^1].Lerp(end2D, TailFollowSpeed * delta);
            }
        }

        private void UpdateLine()
        {
            if (_line == null) return;
            _line.Points = positions.ToArray();
        }

        private Vector2 ProjectTo2D(Vector3 worldPos)
        {
            if (MainCamera == null || TargetViewport == null)
                return Vector2.Zero;

            Vector2 screenPos = MainCamera.UnprojectPosition(worldPos);
            Vector2 viewportSize = TargetViewport.Size;
            Vector2 norm = screenPos / MainCamera.GetViewport().GetVisibleRect().Size;
            return new Vector2(norm.X * viewportSize.X, norm.Y * viewportSize.Y);
        }

        // Métodos públicos
        public void SetTipPosition(Vector2 position, float influence = 1.0f)
        {
            if (positions.Count > 0)
                positions[^1] = positions[^1].Lerp(position, influence);
        }

        public void SetBasePosition(Vector2 position, float influence = 1.0f)
        {
            if (positions.Count > 0)
                positions[0] = positions[0].Lerp(position, influence);
        }

        public void AddForce(Vector2 force, float influence = 1.0f)
        {
            for (int i = 0; i < positions.Count; i++)
            {
                if (!locked[i])
                    positions[i] += force * influence * (1.0f - (float)i / positions.Count);
            }
        }
    }
}