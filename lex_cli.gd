
class_name GDForthCLI extends SceneTree

const LEX = preload("lex.gd")

func load_file(path):
    var f = File.new()
    if f.open(path, File.READ):
        return ""
    else:
        return f.get_as_text()

func _init():

    var os_args = OS.get_cmdline_args()
    for i in len(os_args):
        var a = os_args[i]
        if a == "--gdf-script":
            var l = LEX.new()
            var text = load_file(os_args[i+1])
            var j = 0
            for t in l.tokenize(text):
                print(j,"[",t,"]")
                j += 1
    quit()
                


