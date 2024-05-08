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
var constant_pool = []
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


var lit_counts = {}
var imm_counts = {}

func imm(name, imm_count=0):
    var ret = funcref(self, name)

    if imm_count != 0:
        imm_counts[ret] = imm_count

    return ret


func iota(name, lit_count=0):
    var ret = funcref(self, name)

    if lit_count != 0:
        lit_counts[ret] = lit_count

    return ret

var OP_ADD = iota("OP_ADD")
var OP_SUB = iota("OP_SUB")
var OP_MUL = iota("OP_MUL")
var OP_DIV = iota("OP_DIV")

var OP_GT = iota("OP_GT")
var OP_GE = iota("OP_GE")
var OP_LT = iota("OP_LT")
var OP_LE = iota("OP_LE")
var OP_EQ = iota("OP_EQ")
var OP_AND = iota("OP_AND")
var OP_OR = iota("OP_OR")

var OP_LIT = iota("OP_LIT", 1)
var OP_BLOCK_LIT = iota("OP_BLOCK_LIT", 2)
var OP_GOTO = iota("OP_GOTO", 1)
var OP_EVAL = iota("OP_EVAL")

var OP_GET_MEMBER = iota("OP_GET_MEMBER", 1)
var OP_SET_MEMBER = iota("OP_SET_MEMBER", 1)

var OP_DEF = iota("OP_DEF")

var OP_U_PUSH = iota("OP_U_PUSH")
var OP_U_POP = iota("OP_U_POP")
var OP_U_FETCH = iota("OP_U_FETCH")
var OP_U_FETCH_1 = iota("OP_U_FETCH_1")
var OP_U_FETCH_2 = iota("OP_U_FETCH_2")
var OP_U_STORE = iota("OP_U_STORE")
var OP_U_STORE_1 = iota("OP_U_STORE_1")
var OP_U_STORE_2 = iota("OP_U_STORE_2")
var OP_L_PUSH = iota("OP_L_PUSH")
var OP_L_POP = iota("OP_L_POP")
var OP_L_FETCH = iota("OP_L_FETCH")
var OP_L_FETCH_1 = iota("OP_L_FETCH_1")
var OP_L_FETCH_2 = iota("OP_L_FETCH_2")
var OP_L_FETCH_3 = iota("OP_L_FETCH_3")
var OP_L_STORE = iota("OP_L_STORE")
var OP_L_STORE_1 = iota("OP_L_STORE_1")
var OP_L_STORE_2 = iota("OP_L_STORE_2")
var OP_L_STORE_3 = iota("OP_L_STORE_3")
var OP_L_HERE_NEXT = iota("OP_L_HERE_NEXT")

var OP_STACK_CLEAR = iota("OP_STACK_CLEAR")

var OP_NARRAY = iota("OP_NARRAY")
var OP_NEW_DICT = iota("OP_NEW_DICT")

var OP_NTH = iota("OP_NTH")
var OP_PUT = iota("OP_PUT")
var OP_LEN = iota("OP_LEN")

var OP_SETLOCAL = iota("OP_SETLOCAL", 1)
var OP_GETLOCAL = iota("OP_GETLOCAL", 1)

var OP_PRINT = iota("OP_PRINT")
var OP_PRINT_STACK = iota("OP_PRINT_STACK")

var OP_IF_ELSE = iota("OP_IF_ELSE")
var OP_WHILE = iota("OP_WHILE")
var OP_GOTO_WHEN_TRUE = iota("OP_GOTO_WHEN_TRUE")

var OP_DUP = iota("OP_DUP")
var OP_DROP = iota("OP_DROP")
var OP_SWAP = iota("OP_SWAP")

var OP_PUSH_SCOPE = iota("OP_PUSH_SCOPE")
var OP_DROP_SCOPE = iota("OP_DROP_SCOPE")

var OP_SUSPEND = iota("OP_SUSPEND")
var OP_END_EVAL = iota("OP_END_EVAL")
var OP_WAIT = iota("OP_WAIT", 1)

var OP_THROW = iota("OP_THROW")
var OP_RECOVER = iota("OP_RECOVER")
var OP_RESET = iota("OP_RESET")
var OP_BECOME = iota("OP_BECOME")

var OP_STACK_SIZE = iota("OP_STACK_SIZE")
var OP_VM = iota("OP_VM")
var OP_SELF = iota("OP_SELF")

var OP_RETURN = iota("OP_RETURN")
var OP_DO_BLOCK = iota("OP_DO_BLOCK")
var OP_CALL = imm("OP_CALL", 1)
var OP_SHUFFLE = iota("OP_SHUFFLE",2)
var OP_SET_SCOPE = iota("OP_SET_SCOPE")
var OP_GET_SCOPE = iota("OP_GET_SCOPE")

var OP_RANGE = iota("OP_RANGE")

var decode_table = {}

func print_code():
    var num_lits = 0
    var num_immediates = 0
    do_print("[")
    var idx = 0
    for o in CODE:
        do_printraw(str(idx, ": "))
        idx += 1
        if num_lits > 0:
            do_print(str("\t", constant_pool[o]))
            num_lits -= 1
        elif num_immediates > 0:
            do_print(str("\t", o))
            num_immediates -= 1
        else:
            do_print(decode_table[o])
            if o in lit_counts:
                num_lits += lit_counts[o]
            if o in imm_counts:
                num_immediates += imm_counts[o]
    do_print("]")
        
var lex

func assoc_constant(value):
    var idx = constant_pool.find(value)
    if idx == -1:
        constant_pool.append(value)
        return len(constant_pool) - 1
    return idx

