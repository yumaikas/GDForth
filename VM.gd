class_name GDForthVM extends Reference

signal script_end

var m
var IP = -1
var trace = 0; var trace_indent = false
var stack = []; var utilStack = []; var returnStack = []; var locals = {}
var dict = {}; 
var constant_pool = []
var evts = {};
var stop = true; var is_error = false
var in_exec = false
var CODE = PoolIntArray()
var errSymb = {}; var lblSymb = {}; var iterSymb = {}; var prevSymb = {}
var in_evt = false
var instance

static func make():
    var vm = .new()
    vm.prep()

func halt_fail():
    stop = true
    is_error = true

func bind_instance(to): instance = to
func __pop(stack, errMsg):
    if len(stack) == 0:
        halt_fail(); 
        return {errSymb: errMsg}
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

func call_method(push_nulls=false):
    var on = _pop(); var name = _pop(); var margs = _pop().duplicate()
    #print(on, name, margs, push_nulls)
    _dispatch(on, name, margs, push_nulls)

const argNames = ["a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7", "a8", "a9"]

# TODO: Event select via bound params used for "select context"
# TODO: Blog about the return to GDForth Alpha

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


func comp(script):
    var toks = tokenize(script)
    compile(toks)

func do(word, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9):
    if not(word in dict):
        push_error("Tried to do nonexistent word: ")
        return
    var args = [a0, a1, a2, a3, a4, a5, a6, a7, a8, a9]
    for a in args:
        _push(a)
    _r_push(IP) 
    _r_push(0)
    IP = dict[word]
    exec()

func eval(script):
    _r_push(IP)
    IP = len(CODE)
    comp(script)
    CODE.append(OP_END_EVAL)
    exec()


func tokenize(script):
    var drop = false
    var inputs = script.replace("\n", " ").replace("\r", " ").replace("\t", " ")
    var toks = inputs.split(" ", false)

    var ret_toks = []

    for tok in toks:
        if tok == "": continue
        if tok == "-(": drop = true
        elif tok == ")-": 
            drop = false
            continue
        if not drop: ret_toks.append(tok)

    return ret_toks
    

var lit_counts = {}
var _iota = 0
func iota(lit_count=0):
    _iota += 1

    if lit_count != 0:
        lit_counts[_iota] = lit_count

    return _iota

func lit_count(n):
    lit_counts[_iota] = n

var OP_ADD = iota()
var OP_SUB = iota()
var OP_MUL = iota()
var OP_DIV = iota()

var OP_GT = iota()
var OP_GE = iota()
var OP_LT = iota()
var OP_LE = iota()
var OP_EQ = iota()

var OP_LIT = iota(1)
var OP_BLOCK_LIT = iota(2)
var OP_GOTO = iota(1)

var OP_GET_MEMBER = iota(1)
var OP_SET_MEMBER = iota(1)

var OP_DEF = iota()

var OP_U_PUSH = iota() 
var OP_U_POP = iota()

var OP_STACK_CLEAR = iota()
var OP_CALL_METHOD = iota()
var OP_CALL_METHOD_NULL = iota()
var OP_CALL_METHOD_LIT = iota(1)

var OP_NARRAY = iota()

var OP_NTH = iota()
var OP_LEN = iota()

var OP_SETLOCAL = iota(1)
var OP_GETLOCAL = iota(1)

var OP_PRINT = iota()
var OP_PRINT_STACK = iota()

var OP_IF_ELSE = iota()
var OP_GOTO_WHEN_TRUE = iota()

var OP_DUP = iota()
var OP_DROP = iota()
var OP_SWAP = iota()

var OP_PUSH_SCOPE = iota()
var OP_DROP_SCOPE = iota()

var OP_SUSPEND = iota()
var OP_END_EVAL = iota()
var OP_WAIT = iota(1)

var OP_STACK_SIZE = iota()
var OP_VM = iota()
var OP_SELF = iota()

var OP_RETURN = iota()
var OP_DO_BLOCK = iota()
var OP_CALL = iota(1)
# var OP_GETARG = iota()
var OP_SHUFFLE = iota(2)
var OP_SET_SCOPE = iota()
var OP_GET_SCOPE = iota()

var OP_RANGE = iota()


var decode_table = {}

func print_code():
    var num_lits = 0
    print("[")
    for o in CODE:
        if num_lits > 0:
            print("\t", constant_pool[o])
            num_lits -= 1
        else:
            print(decode_table[o])
            if o in lit_counts:
                num_lits += lit_counts[o]
    print("]")
        
        
