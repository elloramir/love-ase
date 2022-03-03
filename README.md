# Lua asprite loader
It helps you to read ASE files without parsing them into a json or something. So helpful for development,
but I recommend not using it in production (without an [atlas builder](https://github.com/elloramir/packer)), loading files this way is
slower than just passing src data.

### Example:
You will find an example in [main.lua](main.lua) of how to make a simple sprite object with

Note: this loader is not an animation framework, it provides a way to load files from aseprite. Implement
your own sprite system based on the example

**player.ase (demo file) available tags, have fun :smile:**

![tags](https://i.imgur.com/ndEVaeU.png)

### Loader output:
The output is the same from [ase file specs docs](https://github.com/aseprite/aseprite/blob/master/docs/ase-file-specs.md) with
few changes. You can easily find it at [ase-loader.lua](ase-loader.lua)
