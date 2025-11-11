using Godot;

namespace CatPlatform.Tail
{
    /// <summary>
    /// Segmento da cauda usado apenas para representar visualmente a posição.
    /// Colisões 3D e físicas não são mais necessárias.
    /// </summary>
    public partial class TailSegment : Node2D
    {
        [Export(PropertyHint.None)]
        public int IndexInArray;

        // Tornando Node2D exportável, mas retornando como Tail seguro
        [Export(PropertyHint.None)]
        public Node2D TailNode;

        public Tail Tail => TailNode as Tail;

        [Export(PropertyHint.None)]
        public TailSegment ParentSegment;

        // --- Para visualização / efeitos futuros ---
        [Export(PropertyHint.Range, "0.0,1.0,0.01")]
        public float Stickiness { get; set; } = 0.8f;

        [Export(PropertyHint.Range, "0.0,1.0,0.01")]
        public float BounceFactor { get; set; } = 0.05f;

        [Export(PropertyHint.Range, "0.0,1.0,0.01")]
        public float TangentialFriction { get; set; } = 0.6f;

        public override void _Ready()
        {
            // Protege contra TailNode nulo ou do tipo errado
            if (TailNode != null && Tail == null)
            {
                GD.PrintErr($"O nó {TailNode.Name} não tem o script Tail, não será usado.");
            }

            // Opcional: criar CollisionShape2D padrão apenas se quiser efeito visual ou debug
            var collision = GetNodeOrNull<CollisionShape2D>("CollisionShape2D");
            if (collision == null)
            {
                collision = new CollisionShape2D();
                collision.Shape = new CircleShape2D { Radius = 6f };
                AddChild(collision);
            }
        }
    }
}