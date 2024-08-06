# GDForth

A Forth-alike for better async GDScript

## Requirements

Because of GDForth being built to make signals code in Godot 3 less of a pain (an issue that Godot 4 seems to have largely addressed), it requires Godot 3. I've tested in Godot 3.5, though I've not knowingly used things that lower versions of Godot 3 don't have.

## Getting started

You'll want to copy this folder `addons/GDForth` into your Godot project. That'll give you access to the GDForth class, which you can use like so:


```gdscript

# game.gd

var forth

func _ready():
	forth = GDForth.new(self)
	forth.eval("load: game.fth")

```

```forth
( game.fth )

"This is from a GDForth Script!" print(*)

```

## Usage from GDScript

Generally speaking, if you want to call from GDScript into GDForth, you'll be using either `eval`, which sends a string at the GDForth VM, or `do()`, which allows you to call an already-defined word with a number of arguments. Going from GDForth into GDScript is covered in the GDForth language guide.


#### Example of `do()`

```gdscript

# game.gd

var forth

func _ready():
	forth = GDForth.new(self)
	forth.eval("load: game.fth")

func _on_click(evt):
	forth.do("announce", "<Your Name Here>")

```

```forth
( game.fth )

: announce ( name -- ) "Hi, " swap "! How are you?" print(***) ;


For more details, check out GUIDE.md. UI.gd and CLI.gd have example code.
```

## Langauge Guide

For more details asbout GDForth itself, check out [the guide](addons/GDForth/GUIDE.md)
