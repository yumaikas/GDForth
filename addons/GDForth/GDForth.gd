class_name GDForth extends Reference

const GDForthVM = preload("./VM.gd")
const CodeEnv = preload("./CodeEnv.gd")

var stack setget _set_stack, _get_stack
var VM
var code
func _init(instance):
	code = CodeEnv.new()
    VM = GDForthVM.new(code)
    VM.bind_instance(instance)

func do(word, a0=null, a1=null, a2=null, a3=null, a4=null, a5=null, a6=null, a7=null, a8=null, a9=null):
    VM.do(word, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9)

func eval(script):
    code.compile
    VM.eval(script)

var _loaded = []
func load_lib(lib):
    var toLoad = lib.new()
    _loaded.append(toLoad)
    toLoad.load_lib(VM)

func _get_stack():
    return VM.stack
func _set_stack(val):
    VM.stack = val

func do_print(toPrint):
    do_printraw(toPrint)
    do_printraw("\n")

func do_push_error(err):
    push_error(err)
    emit_signal("do_error", err)
