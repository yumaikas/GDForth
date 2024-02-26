class_name GDForth extends Reference

const StackFrame = preload("./StackFrame.gd")

var MEM = []; var RS = [] # Add the bottom frame in _init
var word = ""; var pos = 0; var INPUT = ""; # The current input string
var inbox = []

var trace = 0;  var trace_modes = ["mode", "instr", "stacklen", "pos"]; var trace_indent; var trace_stack = []
var stack = []; var compile_stack = [MEM]
var locals = []; var constants = {};
var head; var fatal_err;
var mode = "m_interpret"

func sfr(name): return funcref(self, name)
	
var dict = { "&": sfr("mapfn") }; var heads = { "DOCOL": funcref(self, "h_DOCOL") }
var name_dict = {}
var IMMEDIATE = { "];": true, "[": true, "]": true }

func fault(m0, m1="", m2="",m3="", m4="", m5="",m6="",m7="",m8=""):
	var message = str(m0,m1,m2,m3,m4,m5,m6,m7,m8)
	print(message)
	push_error(message)
	mode="stop"
	return message

func vm(): _push(self)
func hcf(m0, m1="", m2="", m3="", m4="", m5="", m6="", m7="", m8=""):
	fatal_err = fault(m0,m1,m2,m3,m4,m5,m6,m7,m8)

# :const :defconst &  
var stdlib = """
:VM :vm & :get :dget & :put :dput & :<dict> :newdict &
:clear-stack :_clearstack & :stack-size :_stacklen & 
:call-method :call_method & :LIT :LIT & :EXIT :_exit & :?REDO-BLOCK :reset_block_if &
:? :cond_pick & :[ :begin_block & :] :end_block & :exec :exec &
:def[ :def & :]; :exit_def & 
:here :_here & :assert :_assert &  
:eq? :op_eq & :lt? :op_lt & :gt? :op_gt &
:narray :_narray & :+ :op_add & :- :op_sub & 
:pick-del :_pick_del & :_s :_printstack &
:+trace  :_trace_inc & :-trace :_trace_dec & :untrace :_untrace & :retrace :_retrace &

:<arr> def[ 0 narray ]; :box def[ 1 narray ]; :pair def[ 2 narray ]; :triple def[ 3 narray ];
:spin def[ untrace -1 -3 -2 triple -1 -1 -1 triple pick-del retrace ];
:vmget def[ box VM :get call-method ]; :vmset def[ pair VM :set call-method ];
:const def[ untrace :constants vmget spin put retrace ];

:util-stack <arr> const
:u< def[ untrace 1 narray util-stack :append call-method retrace ]; 
:u> def[ untrace 0 narray util-stack :pop_back call-method retrace ];

:{  def[ stack-size u< ]; :}  def[ stack-size u> - narray ];
:{} <arr> const :{-1} -1 box const :{-2} -2 box const

:1+ def[ 1 + ]; :1- def[ 1 - ]; :nom def[ u> 1- u< ];
:( def[ u< u< { ]; :) def[ } u> u> call-method ];
:() def[ u< u< {} u> u> call-method ];
:false 0 1 eq? const :true 1 1 eq? const

:[] [ ] const
:if def[ [] ? exec ]; :if-else def[ ? exec ];

:dup def[ {-1} {} pick-del ];
:{-1,-2} -1 -2 pair const
:2dup def[ {-1,-2} {} pick-del ];
:drop def[ {} {-1} pick-del ];

:{spin-pick} { -1 -3 -2 } const :{spin-del} { -1 -1 -1 } const
:spin def[ untrace {spin-pick} {spin-del} pick-del retrace ];
:drop def[ {} {-1} pick-del ]; :nip def[ {} {-2} pick-del ];
:not def[ false true ? ];
:ucopy def[ u> dup u< ]; :udrop def[ u> drop ];

:while def[ u< [ ucopy exec ?REDO-BLOCK udrop ] exec ];
:swap def[ untrace {-2} {-2} pick-del retrace ];
:bind def[ :self swap const ];
"""

