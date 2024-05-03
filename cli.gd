class_name GDForthCLI extends SceneTree

const VM = preload("GDForth.gd")
const LibOutput = preload("liboutput.gd")

var forth

func _init():
    forth = VM.new(self, true)
        
    forth.load_lib(LibOutput)

    var os_args = OS.get_cmdline_args()
    for i in len(os_args):
        var a = os_args[i]
        if a == "--gdf-script":
            forth.do("load", os_args[i+1])


