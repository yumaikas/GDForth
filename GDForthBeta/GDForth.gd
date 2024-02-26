class_name GDForth extends Reference

const StackFrame = preload("./StackFrame.gd")

var MEM = []; 
var RS = [] # Add the bottom frame in _init
var word = ""; var pos = 0; var INPUT = ""; # The current input string
var inbox = []

var trace = 0; var trace_indent
var stack = []; var util_stack = []; var compile_stack = [MEM]
var locals = [];
var constants = {};
var head; var fatal_err;
var mode = "m_interpret"

func sfr(name): return funcref(self, name)
	
var dict = { "&": sfr("mapfn") }; var heads = { "DOCOL": funcref(self, "h_DOCOL") }
var IMMEDIATE = { "];": true, "[": true, "]": true }

func fault(m0, m1="", m2="",m3="", m4="", m5="",m6="",m7="",m8=""):
	var message = str(m0,m1,m2,m3,m4,m5,m6,m7,m8)
	print(message)
	push_error(message)
	mode="stop"
	return message

func hcf(m0, m1="", m2="", m3="", m4="", m5="", m6="", m7="", m8=""):
	fatal_err = fault(m0,m1,m2,m3,m4,m5,m6,m7,m8)

var stdlib = """
'clear-stack '_clearstack & 'stack-size '_stacklen & 
'u> '_u_pop_tos & 'u< '_u_push_tos & 'call-method 'call_method &
'LIT 'LIT & 'EXIT '_exit & '?REDO-BLOCK 'reset_block_if &
'? 'cond_pick & '[ 'begin_block & '] 'end_block & 'exec 'exec &
'def[ 'def & ']; 'exit_def & 'const 'defconst &  
'here '_here & 'assert '_assert &  
'eq? 'op_eq & 'lt? 'op_lt & 'gt? 'op_gt &
'narray '_narray & '+ 'op_add & '- 'op_sub & 
'+trace '_trace_inc & '-trace '_trace_dec &
'pick-del '_pick_del & '_s '_printstack &

'{  def[ stack-size u< ]; '}  def[ stack-size u> - narray ];

'false 0 1 eq? const 'true 1 1 eq? const

'{} { } const '{-1} { -1 } const '{-2} { -2 } const
'{-1,-1} { -1 -1 } const '{-1,-2} { -1 -2 } const
'{spin-pick} { -1 -3 -2 } const '{spin-del} { -1 -1 -1 } const

'[] [ ] const
'if def[ [] ? exec ]; 'if-else def[ ? exec ];

'dup  def[ {-1} {} pick-del ];
'2dup def[ {-1,-2} {} pick-del ];
'drop def[ {} {-1} pick-del ];
'1+ def[ 1 + ];
'spin def[ {spin-pick} {spin-del} pick-del ];
'drop def[ {} {-1} pick-del ];
'nip  def[ {} {-2} pick-del ];
'not def[ false true ? ];
'ucopy def[ u> dup u< ];
'udrop def[ u> drop ];
'while def[ u< [ ucopy exec ?REDO-BLOCK udrop ] exec ];
"""

func _here(): _push(len(MEM))
func _pop(): return stack.pop_back()
func _drop(): _pop()
func _push(val): stack.push_back(val)
func _u_pop(): return util_stack.pop_back()
func _u_push(val): util_stack.push_back(val)
func _u_push_tos(): _u_push(_pop())
func _u_pop_tos(): _push(_u_pop())
func _printstack(): print(stack);
func _stacklen(): _push(len(stack))
func _trace_inc(): trace+=1
func _trace_dec(): trace-=1

func _assert():
	var msg = _pop()
	if not _pop(): 
		mode = "stop"
		hcf("Assertion Failed!: ", msg)
		return

func _pick_del():
	var additions = []
	var to_del = _pop()
	var to_add = _pop()
	for idx in to_add:
		additions.append(stack[idx])
	for idx in to_del:
		stack.pop_at(idx)
	stack.append_array(additions)

func _narray(): 
	var n = _pop()
	if n == 0:
		_push([])
		return
	var arr = stack.slice(-n, -1)
	stack.resize(len(stack)-n)
	stack.append(arr)

func _print_mem():
	var addr = 0
	for m in MEM:
		print(addr,": ", m)
		addr+=1

func _is_block_RS(maybeBlock):
	return maybeBlock.MEM != MEM

func _is_block(maybeBlock):
	return (typeof(maybeBlock) == TYPE_ARRAY 
		and maybeBlock.front() == "DOCOL" 
		and maybeBlock.back() == "EXIT")

func exec():
	var maybeBlock = stack.back()
	if _is_block(maybeBlock):
		IP_push(mode)
		IP_push(0, _pop())
		mode = "m_head"
	else:
		fault("Cannot execute: ", maybeBlock)

func reset_block_if():
	if RS.back().MEM != MEM:
		if _pop():
			RS.back().IP = 1
	else:
		hcf("Tried to reset the base block!")
	pass

