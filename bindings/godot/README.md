# byProd Godot bindings

A GDExtension binding for Godot 4, kept in its own repository because it
ships a build rather than a file to copy:

https://github.com/Manshooo/godot-byprod

It reaches GDScript as five classes: the sound manager, event descriptions and
instances, group buses, and an optional node that routes a host-mixed manager
through Godot's own audio buses. Sound banks are served through Godot's
`FileAccess`, so they still resolve from inside an exported `.pck`, where the
runtime's own file I/O could not reach them.

The binding resolves the runtime's symbols at load time instead of linking
against the import library, so it builds without the SDK present. The native
library, `byProd.dll` or `libbyProd.so` from the SDK's `bin` folder, goes into
`addons/byprod/bin/` beside the extension.

Built and verified against 0.5.2 on Windows and Linux, on Godot 4.5 and later.
