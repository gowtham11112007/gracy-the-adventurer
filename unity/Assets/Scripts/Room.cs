using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering.Universal;

[Serializable] public class RoomExit { public string side, to, arrive, gate; public int col, row; }
[Serializable] public class RoomDef
{
    public string id, name, area_name, area, mood;
    public int width, start;
    public RoomExit[] exits;
    public int[] benches;
    public string[] grid;
}
[Serializable] class RoomList { public RoomDef[] rooms; }

/// <summary>One ladder: its column, where the floor above is (top) and the ground it stands on (bottom), in units.</summary>
public struct Ladder
{
    public int col;
    public float topY, bottomY;
}

/// <summary>
/// One room of the world, built from its tile grid (Resources/Data/rooms.json, made from the Godot project by
/// tools/export_unity_data.py) the way the Godot version builds it: ground from the area's art pack, a ladder up
/// to the second floor, obstacles to hop (crate C, boulder R, barrel O, spikes ^), gems (o), the background, light,
/// Janani, the camera and the phone's buttons. Grid rows go down from row 0 to the ground (rows 10 and 11); in
/// Unity y goes up, so a tile in row r spans y = 11 - r to 12 - r. One tile is one unit.
/// Test it from the command line with  -room w6  (any room id) and  -entry left|right|up|down|bench.
/// </summary>
public class Room : MonoBehaviour
{
    public const int Rows = 12;
    public string roomId = "level1";
    public string entry = "left";

    public RoomDef Def { get; private set; }
    public Janani Player { get; private set; }
    public readonly List<Ladder> Ladders = new();
    public string Skin { get; private set; }

    static readonly Dictionary<string, string> SkinForMood = new()
    {
        { "day", "meadow" }, { "windy", "meadow" }, { "sky", "sky" }, { "golden", "desert" }, { "dusk", "graveyard" },
        { "village", "village" }, // (Level 1: the Asset Store packs, see Village)
    };
    static readonly Dictionary<string, RoomDef> all = new();
    Transform art;

    /// <summary>A room's data by its id (null if there's none).</summary>
    public static RoomDef Find(string id)
    {
        if (all.Count == 0)
            foreach (var file in new[] { "Data/rooms", "Data/levels" }) // the world's rooms, and the hand-made levels
            {
                var text = Resources.Load<TextAsset>(file);
                if (text != null)
                    foreach (var r in JsonUtility.FromJson<RoomList>(text.text).rooms)
                        all[r.id] = r;
            }
        return all.TryGetValue(id, out var def) ? def : null;
    }

    /// <summary>The top edge of a grid row, in units: where feet stand on that row.</summary>
    public static float TopY(int row) => Rows - row;

    /// <summary>The tile at a column and row (' ' outside the room).</summary>
    public char At(int c, int r) => r >= 0 && r < Rows && c >= 0 && c < Def.width ? Def.grid[r][c] : ' ';

    void Start()
    {
        Time.fixedDeltaTime = 1f / 60f; // (as in Godot: the hop is tuned to 60 steps a second)
        var args = Environment.GetCommandLineArgs();
        int i = Array.IndexOf(args, "-room");
        if (i >= 0 && i + 1 < args.Length) roomId = args[i + 1];
        i = Array.IndexOf(args, "-entry");
        if (i >= 0 && i + 1 < args.Length) entry = args[i + 1];

        if (Array.IndexOf(args, "-room") >= 0 || Array.IndexOf(args, "-autorun") >= 0)
            Flow.Showing = Flow.Screen.Level; // (test runs go straight into the level)
        else if (Array.IndexOf(args, "-map") >= 0)
            Flow.Showing = Flow.Screen.Map; // (test runs: the world map)
        else if (Flow.Playing)
            roomId = Flow.LevelId; // (the level chosen on the world map)
        Def = Find(roomId) ?? Find("level1") ?? Find("m1");
        Skin = SkinForMood.TryGetValue(Def.mood, out var s) ? s : "meadow";
        if (FindAnyObjectByType<GameInput>() == null)
            new GameObject("Input").AddComponent<GameInput>();
        GameInput.Clear();
        if (!Flow.Playing) // the title screen (mountains in the clouds) or the world map: music, wind, the menu
        {
            GameInput.Blocked = true;
            Ambience(title: true);
            if (Flow.Showing == Flow.Screen.Map) MapUI.Show();
            else MenuUI.Title();
            return;
        }
        art = new GameObject("Art").transform;
        art.SetParent(transform, false);

        BuildGround();
        BuildThings();
        BuildBackground();
        BuildLight();
        Entrance = StartFeet();
        Player = Janani.Create(this, Entrance);
        var cam = Camera.main;
        CameraFollow follow = null;
        if (cam != null)
        {
            follow = cam.GetComponent<CameraFollow>();
            if (follow == null)
                follow = cam.gameObject.AddComponent<CameraFollow>();
            follow.Follow(Player, Def.width);
        }
        if (Village)
            Ambience();
        GameInput.Blocked = false;
        HealthBar.Create(Player);
        if (TouchPad.Wanted())
            TouchPad.Create();
        LevelUI.Create(Def.area_name, Def.name);
        MenuUI.InGame();
    }