func cond_pick():
	var f_val = _pop()
	var t_val = _pop()
	var cond_val = _pop()
	if cond_val: _push(t_val)
	else: _push(f_val)


func begin_block():
	# print("BEGIN: ", mode)
	# print(INPUT)
	IP_push(mode)
	mode = "m_compile"
	compile_stack.push_back(["DOCOL"])


func end_block():
	compile("EXIT")
	var block = compile_stack.pop_back()
	mode = IP(); IP_pop()
	# print("END: ", mode)
	if trace > 0:
		print("end_block", mode)
	if _eq(mode, "m_compile"):
		compile_many(["LIT", block])
	elif _eq(mode, "m_interpret"):
		_push(block)
	elif _eq(mode, MEM):
		hcf("unmatched ']' !")
	else:
		print(INPUT)
		hcf("Should not encounter block in mode: ", mode)
		return

func op_eq(): _push(_eq(_pop(), _pop()))
func op_gt(): _push(_pop() < _pop())
func op_lt(): _push(_pop() > _pop())
func op_add():
	var b = _pop(); var a = _pop(); _push(a + b)
func op_sub():
	var b = _pop(); var a = _pop(); _push(a - b)
func _eq(a, b): 
	return typeof(a) == typeof(b) and a == b

func _clearstack(): stack.clear()

func _init():
	IP_push(StackFrame.new(0,MEM))
	interpret(stdlib)

func IP_inc(): RS.back().inc()
func IP_dec(): RS.back().dec()
func IP(): return RS.back().IP
func IP_push(val, mem=MEM): RS.push_back(StackFrame.new(mem, val))
func IP_pop(): return RS.pop_back()
func instr(): return RS.back().instr()
func EOI(): return pos >= len(INPUT)
func EOM(): return IP() >= len(MEM)

func _exit():
	IP_pop()
	if typeof(IP()) == TYPE_STRING: 
		mode = IP()
		IP_pop()

func LIT(): 
	stack.append(instr()); IP_inc()

func compile(val): compile_stack.back().append(val)
func compile_many(vals): compile_stack.back().append_array(vals)

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

var done = true
func safe_call(method):
	done = false
	call(method)
	done = true
	
func run(): 
	while mode != "stop" and not fatal_err: 
		var oldmode = mode
		var inst
		if mode == "m_forth":
			inst = instr()
		safe_call(mode)
		if done == false:
			hcf(mode, " failed!")
		if oldmode != "m_forth":
			inst = word
		if trace > 0:
			prints("mode:", oldmode, " inst:", inst, " Stack: ",  stack, " RS:", RS, "US:", util_stack, "pos:", pos)

func interpret(input: String):
	INPUT = input; pos = 0
	mode = "m_interpret"
	# if input != stdlib:
	# 	print(input)
	run()

func h_DOCOL(): 
	mode = "m_forth"
	# IP_inc()

func m_head():
	done = false
	head = instr()
	IP_inc()
	heads[head].call_func()
	done = true

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
	hcf("Can't run GDForth instruction: ", instr)
	return
	
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
		hcf("Can't interpret: '", word, "' at: ", pos)
		
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
	if constants.has(word):
		_push(constants[word])
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
		hcf("Cannot compile: ", word)

func compile_immediate_word():
	if word and dict.has(word) and IMMEDIATE.has(word):
		if dict[word] is FuncRef:
			dict[word].call_func()
		else:
			IP_push(mode)
			IP_push(dict[word])
			mode = "m_head"
		return true
	if word and constants.has(word):
		compile_many(["LIT", constants[word]])
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

func mapfn():
	var _val = _pop()
	var _key = _pop()

	dict[_key] = sfr(_val)

func defconst():
	var _val = _pop()
	var _key = _pop()
	constants[_key] = _val

func def():
	if mode == "m_compile":
		hcf("Cannot nest word defs!")
		return

	var name = _pop()
	dict[name] = len(MEM)
	compile("DOCOL") #compile(["NAME:", name])
	mode = "m_compile"

func exit_def():
	compile("EXIT")
	mode = "m_interpret"

func call_method(push_nulls=false):
	var on = _pop(); var name = _pop(); var margs = _pop().duplicate()
	print(on, name, margs, push_nulls)
	_dispatch(on, name, margs, push_nulls)

const argNames = ["a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7", "a8", "a9"]

func _dispatch(on, name, margs, push_nulls = false):
	if typeof(on) == TYPE_OBJECT:
		var fn = funcref(on, name)
		var ret = fn.call_funcv(margs)
		on.callv(name, margs)
		if ret != null or push_nulls:
			_push(ret)
	else:
		var expr = Expression.new()
		var anames = argNames.slice(0, len(margs))
		anames.append("m")
		var toParse = str("m.", name,"(", ", ".join(anames), ")")
		if expr.parse(toParse, anames) != OK:
			hcf("Unable to parse: ", toParse, anames, " as an expression")
			return

		margs.append(on)
		if trace > 0:
			print(toParse, anames, margs)
		var ret = expr.execute(margs)

		if ret != null or push_nulls:
			_push(ret)
