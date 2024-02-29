class_name GDForthAlpha extends Reference

signal script_end()

var m
var IP = -1
var trace = 0; var trace_indent = false
var stack = []; var utilStack = []; var returnStack = []
var dict = {}; var locals = {}
var evts = {};
var stop = false; var is_error = false
var CODE 
var errSymb = {}; var lblSymb = {}; var iterSymb = {}; var prevSymb = {}
var in_evt = false
var instance

var _stdlib = """
:stop [ suspend ] def

:box [ 1 narray ] def :{empty} [ 0 narray ] def
:u< :U-PUSH box def :u> :U-POP box def
:{ [ stack-size u< ] def :} [ stack-size u> - narray ] def
:true { :LIT 1 1 eq? } def :false { :LIT 0 1 eq? } def
:swap { :PICK-DEL -2 box -2 box } def
:2dup { :PICK-DEL { -1 -2 } {empty} } def
:drop { :PICK-DEL {empty} -1 box } def :nip { :PICK-DEL {empty} -2 box } def 
:2drop { :PICK-DEL {empty} { -1 -2 } } def
:) [ stack-size u> - narray u> u> call-method ] def
:)? [ stack-size u> - narray u> u> call-method-null ] def
:if [ [ ] if-else ] def
:2max [ 2dup lt? [ drop ] [ nip ] if-else ] def
:pos? [ 0 gt? ] def  :neg? [ 0 lt? ] def  :zero? [ 0 eq? ] def
:inc [ 1 + ] def  :dec [ 1 - ] def
:nom [ u> dec u< ] def -( :eat: parameters into a method call )-
:not [ [ false ] [ true ] if-else ] def
:do-with-scope [ get-scope u< set-scope do-block u> set-scope ] def
:vmget [ VM &get( nom ) ] def  :vmset [ swap VM &set( nom nom ) ] def
:+trace [ :trace vmget inc :trace vmset ] def
:-trace [ :trace vmget dec 0 2max :trace vmset ] def
:trace [ +trace do-block -trace ] def

:while [ get-scope +scope =old-scope =block 
	%LOOP block old-scope do-with-scope LOOP goto-if-true
	-scope ] def

:each [ get-scope +scope 
	=outer =block =arr 0 =idx
	arr len pos? [
		%LOOP 
			arr idx nth block outer do-with-scope 
			idx inc =idx
		arr len idx gt? LOOP goto-if-true
	] if
	-scope
] def
"""

func _init(script=null,bind_to=null):

	if script:
		load_script(script)
	if bind_to:
		bind_instance(bind_to)

func halt_fail():
	stop = true
	is_error = true

func load_script(script):
	CODE = []
	stack = []
	locals = {}
	
	var inputs = str(_stdlib, script)
	var drop = false
	inputs = inputs.replace("\n", " ").replace("\r", " ").replace("\t", " ")
	var toks = inputs.split(" ", false)

	for tok in toks:
		if tok == "": continue
		if tok == "-(": drop = true
		elif tok == ")-":
			drop = false
			continue
		if not drop: CODE.append(tok)
	IP = 0
	stop = false
	is_error = false
	resume()

func immediate_script(script): 
	load_script(script)
	resume()

func bind_instance(to): instance = to
func __pop(stack, errMsg):
	if len(stack) == 0:
		halt_fail(); return {errSymb: errMsg}
	return stack.pop_back()
func _u_push(e): utilStack.append(e)
func _u_pop(): return __pop(utilStack, "UTILITY STACK UNDERFLOW")
func _r_push(e): returnStack.append(e)
func _r_pop(): return __pop(returnStack, "RETURN STACK UNDERFLOW")
func _push(e): stack.append(e)
func _pop(): return __pop(stack, "DATA UNDERFLOW")
func _is_special(item, symb): return typeof(item) == TYPE_DICTIONARY and item.has(symb)

func _pop_special(symb):
	if symb in stack.back():
		return stack.pop_back()
	else:
		halt_fail()
		return {errSymb: "SPECIAL POP MISMATCH"}

func _has_prefix(word, pre):
	return typeof(word) == TYPE_STRING and word.begins_with(pre)

const math_ops = ["+", "-", "*", "div", "gt?", "lt?", "ge?", "le?", "eq?"]
func math(inst):
	var b = _pop(); var a = _pop()
	match inst:
		"+": _push(a + b); "-": _push(a - b)
		"*": _push(a * b); "div": _push(a / b)
		"gt?": _push(a > b); "lt?": _push(a < b)
		"ge?": _push(a >= b); "le?": _push(a <= b)
		"eq?": _push(a == b)

func sig_resume(a0=null,a1=null,a2=null,a3=null,a4=null,a5=null,a6=null,a7=null,a8=null,a9=null):
	if trace > 0: print("resumed from signal!")
	resume(a0,a1,a2,a3,a4,a5,a6,a7,a8,a9)

