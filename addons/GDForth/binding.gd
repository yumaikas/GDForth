class_name VmCallBinding extends Reference

var _vm
var _word
func _init(vm, word):
	_vm = vm
	_word = word

func trigger(a0=null, a1=null, a2=null, a3=null, a4=null, a5=null, a6=null, a7=null, a8=null, a9=null):
	_vm.do(_word, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9)