func prep():
    for p in get_property_list():
        if p.name.begins_with("OP_"):
            decode_table[get(p.name)] = p.name
    CODE.append(OP_END_EVAL)
            

func assoc_constant(value):
    var idx = constant_pool.find(value)
    if idx == -1:
        constant_pool.append(value)
        return len(constant_pool) - 1
    return idx

func _comp_method_setup(to):
    CODE.append_array([
            OP_SELF, OP_U_PUSH,
            OP_LIT, assoc_constant(to), OP_U_PUSH,
            OP_STACK_SIZE, OP_U_PUSH
    ])

var _comp_map = {
    "+": OP_ADD, "-": OP_SUB, "*": OP_MUL, "div": OP_DIV,
    "lt?": OP_LT, "le?": OP_LE, "gt?": OP_GT, "ge?": OP_GE,
    "eq?": OP_EQ,
    "if-else": OP_IF_ELSE,
    "_s": OP_PRINT_STACK,
    "call-method": OP_CALL_METHOD,
    "call-method-null": OP_CALL_METHOD_NULL,
    "clear-stack": OP_STACK_CLEAR,
    "def": OP_DEF,
    "get": OP_NTH,
    "narray": OP_NARRAY,
    "nth": OP_NTH,
    "print": OP_PRINT,
    "range": OP_RANGE,
    "VM": OP_VM,
    "swap": OP_SWAP,
    "drop": OP_DROP,
    "dup": OP_DUP,
    "len": OP_LEN,
    "self": OP_SELF,
    "stack-size": OP_STACK_SIZE,
    "suspend": OP_SUSPEND,
}

func compile(tokens):
    var t_idx = 0
    while t_idx < len(tokens):
        var tok = tokens[t_idx]
        if tok.begins_with("."):
            CODE.append(OP_GET_MEMBER)
            CODE.append(assoc_constant(tok.substr(1)))
            t_idx+=1
        elif tok.begins_with(":@"):
            if tok.ends_with("("):
                _comp_method_setup( tok.substr(2, len(tok)-3))
            elif tok.ends_with("()"):
                CODE.append_array([
                    OP_CALL_METHOD_LIT, assoc_constant(tok.substr(2, len(tok)-4))
                ])
            else:
                var err = str("Could not compile ", tok, " as a call")
                push_error(err)
                return { "err": err }
            t_idx+=1
        elif tok.begins_with("&"):
            if tok.ends_with("("):
                _comp_method_setup(tok.substr(1, len(tok)-2))
                t_idx+=1
            elif tok.ends_wth("()"):
                CODE.append_array([
                    OP_CALL_METHOD_LIT, assoc_constant(tok.substr(1, len(tok)-3))
                ])
                t_idx+=1
            else:
                var err = str("Could not compile ", tok, " as a call")
                push_error(err)
                return { "err": err }
        elif tok.begins_with("%"):
            CODE.append_array([
                OP_LIT,
                0, # Replaced below
                OP_SETLOCAL,
                assoc_constant(tok.substr(1))
            ])
            CODE[len(CODE)-3] = assoc_constant({ lblSymb: len(CODE) })
            t_idx+=1