var dispatch_count

func evt_call(def, a0=null,a1=null,a2=null,a3=null,a4=null,a5=null,a6=null,a7=null,a8=null,a9=null):
	in_evt = true
	if not evts.has(def):
		push_error("Tried to fire non-existant event!")
		return

	var args =[a0,a1,a2,a3,a4,a5,a6,a7,a8,a9]
	for a in args:
		if a == null:
			break
		_push(a)
	
	returnStack.append(IP)
	returnStack.append(dict["stop"][lblSymb])
	IP = evts[def][lblSymb]
	resume()
	in_evt = false



# The parameters are an attempt to make this a -very- widely connectable signal handler
func resume(a0=null,a1=null,a2=null,a3=null,a4=null,a5=null,a6=null,a7=null,a8=null,a9=null):
	dispatch_count = 0
	var args =[a0,a1,a2,a3,a4,a5,a6,a7,a8,a9]
	if is_error:
		push_error("Attempted to resume failed GDForth script")
		return
	stop = false
	while IP < len(CODE) and not stop:
		var inst = CODE[IP]
		dispatch_count +=1
		if trace > 0:
			print("  ".repeat(trace - 1), 
				"TRACE: ", IP, ", ", inst, " DATA:", stack, " RETURN:", returnStack)
		if typeof(inst) == TYPE_ARRAY:
			if inst[0] == "LIT": _push(inst[1])
			elif inst[0] == "GETVAR": _push(locals[inst[1]])
			elif inst[0] == "CALL":
				if trace_indent: trace+=1
				_r_push(IP+1)
				IP = inst[1]
				continue
			elif inst[0] == "U-PUSH": _u_push(_pop())
			elif inst[0] == "U-POP": _push(_u_pop())
			elif inst[0] == "WAIT":
				if in_evt:
					print("ERROR: suspended in evt_call!")
					halt_fail()
					return
				var obj = _pop()
				if not obj.is_connected(inst[1], self, "sig_resume"):
					if trace > 0: print("connecting")
					obj.connect(inst[1], self, "sig_resume", [], CONNECT_ONESHOT | CONNECT_DEFERRED)
				else:
					print(str("Already connected to ", obj))
				stop = true
				IP += 1
				continue
			elif inst[0] == "PICK-DEL":
				var to_add = []
				for idx in inst[1]:
					to_add.append(stack[idx])
				for idx in inst[2]:
					stack.pop_at(idx)
				stack.append_array(to_add)

			elif inst[0] == "BLOCK-LIT":
				IP = inst[1]; _push(inst[2])
			elif inst[0] == "GET-MEMBER": _push(instance.get(inst[1]))

			else:
				stop = true
				print(str("Unable to execute inst ", CODE[IP], " at ", IP))
				push_error(str("Unable to execute inst ", CODE[IP], " at ", IP))
				_push(inst)
				#
				break
		elif typeof(inst) == TYPE_STRING:
			if inst.begins_with("."): 
				# _push(instance.get(inst.substr(1)))
				CODE[IP] = ["GET-MEMBER", inst.substr(1)]
				continue
			elif inst.begins_with(">"):
				var val = _pop()
				if trace > 0: print("SETTING", instance, inst.substr(1))
				instance.set(inst.substr(1), val)
			elif inst.begins_with(":@"):
				if inst.ends_with("("):
					_u_push(instance)
					_u_push(inst.substr(2,len(inst)-3))
					_u_push(len(stack))
				elif inst.ends_with("()"):
					var fn = funcref(instance, inst.substr(2,len(inst)-4))
					var ret = fn.call_func()
					if ret != null:
						_push(ret)
				else:
					is_error = true
					stop = true
					push_error(str("invalid call ", inst))
			elif inst.begins_with("&"):
				# ( obj name stack-len )
				if inst.ends_with("("):
					_u_push(_pop())
					_u_push(inst.substr(1,len(inst)-2))
					_u_push(len(stack))
				elif inst.ends_with("()"):
					_dispatch(_pop(), inst.substr(1, len(inst)-3), [], false)
				else:
					halt_fail()
					push_error(str("invalid call ", inst))
			elif inst == "call-method" or inst == "call-method-null":
				call_method(inst == "call-method-null")
			elif inst.begins_with("%"):
				locals[inst.substr(1)] = {lblSymb: IP}
			elif inst.begins_with("$"):
				if inst.substr(1) in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]:
					_push(args[int(inst.substr(1))])
				else:
					stop = true; is_error = true
			elif inst.begins_with(":"):
				CODE[IP] = ["LIT", inst.substr(1)]
				continue
			elif inst.begins_with("~"):
				CODE[IP] = ["WAIT", inst.substr(1)]
				continue
			elif inst == "narray":
				var n = _pop(); var top = []
				for i in n: top.append(_pop())
				top.invert(); _push(top)
			elif inst == "print": print(_pop())
			elif inst == "suspend": 
				stop = true
				break
			elif inst == "self": _push(instance)
			elif inst == "VM": _push(self)
			elif inst == "len": _push(len(_pop()))
			elif inst == "range": _push(range(_pop()))
			elif inst == "_s": print(stack)
			elif inst in math_ops: math(inst)
			elif inst.begins_with("="):
				locals[inst.substr(1)] = _pop()
			elif inst == "nth":
				var at = _pop(); var arr = _pop()
				_push(arr[at])
			elif inst == "get":
				var k = _pop()
				var dict = _pop()
				_push(dict[k])
			elif inst == "def":
				var block = _pop()
				var name = _pop()
				#print("DEF", dict, name, block)
				dict[name] = block
			elif inst == "if-else":
				var false_lbl = _pop_special(lblSymb)
				var true_lbl = _pop_special(lblSymb)
				var cond = _pop()
				# Push the IP -after- the if-else onto the return stack
				# so that when we hit the end
				# we return to that instruction
				if cond:
					if trace_indent: trace+=1
					_r_push(IP+1); IP = true_lbl[lblSymb]
					continue
				else:
					if trace_indent: trace+=1
					_r_push(IP+1); IP = false_lbl[lblSymb]
					continue
			elif inst == "dup": stack.push_back(stack.back())
			elif inst == "drop": stack.pop_back()
			elif inst == "+scope":
				var old_locals = locals
				locals = { prevSymb: old_locals }
			elif inst == "-scope":
				var old_locals = locals[prevSymb]
				locals = old_locals
			elif inst == "get-scope": _push(locals)
			elif inst == "set-scope": locals = _pop()
			elif inst == "goto-if-true":
				var JUMP = _pop_special(lblSymb)[lblSymb]
				if _pop(): IP = JUMP
				# Let the IP += 1 happen, so we skip the lable
			elif inst == "stack-size":
				_push(len(stack))
			elif inst == "def-evt":
				var block = _pop()
				var name = _pop()
				#print("DEF", dict, name, block)
				evts[name] = block
				dict[name] = block

			elif inst == "[":
				var SEEK = IP+1
				var DEPTH = 1
				while DEPTH > 0:
					if CODE[SEEK] == "[": DEPTH += 1
					elif CODE[SEEK] == "]": DEPTH -= 1
					if SEEK > len(CODE):
						stop = true
						is_error = true
						push_error("Unmatched [")
						break
					SEEK += 1
				SEEK -= 1
				CODE[IP] = ["BLOCK-LIT", SEEK, {lblSymb: IP+1}]
				IP -= 1
			elif inst == "]":
				if trace_indent: trace -= 1
				IP = _r_pop(); continue
			elif inst == "exec":
				_r_push(IP+1)
				var word_name = _pop()
				if dict.has(word_name):
					IP = dict[word_name][lblSymb]
				else:
					halt_fail()
					push_error("Tried to exec word that doesn't exist!")
				continue
			elif inst == "do-block":
				_r_push(IP+1)
				if trace_indent: trace += 1
				var lbl = _pop_special(lblSymb)
				IP = lbl[lblSymb]
				continue
			elif inst.is_valid_integer():
				CODE[IP] = ["LIT", int(inst)]
				continue
			elif inst.is_valid_float():
				CODE[IP] = ["LIT", float(inst)]
				continue
			elif inst in dict:
				if _is_special(dict[inst], lblSymb):
					CODE[IP] = ["CALL", dict[inst][lblSymb], inst]
				elif typeof(dict[inst]) == TYPE_ARRAY:
					CODE[IP] = dict[inst].duplicate()
				continue
			elif inst in locals:
				CODE[IP] = ["GETVAR", inst]
				continue
			else:
				halt_fail()
				print("ERROR: unresolved word: ", inst, "at ", IP)
				#print(dict)
		IP += 1
	if not stop: emit_signal("script_end")

func call_method(push_nulls=false):
	var on = _pop(); var name = _pop(); var margs = _pop().duplicate()
	#print(on, name, margs, push_nulls)
	_dispatch(on, name, margs, push_nulls)

const argNames = ["a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7", "a8", "a9"]

# TODO: Event select via bound params used for "select context"
# TODO: Blog about teh return to GDForth Alpha

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
			stop = true
			is_error = true

		margs.append(on)
		if trace > 0:
			pass
			#print(toParse, anames, margs)
		var ret = expr.execute(margs)

		if ret != null or push_nulls:
			_push(ret)
