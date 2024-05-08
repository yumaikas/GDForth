class_name GDForthVM extends Reference

const LEX = preload("./lex.gd")

signal script_end
signal eval_complete
signal suspended
signal do_print(item)
signal do_error(err)


var trace = 0; var trace_indent = false
var IP = -1 
var stack = []; 
var utilStack = []; 
var returnStack = []; 
var callStack = [];
var loopStack = [];
var locals = {}
var stop = true; var is_error = false
var instance

var dict = {}; 
var evts = {};

var in_exec = false
var CODE = []
var errSymb = {}; var lblSymb = {}; var iterSymb = {}; var prevSymb = {}
var in_evt = false

var Binds = GDScript.new()
var bind_refs = {}

func _init():
    lex = LEX.new()
    for p in get_property_list():
        if p.name.begins_with("OP_"):
            decode_table[get(p.name)] = p.name
    CODE.append(OP_END_EVAL)
    eval(_stdlib)

func halt_fail():
    stop = true
    is_error = true

func bind_instance(to): instance = to
func __pop(stack, errMsg):
    if len(stack) == 0:
        halt_fail(); 
        return {errSymb: errMsg}
    return stack.pop_back()
func _l_push(e): loopStack.append(e)
func _l_pop(): return __pop(loopStack, "LOOP STACK UNDERFLOW")
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

var stdout = null

func do_printraw(toPrint):
    if not stdout:
        printraw(toPrint)
    else:
        stdout.printraw(str(toPrint))
    emit_signal("do_print", toPrint)

func do_print(toPrint):
    do_printraw(toPrint)
    do_printraw("\n")

func do_push_error(err):
    push_error(err)
    emit_signal("do_error", err)

func _has_prefix(word, pre):
    return typeof(word) == TYPE_STRING and word.begins_with(pre)

const argNames = ["a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7", "a8", "a9"]

# TODO: Event select via bound params used for "select context"


func comp(script):
	pass

func do(word, a0=null, a1=null, a2=null, a3=null, a4=null, a5=null, a6=null, a7=null, a8=null, a9=null):
    # print("do, IP at: ", IP)
    if not(word in dict):
        do_push_error(str("Tried to do nonexistent word: ", word))
        return
    var args = [a0, a1, a2, a3, a4, a5, a6, a7, a8, a9]
    for a in args:
        if a != null:
            _push(a)
        else:
            break
    _r_push(IP) 
    _r_push(0)
    IP = dict[word]
    exec()
    # print("stop-do, IP at: ", IP)

func eval(script):
    _r_push(IP)
    IP = len(CODE)
    var res = comp(script)
    if "err" in res:
        do_push_error(str(res.err))
        return
    CODE.append(OP_END_EVAL)
    exec()

func _eval_(script):
    _r_push(IP)
    IP = len(CODE)
    comp(script)
    exec()

    


func sig_resume(a0=null, a1=null, a2=null, a3=null, a4=null, a5=null, a6=null, a7=null, a8=null, a9=null):
    # print("SIG IP AT", IP)
    var args = [a0, a1, a2, a3, a4, a5, a6, a7, a8, a9]
    # print(args)
    for a in args:
        if a != null:
            _push(a)
        else:
            break
    exec()

func exec():

    # print("EXEC IP AT", IP)
    # TODO: Enable this for non-interactive mode?
    if CODE[IP] == OP_RECOVER:
        do_print("OP_RECOVER")
        is_error = false
        stop = false
        IP += 1
    if is_error == true:
        do_push_error("Tried to re-run failed VM with no recover")
    #if stop == false:
    #    do_push_error("Re-entered exec without halting properly!")
    #    return
    stop = false
    var oldip = IP
    while IP < len(CODE) and not stop:
        var inst = CODE[IP]
        if inst is FuncRef:
            # print(inst.function)
            if inst.call_func(self):
                break
        else:
            stop = true
            # print_code()
            print(returnStack, " ", IP)
            do_print(str("Unknown opcode: ", inst, " at ", IP))
    stop = true
    emit_signal("script_end")

