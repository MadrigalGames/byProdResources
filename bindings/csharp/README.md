# byProd C# bindings

`ByProd.cs` is the API. `ByProd.Native.cs` has the C declarations.

Copy the two files into a project, or compile them in from here the way
the sample does. They need C# 9 and .NET Standard 2.1, which covers .NET 8
and Unity 2021.2 or newer.

The native library, `byProd.dll` or `libbyProd.so` from the SDK's `bin`
folder, goes beside the executable, or under `Assets/Plugins` in Unity.

`samples/play_event_csharp` shows the whole flow.
