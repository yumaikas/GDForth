class_name GDForthVM extends Reference

signal script_end


var m
var IP = -1
var trace = 0; var trace_indent = false
var stack = []; var utilStack = []; var returnStack = []
var dict = {}; var locals = {}
var constant_pool = []
var evts = {};
var stop = false; var is_error = false
var CODE 
var errSymb = {}; var lblSymb = {}; var iterSymb = {}; var prevSymb = {}
var in_evt = false
var instance


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

const OP_2_BLOCKLIT = 8
const OP_2_LIT = 9
const OP_ADD = 10
const OP_SUB = 11
const OP_MUL = 12
const OP_DIV = 13
const OP_GT = 14
const OP_GE = 15
const OP_LT = 16
const OP_LE = 17
const OP_EQ = 18
const OP_PICK_DEL = 19
const OP_LIT = 20
const OP_BLOCK_LIT = 21
const OP_GET_MEMBER = 22
const OP_SET_MEMEBER = 23
const OP_U_PUSH = 24 
const OP_U_POP = 25
const OP_STACK_CLEAR = 26
const OP_CALL_METHOD = 27
const OP_CALL_METHOD_NULL = 28
const OP_NARRAY = 29
const OP_PRINT = 30
const OP_LEN = 31
const OP_SUSPEND = 32
const OP_SETLOCAL = 33
const OP_NTH = 34
const OP_IF_ELSE = 35
const GOTO_WHEN_TRUE = 36
const OP_DUP = 37
const OP_DROP = 38
const OP_PUSH_SCOPE = 39
const OP_DROP_SCOPE = 40
const OP_STACK_SIZE = 41
const OP_RETURN = 42
const OP_DO_BLOCK = 43
const OP_CALL = 44
const OP_GETARG = 45
const OP_WAIT = 46
const OP_SHUFFLE = 47

func asssoc_constant(value):
    var idx = constants.find(value)
    if idx == -1:
        constants.append(value)
        return len(constants) - 1
    return idx

func compile(tokens):
    pass


func run_vm():
    stop = false
    while IP < len(CODE) and not stop:
    if inst == OP_LIT:
        _push(constants[CODE[IP+1]]); IP += 2
    if inst == OP_2_LIT:
        _push(constants[CODE[IP+1] + CODE

    elif inst == OP_GETVAR
        _push(locals[CODE[IP+1]])
        IP += 2
    elif inst == OP_CALL:
        _r_push(IP+1)
        IP = CODE[IP+1]
    elif inst == OP_U_PUSH:
        _u_push(_pop())
        IP += 1
    elif inst == OP_U_POP:
        _push(_u_pop)
        IP += 1
    elif inst == OP_WAIT:
        if in_evt:
            print("ERROR: suspended in evt_call!")
            halt_fail()
            return
        var obj = _pop()
        var sig = constants[CODE[IP+1]]
        if not obj.is_connected(sig, self, "sig_resume"):
            if trace > 0: print("connecting")
            obj.connect(sig, self, "sig_resume", [], CONNECT_ONESHOT | CONNECT_DEFERRED)
        else:
            print(str("Already connected to ", obj))
        stop = true
        IP += 1
    elif inst == OP_SHUFFLE:
        var shuf_locals = {}
        var input = CODE[IP+1]
        var ouput = CODE[IP+2]

        for i in len(input):
            var idx = len(input) - i
            var c = input[idx]
            shuf_locals[c] = _pop()
        for c in output:
            _push(shuf_locals[c])
        IP += 3
    elif inst == OP_BLOCK_LIT:
        _push(
        IP = CODE[IP+1]

        


        
        

func do_op(op):
    
