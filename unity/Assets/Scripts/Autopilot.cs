using System;
using System.Linq;
using UnityEngine;

/// <summary>
/// For test runs and pictures, from the command line (it does nothing otherwise):
///   -autorun          she runs right, hopping over whatever is ahead
///   -shot file.png    takes a screenshot after -shotAt seconds (default 4), then quits
///   -at 60            starts her at that column        -pause   opens the pause menu after 2 seconds
/// </summary>
public class Autopilot : MonoBehaviour
{
    bool run, pause, placed;
    int at = -1;
    string shot;
    float shotAt = 4, age;
    bool shotTaken;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot()
    {
        var args = Environment.GetCommandLineArgs();
        if (!args.Contains("-autorun") && !args.Contains("-shot"))
            return;
        Application.runInBackground = true;
        var pilot = new GameObject("Autopilot").AddComponent<Autopilot>();
        pilot.run = args.Contains("-autorun");
        pilot.pause = args.Contains("-pause");
        int a = Array.IndexOf(args, "-at");
        if (a >= 0 && a + 1 < args.Length) int.TryParse(args[a + 1], out pilot.at);
        int i = Array.IndexOf(args, "-shot");
        if (i >= 0 && i + 1 < args.Length) pilot.shot = args[i + 1];
        i = Array.IndexOf(args, "-shotAt");
        if (i >= 0 && i + 1 < args.Length) float.TryParse(args[i + 1], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out pilot.shotAt);
    }

    void Update()
    {
        age += Time.unscaledDeltaTime; // (keeps counting while the game is paused)
        var room = FindAnyObjectByType<Room>();
        var j = room != null ? room.Player : null;
        if (j != null && at >= 0 && !placed)
        {
            placed = true;
            j.Teleport(new Vector2(at + 0.5f, 2));
        }
        if (pause && age > 2 && MenuUI.Instance != null)
        {
            pause = false;
            MenuUI.Instance.Pause();
        }
        if (j != null && run)
        {
            GameInput.Simulate.Add(Act.Right);
            // hop when there's an obstacle or a gap just ahead
            int c = Mathf.FloorToInt(j.Feet.x + 0.95f), floor = Mathf.RoundToInt(Room.Rows - j.Feet.y);
            bool ahead = "CRO^".IndexOf(room.At(c, floor - 1)) >= 0 || room.At(c, floor) == ' ';
            if (ahead && j.Grounded) GameInput.Simulate.Add(Act.Jump);
            else if (j.Grounded) GameInput.Simulate.Remove(Act.Jump);
        }
        if (shot != null && !shotTaken && age >= shotAt)
        {
            shotTaken = true;
            ScreenCapture.CaptureScreenshot(shot);
            Invoke(nameof(Quit), 0.6f);
        }
    }

    void Quit() => Application.Quit();
}
