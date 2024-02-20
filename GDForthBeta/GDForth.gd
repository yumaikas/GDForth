class_name GDForth extends Reference

var MEM = []; var RS = [ 0 ]
var word = ""; var pos = 0; var INPUT = ""; # This is a queue of input strings
var inbox = []

var trace = 0; var trace_indent
var stack = []; var util_stack = []; var check_stack = []
var locals = [];
var head; 
func sfr(name): return funcref(self, name)
	
var dict = {
	"clear-stack": sfr("_clearstack"),
	"stack-size": sfr("_stacklen"),
	"_s": sfr("_printstack"), "+": sfr("op_add"), "-": sfr("op_sub"),
	"def[": sfr("def"), "];": sfr("exit_def"),
	"]": sfr("end_block"),
	"LIT": sfr("LIT"), "EXIT": sfr("_exit"),
	"narray": sfr("_narray"),
	"n-popmem": sfr("_n_mem"),
	"u>": sfr("_u_pop_tos"), "u<": sfr("_u_push_tos"),
	"c>": sfr("_c_pop_tos"), "c<": sfr("_c_push_tos"),
	"assert": sfr("_assert"),
	"here": sfr("_here"),
	"pick-del": sfr("_pick_del"),
	"eq?": sfr("op_eq"), "lt?": sfr("op_lt"), "gt?": sfr("op_gt"),
	"+trace": sfr("_trace_inc"), "-trace": sfr("_trace_dec"),
}; 
var heads = {
	"DOCOL": funcref(self, "h_DOCOL")
}

var IMMEDIATE = { "];": true, "]": true, "][": true, "if[": true }

var stdlib=  """
'{  def[ stack-size u< ]; 
'}  def[ stack-size u> - narray ];
'{} def[ 0 narray ];
'dup  def[ { -1 } {} pick-del ];
'2dup def[ { -1 -2 } {} pick-del ];
'drop def[ {} { -1 } pick-del ];
'nip  def[ {} { -2 } pick-del ];

'c-drop def[ c> drop ];
'c-assert def[ c> dup eq? [[COMPILE-MODE-ASSERT FAILED]] assert ];
'if[ def[ { 'IF 'IF-ELSE } u< here u< ];
'][ def[ here u< ];
"""

var qqq = """
cond if[ ]
while[ do various things cond ]
iterable each[ ]
"""

func _here(): _push(len(MEM))
func _pop(): return stack.pop_back()
func _drop(): _pop()
func _push(val): stack.push_back(val)
func _u_pop(): return util_stack.pop_back()
func _u_push(val): util_stack.push_back(val)
func _c_pop(): return check_stack.pop_back()
func _c_push(val): check_stack.push_back(val)
func _u_push_tos(): _u_push(_pop())
func _u_pop_tos(): _push(_u_pop())
func _c_push_tos(): _c_push(_pop())
func _c_pop_tos(): _push(_c_pop())
func _printstack(): print(stack)
func _stacklen(): _push(len(stack))
func _trace_inc(): trace+=1
func _trace_dec(): trace-=1

func _assert():
	var msg = _pop()
	if not _pop(): 
		mode = "stop"
		print("Assertion Failed!: ", msg)
		push_error(msg)
		return

func _pick_del():
	var additions = []
	var to_del = _pop()
	var to_add = _pop()
	for idx in to_add:
		to_add.append(stack[idx])
	for idx in to_del:
		stack.pop_at(idx)
	stack.append_array(additions)



func _narray(): 
	var n = _pop()
	var arr = stack.slice(-n, -1)
	stack.resize(len(stack)-n)
	stack.append(arr)

func _n_mem():
	var n = _pop()
	stack.append_array(MEM.slice(len(MEM)-n))
	MEM.resize(len(MEM)-n)

func _print_mem():
	var addr = 0
	for m in MEM:
		print(addr,": ", m)
		addr+=1


func end_block():
	# TOS should be a MEM address
	var from = _u_pop()
	if mode == "m_compile":

		var to_compile = [from]
		var u = _u_pop()
		while typeof(u) != TYPE_ARRAY:
			to_compile.append(u)
			u = _u_pop()

		if len(to_compile) <= len(u):
			compile(u[len(to_compile)-1])
		else:
			mode = "stop"
			print("Unable to compile: ", to_compile, u)
			return
		compile_many(to_compile)

	elif mode == "m_interpret":
		print("ERROR", "unble to interpert blocks yet")
		mode = "stop"
		return
		# TOS 
		pass
	else:
		mode = "stop"
		return

func op_eq(): _push(_pop() == _pop())
func op_gt(): _push(_pop() < _pop())
func op_lt(): _push(_pop() > _pop())
func op_add():
	var b = _pop(); var a = _pop(); _push(a + b)
func op_sub():
	var b = _pop(); var a = _pop(); _push(a - b)

func _clearstack(): stack.clear()


var mode = "m_interpret"
# Modes: m_interpret, m_compile, m_head, m_forth, m_eval stop


# Ways to handle blocks/quotes
# if end
# while end
# each end


func _init():
	interpret(stdlib)

