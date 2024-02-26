class_name StackFrame extends Reference

var MEM
var IP = 0

func _to_string():
	var ipstr
	if typeof(IP) == TYPE_ARRAY:
		ipstr = str("[B/",len(IP),"]")
	else:
		ipstr = IP

	return str("SF(", ipstr, ", ", _len(MEM),")")

func _init(mem, ip = 0):
	MEM = mem
	IP = ip

func inc(): IP += 1
func dec(): IP -=1
func instr(): return MEM[IP]
func compile(val): MEM.append(val)
func compile_many(vals): MEM.append_array(vals)

func _len(val):
	if typeof(val) == TYPE_ARRAY:
		return len(val)
	return 0