    bool Village => Skin == "village";

    /// <summary>The village's sound: birdsong and a light wind, soft music under them (the title: wind and music).</summary>
    void Ambience(bool title = false)
    {
        void Loop(string clip, float volume, bool isMusic)
        {
            var a = gameObject.AddComponent<AudioSource>();
            a.clip = Resources.Load<AudioClip>("Audio/" + clip);
            a.loop = true;
            a.volume = volume;
            a.Play();
            if (isMusic) Flow.Music(a); else Flow.Sound(a);
        }
        if (!title)
            Loop("BirdLoop", 0.45f, false);
        Loop("WindWeakLoop", 0.25f, false);
        Loop("SummerTension", 0.3f, true);
    }

    /// <summary>Where she came in (where she starts again if she runs out of health).</summary>
    public Vector2 Entrance { get; private set; }

    /// <summary>Where she appears: beside the door she came in by, in a doorway, at the bench, or the start.</summary>
    Vector2 StartFeet()
    {
        int col = Def.start, row = 10;
        if (entry == "left") col = 2;
        else if (entry == "right") col = Def.width - 3;
        else if (entry == "bench" && Def.benches is { Length: > 0 }) col = Def.benches[0];
        else
            foreach (var ex in Def.exits ?? new RoomExit[0])
                if (ex.side == entry)
                {
                    col = ex.col;
                    row = ex.row;
                }
        return new Vector2(col + 0.5f, TopY(row));
    }

    SpriteRenderer Picture(Sprite sprite, Vector2 at, int order, string name)
    {
        var go = new GameObject(name);
        go.transform.SetParent(art, false);
        go.transform.localPosition = at;
        var sr = go.AddComponent<SpriteRenderer>();
        sr.sprite = sprite;
        sr.sortingOrder = order;
        return sr;
    }