#        elif tok.begins_with("$"):
#            if tok.substr(1) in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]:
#                CODE.append_array([ OP_GETARG, int(tok.substr(1)) ])
#                t_idx+=1
#            else:
#                var err = str("Could not compile ", tok, " as a valid argument get")
#                push_error(err)
#                return { "err": err }
        elif tok.begins_with(":"):
            CODE.append_array([OP_LIT, assoc_constant(tok.substr(1))])
            t_idx+=1
        elif tok.begins_with("~"):
            CODE.append_array([OP_WAIT, assoc_constant(tok.substr(1))])
            t_idx+=1
        elif tok.begins_with("*") and tok != '*':
            CODE.append_array([OP_GETLOCAL, assoc_constant(tok.substr(1))])
            t_idx += 1
        elif tok.begins_with("="):
            CODE.append_array([OP_SETLOCAL, assoc_constant(tok.substr(1))])
            t_idx += 1
        elif tok in ["def:", "defl:", "evt:", "evtl:"]:
            var name = tokens[t_idx + 1];
            var SEEK = t_idx + 2;

            while tokens[SEEK] != ";":
                if tokens[SEEK] in ["def:", "defl:", "evt:", "evtl:"]:
                    var err = str("Cannot nest `", tok, "`, while defining '", name, "'")
                    push_error(err)
                    return { "err": err }
                SEEK += 1
            # Create a 
            CODE.append_array([OP_GOTO, 0])
            dict[name] = len(CODE)
            if tok in ["evt:", "evtl:"]:
                evts[name] = len(CODE)

            if tok in ["defl:", "evtl:"]:
                CODE.append(OP_PUSH_SCOPE)

            var to_comp = tokens.slice(t_idx + 2, SEEK - 1)

            var status = compile(to_comp)
            if "err" in status:
                return status

            if tok in ["defl:", "evtl:"]:
                CODE.append(OP_DROP_SCOPE)
            CODE.append(OP_RETURN)
            # 
            CODE[dict[name]-1] = assoc_constant(len(CODE))

            t_idx = SEEK + 1

            
        elif tok == "[":
            var SEEK = t_idx + 1
            var DEPTH = 1
            while DEPTH > 0:
                if tokens[SEEK] == "[": DEPTH += 1
                elif tokens[SEEK] == "]": DEPTH -= 1
                if SEEK > len(tokens):
                    var err = str("Unmatched [")
                    push_error(err)
                    return {"err": err}
                SEEK += 1

            CODE.append_array([OP_BLOCK_LIT, 0, 0])
            var slot_1 = len(CODE) - 2
            var slot_2 = len(CODE) - 1
            compile(tokens.slice(t_idx + 1, SEEK - 2))
            CODE[slot_2] = assoc_constant(slot_2 + 1)
            CODE.append(OP_RETURN)
            CODE[slot_1] = assoc_constant(len(CODE))
            t_idx = SEEK 

        elif tok.is_valid_integer():
            CODE.append_array([OP_LIT, assoc_constant(int(tok))])
            t_idx += 1
        elif tok.is_valid_float():
            CODE.append_array([OP_LIT, assoc_constant(float(tok))])
            t_idx += 1
        elif tok in _comp_map:
            CODE.append(_comp_map[tok])
            t_idx += 1
        elif tok in dict:
            if typeof(dict[tok]) == TYPE_ARRAY: 
                CODE.append_array(dict[tok])
            else:
                CODE.append_array([OP_CALL, dict[tok]])
            t_idx += 1
        elif tok in _comp_map:
            CODE.append(_comp_map[tok])
            t_idx += 1
        else:
            var err = str("Unrecognized command: ", tok)
            push_error(err)
            return {"err": err}
    return {}

func exec():
    if stop == false:
        push_error("Re-entered exec without halting properly!")
        return
    stop = false
    var oldip = IP
    while IP < len(CODE) and not stop:
#        printraw(decode_table[CODE[IP]])
#        if CODE[IP] in lit_counts:
#            printraw(": ")
#            for i in lit_counts[CODE[IP]]:
#                printraw(constant_pool[CODE[IP+i+1]])
#                if i+1 < lit_counts[CODE[IP]]:
#                    printraw(", ")
#        print()

                
        var inst = CODE[IP]
        if inst == OP_LIT:
            _push(constant_pool[CODE[IP+1]]); IP += 2
        elif inst == OP_CALL:
            _r_push(IP+2)
            IP = CODE[IP+1]
        elif inst == OP_U_PUSH:
            _u_push(_pop())
            IP += 1
        elif inst == OP_U_POP:
            _push(_u_pop())
            IP += 1
        elif inst == OP_WAIT:
            if in_evt:
                print("ERROR: suspended in evt_call!")
                halt_fail()
                return
            var obj = _pop()
            var sig = constant_pool[CODE[IP+1]]
            if not obj.is_connected(sig, self, "sig_resume"):
                if trace > 0: print("connecting")
                obj.connect(sig, self, "sig_resume", [], CONNECT_ONESHOT | CONNECT_DEFERRED)
            else:
                print(str("Already connected to ", obj))
            stop = true
            IP += 2
        elif inst == OP_SHUFFLE:
            var shuf_locals = {}
            var input = constant_pool[CODE[IP+1]]
            var output = constant_pool[CODE[IP+2]]

            for i in len(input):
                var idx = len(input) - i
                var c = input[idx]
                shuf_locals[c] = _pop()
            for c in output:
                 _push(shuf_locals[c])
            IP += 3
        elif inst == OP_BLOCK_LIT:
            _push(constant_pool[CODE[IP+2]])
            IP = constant_pool[CODE[IP+1]]
        elif inst == OP_RETURN:
            IP = _r_pop()
        elif inst == OP_DO_BLOCK:
            _r_push(IP+1)
            var lbl = _pop_special(lblSymb)
            IP = lbl[lblSymb]
        elif inst == OP_GET_MEMBER:
            _push(instance.get(constant_pool[CODE[IP+1]]))
            IP += 2
        elif inst == OP_DEF:
            var block = _pop()
            var name = _pop()
            dict[name] = block
        elif inst == OP_SET_MEMBER:
            instance.set(constant_pool[CODE[IP+1]], _pop())
            IP += 2
        elif inst == OP_SELF:
            _push(instance)
        elif inst == OP_VM:
            _push(self)
        elif inst == OP_CALL_METHOD_LIT:
            var mname = constant_pool[CODE[IP+1]]
            _dispatch(instance, mname, [], false)
            IP += 2
        elif inst == OP_CALL_METHOD:
            call_method(false)
            IP += 1
        elif inst == OP_CALL_METHOD_NULL:
            call_method(true)
            IP += 1
        elif inst == OP_STACK_CLEAR:
            stack.clear()
            IP += 1
        elif inst == OP_STACK_SIZE:
            _push(len(stack))
            IP += 1
        elif inst == OP_NARRAY:
            var n = _pop(); 
            if n == 0:
                _push([])
            else:
                var top = []
                for i in n: top.append(_pop())
                top.invert(); _push(top)
            IP += 1
        elif inst == OP_PRINT:
            print(_pop())
            IP += 1
        elif inst == OP_SUSPEND:
            stop = true
            IP += 1
            break
        elif inst == OP_END_EVAL:
            stop = true
            IP = _r_pop()
            break
        elif inst == OP_NTH:
            var at = _pop(); var arr = _pop();
            _push(arr[at])
            IP += 1
        elif inst == OP_IF_ELSE:
            var false_lbl = _pop() 
            var true_lbl = _pop()
            var cond = _pop()
            if cond:
                _r_push(IP+1); IP = true_lbl
            else:
                _r_push(IP+1); IP = false_lbl
        elif inst == OP_GOTO:
            IP = constant_pool[CODE[IP+1]]
        elif inst == OP_GOTO_WHEN_TRUE:
            var JUMP = _pop_special(lblSymb)[lblSymb]
            if _pop(): IP = JUMP
        elif inst == OP_DUP:
            stack.push_back(stack.back())
            IP += 1
        elif inst == OP_DROP:
            stack.pop_back()
            IP += 1
        elif inst == OP_SWAP:
            var a = stack[len(stack)-1]
            stack[len(stack)-1] = stack[len(stack)-2]
            stack[len(stack)-2] = a
            IP += 1
        elif inst == OP_PUSH_SCOPE:
            var old_locals = locals
            locals = { prevSymb: old_locals }
            IP += 1
        elif inst == OP_DROP_SCOPE:
            var old_locals = locals[prevSymb]
            locals = old_locals
            IP += 1
        elif inst == OP_GET_SCOPE:
            _push(locals)
            IP += 1
        elif inst == OP_SET_SCOPE:
            locals = _pop()
            IP += 1
        elif inst == OP_SETLOCAL:
            var local_key = constant_pool[CODE[IP+1]]
            locals[local_key] = _pop()
            IP += 2
        elif inst == OP_GETLOCAL:
            var local_key = constant_pool[CODE[IP+1]]
            _push(locals[local_key])
            IP += 2
        elif inst == OP_ADD:
            var b = _pop(); var a = _pop();
            _push(a + b)
            IP += 1
        elif inst == OP_SUB:
            var b = _pop(); var a = _pop();
            _push(a - b)
            IP += 1
        elif inst == OP_MUL:
            var b = _pop(); var a = _pop();
            _push(a * b)
            IP += 1
        elif inst == OP_DIV:
            var b = _pop(); var a = _pop();
            _push(a / b)
            IP += 1
        elif inst == OP_GT:
            var b = _pop(); var a = _pop();
            _push(a > b)
            IP += 1
        elif inst == OP_LT:
            var b = _pop(); var a = _pop();
            _push(a < b)
            IP += 1
        elif inst == OP_GE:
            var b = _pop(); var a = _pop();
            _push(a >= b)
            IP += 1
        elif inst == OP_LE:
            var b = _pop(); var a = _pop();
            _push(a <= b)
            IP += 1
        elif inst == OP_EQ:
            var b = _pop(); var a = _pop();
            _push(a == b)
            IP += 1
        elif inst == OP_PRINT:
            print(_pop())
            IP += 1
        elif inst == OP_LEN:
            _push(len(_pop()))
            IP += 1
        elif inst == OP_RANGE:
            _push(range(_pop()))
            IP += 1
        
        else:
            halt_fail()
            print("Unknown opcode: ", inst, " at ", IP)
    stop = true

            
        