func parse_call_token(tok, is_method):
    # Expected form: & <method-name> '(' '*' 0-n times ')'
    var name = ""
    var argCount = 0
    var idx = 0

    while idx < len(tok):
        if tok[idx] == "(":
            idx += 1
            break
        elif tok[idx] == ")":
            return { "valid": false, "error": str("Unmatched ) in call, parsing: ", tok) }
        else:
            name += tok[idx]
            idx += 1
    if idx > len(tok) - 1:
        return { "valid": false, "error": str("Method call missing '(' and ')', parsing: ", tok) }

    while idx < len(tok):
        if tok[idx] == '*':
            argCount += 1
            idx += 1
        elif tok[idx] == ")":
            idx += 1
            break
        else:
            return { 
                "valid": false, 
                "error": str("Invalid character in argument count description: ", tok[idx], " parsing: ", tok)
            }
    var discard = tok.ends_with("!")

    var bindName = str(name, "_", argCount)
    if not discard:
        bindName += "_ret"
    if is_method:
        bindName = "m_" + bindName
        
    return {
        "valid": true,
        "name": name,
        "argCount": argCount,
        "discard": discard,
        "bindName": bindName.replace(".", "_dot_"),
    }
    
func try_compile_bind(code, tok):
    var old_code = Binds.source_code

    Binds.source_code += code
    if Binds.reload(true) != OK:
        Binds.source_code = old_code
        Binds.reload(true)
        return {"err": str("Failed to compile bind code for ", tok)}
    return {}

func _comp_method_setup(to):
    CODE.append_array([
            OP_U_PUSH,
            OP_LIT, assoc_constant(to), OP_U_PUSH,
            OP_STACK_SIZE, OP_U_PUSH
    ])

func dump_binds(vm):
    print(vm.Binds.source_code)
    vm.IP += 1

var _comp_map = {
    "+": OP_ADD, "-": OP_SUB, "*": OP_MUL, "div": OP_DIV,
    "lt?": OP_LT, "le?": OP_LE, "gt?": OP_GT, "ge?": OP_GE,
    "eq?": OP_EQ,
    "and": OP_AND,
    "or": OP_OR,
    "debug-binds": funcref(self, "dump_binds"),
    "true": [OP_LIT, assoc_constant(true)],
    "false": [OP_LIT, assoc_constant(false)],
    "null": [OP_LIT, assoc_constant(null)],
    "1+": [OP_LIT, assoc_constant(1), OP_ADD],
    "1-": [OP_LIT, assoc_constant(1), OP_SUB],
    "eval": OP_EVAL,
    "if-else": OP_IF_ELSE,
    "while": [OP_L_PUSH, OP_LIT, assoc_constant(true), OP_WHILE],
    "IF/WHILE": [OP_L_PUSH, OP_WHILE],
    "do-block": OP_DO_BLOCK,
    "throw": OP_THROW,
    "recover-vm": OP_RECOVER,
    "reset-vm": OP_RESET,
    "_s": OP_PRINT_STACK,
    "goto-if-true": OP_GOTO_WHEN_TRUE,
    "u<": OP_U_PUSH, "u>": OP_U_POP, "u@": OP_U_FETCH, "u@1": OP_U_FETCH_1, "u@2": OP_U_FETCH_2, 
    "u!0": OP_U_STORE, "u!1": OP_U_STORE_1, "u!2": OP_U_STORE_2,
    "l<": OP_L_PUSH, "l>": OP_L_POP, "l@": OP_L_FETCH,
    "l@0": OP_L_FETCH, "l@1": OP_L_FETCH_1, "l@2": OP_L_FETCH_2, "l@3": OP_L_FETCH_3,
    "l!0": OP_L_STORE, "l!1": OP_L_STORE_1, "l!2": OP_L_STORE_2, "l!3": OP_L_STORE_3,
	"become": 
    "l<here+": OP_L_HERE_NEXT,
    "clear-stack": OP_STACK_CLEAR,
    "def": OP_DEF,
    "narray": OP_NARRAY,
    "dict": OP_NEW_DICT,
    "put": OP_PUT,
    "get": OP_NTH,
    "nth": OP_NTH,
    "print": OP_PRINT,
    "VM": OP_VM,
    "swap": OP_SWAP,
    "drop": OP_DROP,
    "dup": OP_DUP,
    "len": OP_LEN, # maybe remove, replace with len(*) ?
    "self": OP_SELF,
    "stack-size": OP_STACK_SIZE,
    "suspend": OP_SUSPEND,
}

func code_gen_call(call_info, is_method):
    var codeGen = []
    codeGen.append(str("func ", call_info.bindName, "(vm):\n"))
    if is_method:
        codeGen.append("    var me = vm._pop()\n")

    for i in call_info.argCount:
        codeGen.append(str("    var a", call_info.argCount - i - 1, " = vm._pop()\n"))
    codeGen.append("    ")

    if not call_info.discard:
        codeGen.append("var ret = ")

    if is_method:
        codeGen.append("me.")
    codeGen.append(str(call_info.name, "("))

    for i in call_info.argCount:
        codeGen.append(str("a", i))
        codeGen.append(", ")
    if call_info.argCount > 0:
        codeGen.pop_back()
    codeGen.append(")\n")

    if not call_info.discard:
        codeGen.append("    vm._push(ret)\n")
    codeGen.append("    vm.IP += 1\n\n")
    return "".join(codeGen)
    
var bindlib

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

