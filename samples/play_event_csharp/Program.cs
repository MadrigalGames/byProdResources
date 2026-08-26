// play_event_csharp - A minimal sample showing how to initialize the runtime,
// load a project, play an event and adjust its playback speed using a float
// parameter. The byProd bindings come from bindings\csharp in this repository.

using ByProd;

// The path to the main runtime project file. You can find a copy in this
// repository's samples\assets folder along with the sound bank file(s)
// (.bybank). You, as the programmer, load the .byprod file. The
// runtime decides when to load the .bybank file(s) using the sound
// bank loader (see below). The folder holding them is the first argument.
const string ProjectFile = "sample_project.byprod";

// The path to the event we want to play, inside the project.
const string EventPath = "event:/Drums";

// The name of the float parameter we use to adjust the playback speed of the drum loop.
const string ParamName = "Speed";

// We adjust the the playback speed using a sine wave.
const float ParamMin = 0.8f;
const float ParamMax = 1.2f;
const double SweepPeriodSeconds = 4.0;

// How much to sleep between sample program updates.
const int StepMilliseconds = 10;

string assetsFolder = args.Length > 0 ? args[0] : ".";

// You should always check the byProd version reported by the dynamic library
// and make sure it matches the version your app was built against.
if (Runtime.LibraryVersion != Runtime.Version)
{
    Console.Error.WriteLine(
        $"Library version 0x{Runtime.LibraryVersion:x8} does not match binding version 0x{Runtime.Version:x8}.");
    return 1;
}

// Install the print hook. Whenever the byProd runtime prints something, it
// uses this function to do it.
Runtime.PrintHandler = (type, message) =>
{
    string prefix = type switch
    {
        PrintType.Warning => "warning",
        PrintType.Error => "error",
        _ => "info",
    };

    Console.WriteLine($"[byProd {prefix}] {message}");
};

// Create the byProd sound manager. This is the main "object" of the byProd
// runtime in a game, and needs to outlive any other resources created/loaded
// by the runtime. Create() uses byProd's defaults. Start from
// SoundManagerSettings.Default and pass the result to Create() when the
// defaults are not what you want.
SoundManager? soundManager = SoundManager.Create();

if (soundManager == null)
{
    Console.Error.WriteLine("SoundManager.Create failed.");
    return 1;
}

// Install the sound bank loader, so byProd knows what to call when it wants
// to load a sound bank. We read the whole file into memory and return it.
// The bindings keep it pinned for as long as byProd needs it, no copy is made.
soundManager.SoundBankLoader = name =>
{
    string path = Path.Combine(assetsFolder, name + ".bybank");

    return File.Exists(path) ? File.ReadAllBytes(path) : null;
};

string projectPath = Path.Combine(assetsFolder, ProjectFile);

if (!File.Exists(projectPath))
{
    Console.Error.WriteLine($"Could not read \"{projectPath}\".");
    return 1;
}

// Load the project into memory. The bytes are always copied during load, so
// we don't need to hold onto the bytes.
if (!soundManager.LoadProject(File.ReadAllBytes(projectPath)))
{
    Console.Error.WriteLine($"Loading \"{projectPath}\" failed.");
    return 1;
}

// Get the event description for our sample event, found at EventPath.
// Event descriptions are created when the project loads and they stay alive until
// the project is unloaded.
EventDescription? foundDescription = soundManager.GetEventDescription(EventPath);

if (foundDescription == null)
{
    Console.Error.WriteLine($"The project has no event \"{EventPath}\".");
    return 1;
}

EventDescription description = foundDescription.Value;

// An event can have multiple parameters that can be set from the game code at runtime.
// Parameter indices can be queried up-front, using the parameter name. This way
// we can use the parameter index to actually set the parameter later, which is faster
// than setting it by name.
uint paramIndex = description.GetParameterIndex(ParamName);

if (paramIndex == EventDescription.InvalidParameterIndex)
{
    Console.Error.WriteLine($"The event has no parameter \"{ParamName}\".");
    return 1;
}

// You can create any number of instances of an event. For this you need the event
// description. Event instances need to be manually released later, but you
// can ask the runtime to automatically release an event after it has finished, after
// a fade-out etc.
EventInstance? createdInstance = description.CreateInstance();

if (createdInstance == null)
{
    Console.Error.WriteLine($"Creating an instance of \"{EventPath}\" failed.");
    return 1;
}

EventInstance instance = createdInstance.Value;

Console.WriteLine($"Playing \"{EventPath}\", sweeping \"{ParamName}\" between {ParamMin} and {ParamMax}.");

// Instances start in the stopped-state, so let's start it!
instance.Start();

double elapsedSeconds = 0.0;
int step = 0;

// This loop runs while the instance is playing.
while (instance.State == EventInstanceState.Playing)
{
    // Update the sound manager. You'll want to do this once per game update / frame.
    // The sound manager tracks time internally, so you don't need to pass delta time here.
    soundManager.Update();

    // Modulate the playback speed over time using a sine wave. Print out the value every 20th step.
    double phase = elapsedSeconds * (2.0 * Math.PI / SweepPeriodSeconds);
    float normalized = 0.5f + 0.5f * (float)Math.Sin(phase);
    float value = ParamMin + (ParamMax - ParamMin) * normalized;
    if (step % 20 == 0) Console.Error.WriteLine($"Speed: {value:F2}");

    // Update the parameter value for the playing instance.
    instance.SetParameter(paramIndex, value);

    Thread.Sleep(StepMilliseconds);
    elapsedSeconds += StepMilliseconds / 1000.0;
    ++step;
}

Console.WriteLine("Done.");

// Release the instance.
instance.Release();

// Shut down the sound manager.
soundManager.Dispose();

// Easy, right? Check out ByProd.cs for the full API.

return 0;