func IP_inc(): RS[len(RS)-1] += 1
func RS_under(): return RS[len(RS)-2] # Plan to use this for anon-code
func IP(): return RS.back()
func IP_push(val): RS.push_back(val)
func IP_pop(): return RS.pop_back()
func instr(): return MEM[IP()]
func EOI(): return pos >= len(INPUT)
func EOM(): return IP() >= len(MEM)

func _exit():
	IP_pop()
	if typeof(IP()) == TYPE_STRING: mode = IP_pop()

func LIT(): 
	stack.append(instr()); IP_inc()

func p_dup():
	var tos = stack.pop_back(); stack.push_back(tos); stack.push_back(tos)

func compile(val): MEM.append(val)
func compile_many(vals): MEM.append_array(vals)

func scan_until(charset: String, contains=true):
	var newPos = pos
	var subj = INPUT
	while newPos < len(subj) and contains != (subj[newPos] in charset):
		newPos += 1
	if newPos >= len(subj):
		var ret = INPUT.substr(pos)
		pos = newPos
		return ret
	else:
		var ret = INPUT.substr(pos, newPos - pos)
		pos = newPos
		return ret

func scan_for_seq(seq: String):
	var newPos = pos
	var subj = INPUT
	newPos = subj.find(seq)
	if newPos != -1:
		var ret = subj.substr(pos, newPos - pos)
		pos = newPos + len(seq)
		return ret
	return null

func eat_space(): scan_until(" \t\r\n", false)

func run(): 
	while mode != "stop": 
		var oldmode = mode
		var inst
		if mode == "m_forth":
			inst = instr()
		call(mode)
		if oldmode != "m_forth":
			inst = word
		if trace > 0:
			prints("mode:", oldmode, " inst:", inst, " Stack: ",  stack, " RS:", RS, "US:", util_stack, "pos:", pos)

func interpret(input: String):
	INPUT = input; pos = 0
	mode = "m_interpret"
	run()

func h_DOCOL(): mode = "m_forth"

func m_head():
	head = instr()
	IP_inc()
	heads[head].call_func()

func m_forth():
	if EOM():
		mode = "stop"
		return
	var instr = instr()
	IP_inc()
	if typeof(instr) == TYPE_INT: 
		IP_push(instr); mode = "m_head"; return
	if typeof(instr) == TYPE_STRING:
		dict[instr].call_func(); return
	push_error(str("Can't run GDForth instruction: ", instr))
	mode = "stop"
	
func m_interpret():
	if EOI():
		mode = "stop"
		return
	eat_space(); word = scan_until(" \t\r\n")
	if word == '': pass
	elif interpret_primitive(): pass
	elif interpret_nonprimitive(): pass
	elif interpret_literal(): pass
	else:
		push_error(str("Can't interpret: '", word, "' at: ", pos))
		mode = "stop"
		
func interpret_primitive(): 
	if dict.has(word) and dict[word] is FuncRef:
		dict[word].call_func()
		return true
	return false

func interpret_nonprimitive():
	# print("inonprim")
	if dict.has(word) and typeof(dict[word]) == TYPE_INT:
		IP_push("m_interpret")
		IP_push(dict[word])
		mode = "m_head"
		return true
	return false

func interpret_literal():
	#print("ilit")
	if word.is_valid_integer():
		stack.append(int(word)); return true
	elif word.is_valid_float():
		stack.append(float(word)); return true
	elif word.begins_with("'"):
		stack.append(word.substr(1)); return true
	elif word.begins_with("[["):
		pos = pos - len(word) + 2
		var maybeStr = scan_for_seq("]]")
		if maybeStr != null:
			stack.append(maybeStr); return true
		return false
	else:
		return false

func m_compile():
	if EOI():
		mode = "stop"
		return
	eat_space(); word = scan_until(" \t\r\n")
	if compile_immediate_word(): pass
	elif compile_nonimmediate_word(): pass
	elif compile_literal(): pass
	else:
		push_error(str("Cannot compile: ", word))
		mode = "stop"

func compile_immediate_word():
	if word and dict.has(word) and IMMEDIATE.has(word):
		if dict[word] is FuncRef:
			dict[word].call_func()
		else:
			IP_push(mode)
			IP_push(dict[word])
			mode = "m_head"
		return true

func compile_nonimmediate_word(): 
	if word and dict.has(word) and not IMMEDIATE.has(word):
		if dict[word] is FuncRef:
			compile(word)
		else:
			compile(dict[word])
		return true
	
func compile_literal():
	if word.is_valid_float():
		compile_many(["LIT", float(word)]); return true
	elif word.is_valid_integer():
		compile_many(["LIT", int(word)]); return true
	elif word.begins_with("'"):
		compile_many(["LIT", word.substr(1)]); return true
	elif word.begins_with("[["):
		var maybeStr = scan_for_seq("]]")
		if maybeStr != null:
			compile_many(["LIT", maybeStr]); return true
		return false

	return false

func def():
	dict[_pop()] = len(MEM)
	compile("DOCOL")
	mode = "m_compile"

func exit_def():
	compile("EXIT")
	mode = "m_interpret"


