using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;

public enum Act { Left, Right, Up, Down, Jump, Shoot }

/// <summary>
/// Every control in one place: the keyboard, the phone's touch buttons (TouchPad fills Touch) and the tests
/// (Simulate) press the same actions. Held() can be read any time; TakePress() hands out each new press once
/// (the physics step takes it, so a quick tap between two physics steps isn't lost).
/// Keys: arrows / WASD to move, Up / W / Space to jump (Up also climbs), X / J magic.
/// </summary>
[DefaultExecutionOrder(-100)]
public class GameInput : MonoBehaviour
{
    public static readonly HashSet<Act> Simulate = new(); // (tests and the autopilot)
    public static readonly HashSet<Act> Touch = new();    // (the phone's buttons)
    const int Count = 6;
    static readonly bool[] held = new bool[Count];
    static readonly bool[] latched = new bool[Count];

    public static bool Held(Act a) => held[(int)a];
    public static float Axis => (Held(Act.Right) ? 1f : 0f) - (Held(Act.Left) ? 1f : 0f);

    /// <summary>True once for each new press of the action.</summary>
    public static bool TakePress(Act a)
    {
        bool pressed = latched[(int)a];
        latched[(int)a] = false;
        return pressed;
    }

    /// <summary>Let go of everything (a new room, the tests).</summary>
    public static void Clear()
    {
        Simulate.Clear();
        Touch.Clear();
        for (int i = 0; i < Count; i++)
            held[i] = latched[i] = false;
    }

    void Update() => Poll();
    void FixedUpdate() => Poll();

    static void Poll()
    {
        var k = Keyboard.current;
        for (int i = 0; i < Count; i++)
        {
            var a = (Act)i;
            bool on = Simulate.Contains(a) || Touch.Contains(a) || (k != null && OnKeyboard(k, a));
            if (on && !held[i])
                latched[i] = true;
            held[i] = on;
        }
    }

    static bool OnKeyboard(Keyboard k, Act a) => a switch
    {
        Act.Left => k.leftArrowKey.isPressed || k.aKey.isPressed,
        Act.Right => k.rightArrowKey.isPressed || k.dKey.isPressed,
        Act.Up => k.upArrowKey.isPressed || k.wKey.isPressed,
        Act.Down => k.downArrowKey.isPressed || k.sKey.isPressed,
        Act.Jump => k.spaceKey.isPressed || k.upArrowKey.isPressed || k.wKey.isPressed,
        Act.Shoot => k.xKey.isPressed || k.jKey.isPressed,
        _ => false,
    };
}
