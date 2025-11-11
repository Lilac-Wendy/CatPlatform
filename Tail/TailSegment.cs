using Godot;

namespace CatPlatform.Tail
{

    public partial class TailSegment : Node2D
    {
        [Export(PropertyHint.None)]
        public int IndexInArray;

        [Export(PropertyHint.None)]
        public Node2D TailNode;

        public Tail Tail => TailNode as Tail;

        [Export(PropertyHint.None)]
        public TailSegment ParentSegment;

        [Export(PropertyHint.Range, "0.0,1.0,0.01")]
        public float Stickiness { get; set; } = 0.8f;

        [Export(PropertyHint.Range, "0.0,1.0,0.01")]
        public float BounceFactor { get; set; } = 0.05f;

        [Export(PropertyHint.Range, "0.0,1.0,0.01")]
        public float TangentialFriction { get; set; } = 0.6f;

        public override void _Ready()
        {

            if (TailNode != null && Tail == null)
            {
                GD.PrintErr($"O nó {TailNode.Name} não tem o script Tail, não será usado.");
            }

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