    /// <summary>
    /// Ground and floors (one merged collision shape, so she never snags on tile edges), the ladders with a
    /// step at their top, the solid obstacles and the walls at both ends.
    /// </summary>
    void BuildGround()
    {
        var ground = new GameObject("Ground");
        ground.transform.SetParent(transform, false);
        ground.AddComponent<Rigidbody2D>().bodyType = RigidbodyType2D.Static;
        var shape = ground.AddComponent<CompositeCollider2D>();
        shape.geometryType = CompositeCollider2D.GeometryType.Polygons;
        shape.sharedMaterial = new PhysicsMaterial2D("Ground") { friction = 0 };
        void Box(Vector2 center, Vector2 size)
        {
            var b = ground.AddComponent<BoxCollider2D>();
            b.offset = center;
            b.size = size;
            b.compositeOperation = Collider2D.CompositeOperation.Merge;
        }

        int[] floatPieces = { 13, 14, 15 };
        for (int r = 0; r < Rows; r++)
        {
            int run = -1;
            for (int c = 0; c <= Def.width; c++)
            {
                char ch = At(c, r);
                if (c < Def.width && ch == '#' && Village)
                    global::Village.Place(art, global::Village.Ground(GroundPiece(c, r) - 1), new Vector2(c, TopY(r) - 1), 0, "Ground", Vector2.zero);
                else if (c < Def.width && ch == '#')
                    Picture(Art.Picture($"Skins/{Skin}/tile_{GroundPiece(c, r)}", Vector2.zero), new Vector2(c, TopY(r) - 1), 0, "Ground");
                else if (c < Def.width && ch == '=' && Village)
                {
                    bool left = At(c - 1, r) == '=', right = At(c + 1, r) == '=';
                    string piece = right && !left ? "Platform L 01" : left && !right ? "Platform R 01" : "Platform M 01";
                    global::Village.Place(art, global::Village.Prop(piece), new Vector2(c, TopY(r)), 0, "Floor", new Vector2(0, 1));
                }
                else if (c < Def.width && ch == '=')
                {
                    bool left = At(c - 1, r) == '=', right = At(c + 1, r) == '=';
                    int n = right && !left ? floatPieces[0] : left && !right ? floatPieces[2] : floatPieces[1];
                    Picture(Art.Picture($"Skins/{Skin}/tile_{n}", new Vector2(0, 1)), new Vector2(c, TopY(r)), 0, "Floor");
                }
                bool solid = c < Def.width && (ch == '#' || ch == '=');
                if (solid && run < 0)
                    run = c;
                else if (!solid && run >= 0)
                {
                    // (the village's wooden platforms are thinner than a tile)
                    float high = Village && At(run, r) == '=' ? 0.8f : 1f;
                    Box(new Vector2((run + c) / 2f, TopY(r) - high / 2), new Vector2(c - run, high));
                    run = -1;
                }
            }
        }

        // ladders: rungs behind her, and a thin step at the top that fills the gap in the floor above
        var ladderSprite = Art.Picture("Props/ladder", Vector2.zero);
        for (int c = 0; c < Def.width; c++)
        {
            int top = -1, bottom = -1;
            for (int r = 0; r < Rows; r++)
                if (At(c, r) == 'L')
                {
                    if (top < 0) top = r;
                    bottom = r;
                    if (Village)
                        global::Village.Place(art, global::Village.Prop(r == top ? "Ladder 01 T" : At(c, r + 1) == 'L' ? "Ladder 01 M" : "Ladder 01 B"), new Vector2(c, TopY(r) - 1), -5, "Ladder", Vector2.zero);
                    else
                        Picture(ladderSprite, new Vector2(c, TopY(r) - 1), -5, "Ladder");
                }
            if (top < 0)
                continue;
            Ladders.Add(new Ladder { col = c, topY = TopY(top), bottomY = TopY(bottom + 1) });
            Box(new Vector2(c + 0.5f, TopY(top) - 0.075f), new Vector2(1, 0.15f));
        }

        // solid obstacles to hop over
        for (int r = 0; r < Rows; r++)
            for (int c = 0; c < Def.width; c++)
            {
                char ch = At(c, r);
                if ("CRO^".IndexOf(ch) < 0)
                    continue;
                var foot = new Vector2(c + 0.5f, TopY(r) - 1);
                if (Village) // the village's own crate, barrel, stump and spikes, each as solid as it looks
                {
                    string name = ch switch { 'C' => "Crate Small", 'O' => "Barrel", 'R' => "Stump", _ => "Spike Plate" };
                    var pic = global::Village.Stand(art, name, foot, 1, name);
                    var size = pic.sprite.bounds.size;
                    Box(foot + new Vector2(0, size.y / 2), new Vector2(Mathf.Min(1, size.x), size.y));
                    if (ch == '^')
                        Hazard.Create(art, foot + new Vector2(0, 0.35f), new Vector2(0.8f, 0.7f));
                    continue;
                }
                Box(new Vector2(c + 0.5f, TopY(r) - 0.5f), Vector2.one);
                switch (ch)
                {
                    case 'C': Picture(Art.Picture($"Skins/{Skin}/block", new Vector2(0.5f, 0)), foot, 1, "Crate"); break;
                    case 'R': Picture(Art.Picture("Props/boulder", new Vector2(0.5f, 0)), foot, 1, "Boulder"); break;
                    case 'O': Picture(Art.Picture("Props/barrel", new Vector2(0.5f, 0)), foot, 1, "Barrel"); break;
                    case '^':
                        Picture(Art.Picture("Props/tile_spikes", new Vector2(0.5f, 0)), foot, 1, "Spikes");
                        Hazard.Create(art, new Vector2(c + 0.5f, TopY(r) - 0.45f), new Vector2(0.8f, 1.1f));
                        break;
                }
            }

        // the room's two ends are walls for now (doors to the next rooms come next)
        Box(new Vector2(-0.5f, Rows), new Vector2(1, Rows * 3));
        Box(new Vector2(Def.width + 0.5f, Rows), new Vector2(1, Rows * 3));
    }

