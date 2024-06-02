class_name GDForth extends Reference

const GDForthVM = preload("./VM.gd")

var stack setget _set_stack, _get_stack
var VM
func _init(instance):
	VM = GDForthVM.new()
	VM.bind_instance(instance)
	VM.connect("do_print", self, "__print")

func do(word, a0=null, a1=null, a2=null, a3=null, a4=null, a5=null, a6=null, a7=null, a8=null, a9=null):
	VM.do(word, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9)

func eval(script):
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

func __print(val):
	print(val)
