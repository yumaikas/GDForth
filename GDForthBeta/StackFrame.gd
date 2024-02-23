class_name StackFrame extends Reference

var MEM
var IP = 0

func _init(mem, ip = 0):
	MEM = mem
	IP = ip

func inc(): IP += 1
func instr(): return MEM[IP]
func compile(val): MEM.append(val)
func compile_many(vals): MEM.append_array(vals)