    /// <summary>Which numbered ground piece a tile needs: grass on top where it's open above (1-3), earth below
    /// (4-6), rounded at a side that's open (the Godot version's _ground_piece).</summary>
    int GroundPiece(int c, int r)
    {
        bool Ground(int cc, int rr) => cc < 0 || cc >= Def.width || (rr >= 0 && rr < Rows && Def.grid[rr][cc] == '#');
        bool openLeft = !Ground(c - 1, r), openRight = !Ground(c + 1, r);
        int side = openLeft == openRight ? 0 : (openLeft ? -1 : 1);
        int middle = Ground(c, r - 1) ? 5 : 2;
        return middle + side;
    }

    /// <summary>Gems to collect. (Animals, crystals and candles come next.)</summary>
    void BuildThings()
    {
        for (int r = 0; r < Rows; r++)
            for (int c = 0; c < Def.width; c++)
                if (At(c, r) == 'o')
                    Gem.Create(art, new Vector2(c + 0.5f, TopY(r) - 0.85f));
                else if (Village)
                    global::Village.Scenery(At(c, r), art, new Vector2(c + 0.5f, TopY(r) - 1), c);
    }

    /// <summary>The area's painted background, in layers that drift slower the further away they are.</summary>
    void BuildBackground()
    {
        if (Village)
        {
            global::Village.Background(transform);
            return;
        }
        for (int i = 0; i < 4; i++)
        {
            if (Resources.Load<Texture2D>($"Art/Skins/{Skin}/bg_{i}") == null)
                break;
            Parallax.Create(transform, Art.Picture($"Skins/{Skin}/bg_{i}", Vector2.zero), 0.1f + i * 0.15f, -100 + i);
        }
    }

    /// <summary>The room's light: one soft light over everything, tinted by the area's mood.</summary>
    void BuildLight()
    {
        var light = new GameObject("Light").AddComponent<Light2D>();
        light.transform.SetParent(transform, false);
        light.lightType = Light2D.LightType.Global;
        light.intensity = Def.mood == "dusk" ? 0.75f : Def.mood == "village" ? 0.8f : 1f; // (the village: evening, so its lamps glow)
        light.color = Def.mood switch
        {
            "day" => new Color(1f, 0.97f, 0.9f),
            "windy" => new Color(0.92f, 0.96f, 1f),
            "golden" => new Color(1f, 0.9f, 0.75f),
            "dusk" => new Color(0.75f, 0.8f, 1f),
            "village" => new Color(1f, 0.88f, 0.74f),
            _ => Color.white,
        };
    }
}

/// <summary>A gem: turns gently, and is collected when she touches it.</summary>
public class Gem : MonoBehaviour
{
    public static void Create(Transform parent, Vector2 at)
    {
        var go = new GameObject("Gem");
        go.transform.SetParent(parent, false);
        go.transform.localPosition = at;
        var look = go.AddComponent<Flipbook>();
        var f = Art.Strip("Props/gem", 3, 32, 42, 16);
        if (f.Length == 3)
            look.Add("turn", new[] { f[0], f[1], f[2], f[1] }, 6, true);
        look.Play("turn");
        look.Renderer.sortingOrder = 2;
        var touch = go.AddComponent<CircleCollider2D>();
        touch.isTrigger = true;
        touch.radius = 0.35f;
        touch.offset = new Vector2(0, 0.33f);
        go.AddComponent<Gem>();
    }

    void OnTriggerEnter2D(Collider2D other)
    {
        var j = other.GetComponentInParent<Janani>();
        if (j == null)
            return;
        j.Gems++;
        Destroy(gameObject);
    }
}

/// <summary>Spikes: touching them hurts.</summary>
public class Hazard : MonoBehaviour
{
    public static void Create(Transform parent, Vector2 center, Vector2 size)
    {
        var go = new GameObject("Hurts");
        go.transform.SetParent(parent, false);
        go.transform.localPosition = center;
        var box = go.AddComponent<BoxCollider2D>();
        box.isTrigger = true;
        box.size = size;
        go.AddComponent<Hazard>();
    }

    void OnTriggerStay2D(Collider2D other)
    {
        var j = other.GetComponentInParent<Janani>();
        if (j != null)
            j.Hurt(transform.position.x);
    }
}