func _here(): _push(len(MEM))
func _pop(): 
	if not stack.empty():
		return stack.pop_back()
	hcf("data underflow")
	return null

func _drop(): _pop()
func _push(val): stack.push_back(val)
func _printstack(): print(stack);
func _stacklen(): _push(len(stack))
func _trace_inc(): trace+=1
func _trace_dec(): trace-=1
func _untrace():
	trace_stack.push_back(trace); trace=0
func _retrace(): trace = trace_stack.pop_back()

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

var lastlit
func LIT(): 
	lastlit = instr()
	stack.append(lastlit); IP_inc()

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
			for t in trace_modes:
				if _eq(t, "mode"):
					printraw(" mode: ", oldmode)
				elif _eq(t, "instr"):
					printraw(" inst: ", inst)
					if _eq(inst, "LIT"):
						printraw(" <<", lastlit, ">> ")
					elif typeof(inst) == TYPE_INT:
						printraw(" [", name_dict[inst], "]")

				elif _eq(t, "stack"):
					printraw(" stack: ", stack)
				elif _eq(t, "stacklen"):
					printraw(" len(stack): ", len(stack))
				elif _eq(t, "RS"):
					printraw(" RS ", RS)
				elif typeof(t) == TYPE_ARRAY and t[0] == "consts":
					for c in t.slice(1, -1):
						printraw(" ", c, ": ", constants[c])
			print()

func interpret(input: String, s0=null, s1=null, s2=null, s3=null, s4=null, s5=null, s6=null, s7=null, s8=null, s9=null):
	var args = [s0,s1,s2,s3,s4,s5,s6,s7,s8,s9]
	for a in args: 
		if not _eq(a, null):
			_push(a)

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
	elif word.begins_with(":"):
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
	elif word.begins_with(":"):
		compile_many(["LIT", word.substr(1)]); return true
	elif word.begins_with("[["):
		var maybeStr = scan_for_seq("]]")
		if maybeStr != null:
			compile_many(["LIT", maybeStr]); return true
		return false

	return false

func mapfn():
	var _val = _pop(); var _key = _pop()
	dict[_key] = sfr(_val)

func newdict(): _push({})
func dget():
	var _key = _pop()
	var _dict = _pop()
	if _dict.has(_key):
		_push(_dict)
	else:
		_push(null)

func dput():
	var _val = _pop()
	var _key = _pop()
	var _dict = _pop() #print(_dict, _key, _val)
	_dict[_key] = _val

func def():
	if mode == "m_compile":
		hcf("Cannot nest word defs!"); return

	var name = _pop()
	dict[name] = len(MEM); name_dict[len(MEM)] = name
	compile("DOCOL") #compile(["NAME:", name])
	mode = "m_compile"

func exit_def():
	compile("EXIT"); mode = "m_interpret"

func call_method(push_nulls=false):
	# margs on name
	var name = _pop(); var on = _pop(); var margs = _pop().duplicate()
	# print(on, name, margs, push_nulls)
	_dispatch(on, name, margs, push_nulls)

const argNames = ["a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7", "a8", "a9"]
func _dispatch(on, name, margs, push_nulls = false):
	if typeof(on) == TYPE_OBJECT:
		var ret = on.callv(name, margs)
		if ret != null or push_nulls:
			_push(ret)
	else:
		var expr = Expression.new()
		var anames = argNames.slice(0, len(margs)-1)
		if len(margs) == 0:
			anames = []
		var toParse = str("m.", name,"(", ", ".join(anames), ")")
		anames.append("m")
		if expr.parse(toParse, anames) != OK:
			hcf("Unable to parse: ", toParse, anames, " as an expression")
			return

		margs.append(on)
		if trace > 0: 
			print(toParse, anames, margs)
		var ret = expr.execute(margs)

		if ret != null or push_nulls:
			_push(ret)
