using System;
using System.Linq;
using UnityEngine;

/// <summary>
/// For test runs and pictures, from the command line (it does nothing otherwise):
///   -autorun          she runs right, hopping over whatever is ahead
///   -shot file.png    takes a screenshot after -shotAt seconds (default 4), then quits
/// </summary>
public class Autopilot : MonoBehaviour
{
    bool run;
    string shot;
    float shotAt = 4, age;
    bool shotTaken;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot()
    {
        var args = Environment.GetCommandLineArgs();
        if (!args.Contains("-autorun") && !args.Contains("-shot"))
            return;
        var pilot = new GameObject("Autopilot").AddComponent<Autopilot>();
        pilot.run = args.Contains("-autorun");
        int i = Array.IndexOf(args, "-shot");
        if (i >= 0 && i + 1 < args.Length) pilot.shot = args[i + 1];
        i = Array.IndexOf(args, "-shotAt");
        if (i >= 0 && i + 1 < args.Length) float.TryParse(args[i + 1], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out pilot.shotAt);
    }

    void Update()
    {
        age += Time.deltaTime;
        var room = FindAnyObjectByType<Room>();
        var j = room != null ? room.Player : null;
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
