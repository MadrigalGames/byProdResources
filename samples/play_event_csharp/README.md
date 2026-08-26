# play_event_csharp

The play_event sample in C#, against the bindings in `bindings\csharp`.
Needs the .NET 8 SDK and an unpacked byProd SDK. From this folder:

    dotnet run -p:ByProdSdk=C:\path\to\byprod-sdk -- ..\assets

`ByProdSdk` is the SDK folder holding `bin` and `lib`, so the build can
copy `byProd.dll` or `libbyProd.so` beside the executable. The argument
after `--` is the folder holding `sample_project.byprod` and `main.bybank`.
