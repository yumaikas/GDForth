class_name GDForthVM extends Reference

signal script_end
signal eval_complete
signal suspended
signal do_print(item)
signal do_error(err)

class Util:
    func v2(a, b):
        return Vector2(a, b)

var util = Util.new()

var m
var IP = -1 

var trace = 0; var trace_indent = false
var stack = []; 
var utilStack = []; 
var returnStack = []; 
var loopStack = [];
var locals = {}
var dict = {}; 
var constant_pool = []
var evts = {};
var stop = true; var is_error = false
var in_exec = false
var CODE = PoolIntArray()
var errSymb = {}; var lblSymb = {}; var iterSymb = {}; var prevSymb = {}
var in_evt = false
var instance

func _init():
    prep()

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

func do_printraw(toPrint):
    printraw(toPrint)
    emit_signal("do_print", toPrint)

func do_print(toPrint):
    do_printraw(toPrint)
    do_printraw("\n")

func do_push_error(err):
    push_error(err)
    emit_signal("do_error", err)

func _has_prefix(word, pre):
    return typeof(word) == TYPE_STRING and word.begins_with(pre)

func call_method(push_nulls=false):
    var on = _pop(); var name = _pop(); var margs = _pop().duplicate()
    #do_print(on, name, margs, push_nulls)
    _dispatch(on, name, margs, push_nulls)

const argNames = ["a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7", "a8", "a9"]


# TODO: Event select via bound params used for "select context"
# TODO: Blog about the return to GDForth Alpha

func _dispatch(on, name, margs, push_nulls = false):
    if typeof(on) == TYPE_OBJECT:
        var ret = on.callv(name, margs)
        if ret != null or push_nulls:
            _push(ret)
    else:
        var expr = Expression.new()
        var anames = argNames.slice(0, len(margs) - 1)
        if len(margs) == 0:
            anames = []
        var toParse = str("m.", name,"(", ", ".join(anames), ")")
        anames.append("m")
        if expr.parse(toParse, anames) != OK:
            stop = true
            is_error = true
            return

        margs.append(on)
        if trace > 0:
            pass
        # do_print([toParse, anames, margs])
        var ret = expr.execute(margs)

        if ret != null or push_nulls:
            _push(ret)


const _stdlib = """
: stop suspend ;
: box 1 narray ;
: nip swap drop ;
: over shuf: ab aba ;
: rot shuf: abc bca ;
: dup-under u< dup u> ;
: if ( block -- quot/' ) [ ] if-else ;
: {empty} 0 narray ;
: { stack-size u< ;
: } stack-size u> - narray ;
: 2dup shuf: ab abab ;
: pos? 0 gt? ;
: 2drop drop drop ;
: 3drop drop drop drop ;
: ) stack-size u> - narray u> u> call-method ;
: )? stack-size u> - narray u> u> call-method-null ;
: nom u> 1 - u< ( eat parameters into a method call ) ;
: }: stack-size u> - narray SP &join( nom ) ;
: }ES: stack-size u> - narray ES &join( nom ) ;
: not ( t/f -- f/t ) [ false ] [ true ] if-else ;
: WRITE 2 ;
: READ 1 ;
: OK 0 ;
: print-raw ( toprint -- ) VM &do_printraw( nom ) ;
:: load ( path -- .. ) =path File &new() =f 
    *f &open( *path READ ) dup OK eq? [ drop *f &get_as_text() eval OK ] if ;

: while ( block: ( -- t/f ) -- ..  ) l< l<here+ l@1 do-block l@ goto-if-true l> l> 2drop ;
: each ( arr block -- .. ) 
    l< l< ( l: block arr )
    l@ len pos? [
        0 l< ( l: block arr idx )
        l<here+ ( l: 3:block 2:arr 1:idx 0:lbl )
        l@2 l@1 nth l@3 do-block ( fetch element via arr & idx, exec block )
        l@1 1+ l!1  ( increment idx )
        l@2 len l@1 gt? l@ goto-if-true ( check if we need to continue )
        l> l> 2drop
    ] if
    l> l> 2drop
;
: times ( num block -- ..  ) 
    ( setup )    l< l< l<here+ ( block num here )
    ( iterate )  l@1 pos? [ l@2 do-block l@1 1- l!1 ] if l@1 pos? l@ goto-if-true 
    ( teardown ) l> l> l> 3drop 
;

"""


func comp(script):
    var toks = tokenize(script)
    return compile(toks)

func do(word, a0=null, a1=null, a2=null, a3=null, a4=null, a5=null, a6=null, a7=null, a8=null, a9=null):
    print("do, IP at: ", IP)
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
    print("stop-do, IP at: ", IP)

func eval(script):
    _r_push(IP)
    IP = len(CODE)
    comp(script)
    CODE.append(OP_END_EVAL)
    exec()

func _eval_(script):
    _r_push(IP)
    IP = len(CODE)
    comp(script)
    exec()


func tokenize(script):
    var drop = false
    var inputs = script.replace("\n", " ").replace("\r", " ").replace("\t", " ")
    var toks = inputs.split(" ", false)

    var ret_toks = []

    for tok in toks:
        if tok == "": continue
        ret_toks.append(tok)

    return ret_toks
    

var lit_counts = {}
var _iota = 0

var imm_counts = {}

func imm(imm_count=0):
    _iota += 1

    if imm_count != 0:
        imm_counts[_iota] = imm_count

    return _iota


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
var OP_AND = iota()
var OP_OR = iota()

var OP_LIT = iota(1)
var OP_BLOCK_LIT = iota(2)
var OP_GOTO = iota(1)
var OP_EVAL = iota()

var OP_GET_MEMBER = iota(1)
var OP_SET_MEMBER = iota(1)

var OP_DEF = iota()

var OP_U_PUSH = iota() 
var OP_U_POP = iota()
var OP_U_FETCH = iota()
var OP_L_PUSH = iota() 
var OP_L_POP = iota()
var OP_L_FETCH = iota()
var OP_L_FETCH_1 = iota()
var OP_L_FETCH_2 = iota()
var OP_L_FETCH_3 = iota()
var OP_L_STORE = iota()
var OP_L_STORE_1 = iota()
var OP_L_STORE_2 = iota()
var OP_L_STORE_3 = iota()
var OP_L_HERE_NEXT = iota()

var OP_STACK_CLEAR = iota()
var OP_CALL_METHOD = iota()
var OP_CALL_METHOD_NULL = iota()
var OP_CALL_METHOD_LIT = iota(1)

var OP_NARRAY = iota()
var OP_NEW_DICT = iota()

var OP_NTH = iota()
var OP_PUT = iota()
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

var OP_THROW = iota()
var OP_RECOVER = iota()
var OP_RESET = iota()

var OP_STACK_SIZE = iota()
var OP_VM = iota()
var OP_SELF = iota()

var OP_RETURN = iota()
var OP_DO_BLOCK = iota()
var OP_CALL = imm(1)
# var OP_GETARG = iota()
var OP_SHUFFLE = iota(2)
var OP_SET_SCOPE = iota()
var OP_GET_SCOPE = iota()

var OP_RANGE = iota()


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
        
        
func prep():
    for p in get_property_list():
        if p.name.begins_with("OP_"):
            decode_table[get(p.name)] = p.name
    CODE.append(OP_END_EVAL)
    eval(_stdlib)
            

func assoc_constant(value):
    var idx = constant_pool.find(value)
    if idx == -1:
        constant_pool.append(value)
        return len(constant_pool) - 1
    return idx

func _comp_method_setup(to):
    CODE.append_array([
            OP_U_PUSH,
            OP_LIT, assoc_constant(to), OP_U_PUSH,
            OP_STACK_SIZE, OP_U_PUSH
    ])

var _comp_map = {
    "+": OP_ADD, "-": OP_SUB, "*": OP_MUL, "div": OP_DIV,
    "lt?": OP_LT, "le?": OP_LE, "gt?": OP_GT, "ge?": OP_GE,
    "eq?": OP_EQ,
    "and": OP_AND,
    "or": OP_OR,
    "true": [OP_LIT, assoc_constant(true)],
    "false": [OP_LIT, assoc_constant(false)],
    "null": [OP_LIT, assoc_constant(null)],
    "util": [OP_LIT, assoc_constant(util)],
    "SP": [OP_LIT, assoc_constant(" ")],
    "DQ": [OP_LIT, assoc_constant('"')],
    "SQ": [OP_LIT, assoc_constant("'")],
    "TAB": [OP_LIT, assoc_constant("\t")],
    "CR": [OP_LIT, assoc_constant("\r")],
    "NL": [OP_LIT, assoc_constant("\n")],
    "COLON": [OP_LIT, assoc_constant(":")],
    "ES": [OP_LIT, assoc_constant("")],
    "1+": [OP_LIT, assoc_constant(1), OP_ADD],
    "1-": [OP_LIT, assoc_constant(1), OP_SUB],
    "File": [OP_LIT, assoc_constant(File)],
    "eval": OP_EVAL,
    "if-else": OP_IF_ELSE,
    "do-block": OP_DO_BLOCK,
    "throw": OP_THROW,
    "recover-vm": OP_RECOVER,
    "reset-vm": OP_RESET,
    "_s": OP_PRINT_STACK,
    "class-db": [OP_LIT,assoc_constant(ClassDB)],
    "goto-if-true": OP_GOTO_WHEN_TRUE,
    "u<": OP_U_PUSH, "u>": OP_U_POP, "u@": OP_U_FETCH,
    "l<": OP_L_PUSH, "l>": OP_L_POP, "l@": OP_L_FETCH,
    "l@0": OP_L_FETCH, "l@1": OP_L_FETCH_1, "l@2": OP_L_FETCH_2, "l@3": OP_L_FETCH_3,
    "l!0": OP_L_STORE, "l!1": OP_L_STORE_1, "l!2": OP_L_STORE_2, "l!3": OP_L_STORE_3,
    "l<here+": OP_L_HERE_NEXT,
    "call-method": OP_CALL_METHOD,
    "call-method-null": OP_CALL_METHOD_NULL,
    "clear-stack": OP_STACK_CLEAR,
    "def": OP_DEF,
    "narray": OP_NARRAY,
    "dict": OP_NEW_DICT,
    "put": OP_PUT,
    "get": OP_NTH,
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
        elif tok.begins_with(">"):
            CODE.append(OP_SET_MEMBER)
            CODE.append(assoc_constant(tok.substr(1)))
            t_idx+=1
        elif tok.begins_with(">>"):
            CODE.append_array([
                OP_U_PUSH, OP_DUP, OP_U_POP, # ab -- aab
                OP_SET_MEMBER, CODE.append(assoc_constant(tok.substr(1)))
            ])
            t_idx+=1
        elif tok.begins_with("&"):
            if tok.ends_with("("):
                _comp_method_setup(tok.substr(1, len(tok)-2))
                t_idx+=1
            elif tok.ends_with("()"):
                CODE.append_array([
                    OP_CALL_METHOD_LIT, assoc_constant(tok.substr(1, len(tok)-3))
                ])
                t_idx+=1
            else:
                var err = str("Could not compile ", tok, " as a call")
                do_push_error(err)
                return { "err": err }
#        elif tok.begins_with("$"):
#            if tok.substr(1) in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]:
#                CODE.append_array([ OP_GETARG, int(tok.substr(1)) ])
#                t_idx+=1
#            else:
#                var err = str("Could not compile ", tok, " as a valid argument get")
#                do_push_error(err)
#                return { "err": err }
        elif tok.begins_with(":") and tok != ":" and tok != "::":
            CODE.append_array([OP_LIT, assoc_constant(tok.substr(1))])
            t_idx+=1
        elif tok.begins_with("~"):
            CODE.append_array([OP_WAIT, assoc_constant(tok.substr(1))])
            t_idx+=1
        elif tok.begins_with("*") and tok != '*':
            CODE.append_array([OP_GETLOCAL, assoc_constant(tok.substr(1))])
            t_idx += 1
        elif tok.begins_with("%") and tok != '%':
            CODE.append_array([
                OP_GETLOCAL, assoc_constant(tok.substr(1)),
                OP_SWAP, OP_DO_BLOCK,
                OP_SETLOCAL, assoc_constant(tok.substr(1))
            ])
            t_idx += 1
        elif tok.begins_with("="):
            CODE.append_array([OP_SETLOCAL, assoc_constant(tok.substr(1))])
            t_idx += 1
        elif tok == "shuf:":
            CODE.append_array([
                OP_SHUFFLE, 
                assoc_constant(tokens[t_idx+1]), 
                assoc_constant(tokens[t_idx+2]),
            ])
            t_idx += 3
            
        elif tok in [":", "::", "evt:", "evtl:"]:
            var name = tokens[t_idx + 1];
            var SEEK = t_idx + 2;

            while tokens[SEEK] != ";":
                if tokens[SEEK] in [":", "::", "evt:", "evtl:"]:
                    var err = str("Cannot nest `", tok, "`, while defining '", name, "'")
                    do_push_error(err)
                    return { "err": err }
                SEEK += 1
            # Create a 
            CODE.append_array([OP_GOTO, 0])
            dict[name] = len(CODE)
            if tok in ["evt:", "evtl:"]:
                evts[name] = len(CODE)

            if tok in ["::", "evtl:"]:
                CODE.append(OP_PUSH_SCOPE)

            var to_comp = tokens.slice(t_idx + 2, SEEK - 1)

            var status = compile(to_comp)
            if "err" in status:
                return status

            if tok in ["::", "evtl:"]:
                CODE.append(OP_DROP_SCOPE)
            CODE.append(OP_RETURN)
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
                    do_push_error(err)
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
        elif tok == "(":
            var SEEK = t_idx + 1;
            var DEPTH = 1
            while DEPTH > 0:
                if tokens[SEEK] == "(": DEPTH += 1
                elif tokens[SEEK] == ")": DEPTH -= 1
                if SEEK > len(tokens):
                    var err = str("Unmatched (")
                    do_push_error(err)
                    return {"err": err}
                SEEK += 1
            t_idx = SEEK
        elif tok.is_valid_integer():
            CODE.append_array([OP_LIT, assoc_constant(int(tok))])
            t_idx += 1
        elif tok.is_valid_float():
            CODE.append_array([OP_LIT, assoc_constant(float(tok))])
            t_idx += 1
        elif tok in dict:
            if typeof(dict[tok]) == TYPE_ARRAY: 
                CODE.append_array(dict[tok])
            else:
                CODE.append_array([OP_CALL, dict[tok]])
            t_idx += 1
        elif tok in _comp_map:
            if typeof(_comp_map[tok]) == TYPE_ARRAY:
                CODE.append_array(_comp_map[tok])
            else:
                CODE.append(_comp_map[tok])
            t_idx += 1
        else:
            var err = str("Unrecognized command: ", tok)
            do_print(str(_comp_map.keys()))
            do_print(str(dict.keys()))
            do_push_error(err)
            return {"err": err}
    return {}

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
#        if CODE[IP] in decode_table:
#            do_printraw(decode_table[CODE[IP]])
#        else:
#            do_printraw("IP@: " + str(CODE[IP]))
#        if CODE[IP] in lit_counts:
#            do_printraw(": ")
#            for i in lit_counts[CODE[IP]]:
#                do_printraw(constant_pool[CODE[IP+i+1]])
#                if i+1 < lit_counts[CODE[IP]]:
#                    do_printraw(", ")
#        if CODE[IP] in imm_counts:
#            do_printraw(": ")
#            for i in imm_counts[CODE[IP]]:
#                do_printraw(CODE[IP+i+1])
#                if i+1 < imm_counts[CODE[IP]]:
#                    do_printraw(", ")
#
        # do_printraw(" S: " + str(stack)+" ")
        # do_print("")
                
        var inst = CODE[IP]

        if inst == OP_LIT:
            _push(constant_pool[CODE[IP+1]])
            IP += 2
        elif inst == OP_CALL:
            _r_push(IP+2)
            IP = CODE[IP+1]
        elif inst == OP_U_PUSH:
            _u_push(_pop())
            IP += 1
        elif inst == OP_U_POP:
            _push(_u_pop())
            IP += 1
        elif inst == OP_U_FETCH:
            _push(utilStack.back())
            IP += 1
        elif inst == OP_L_PUSH:
            _l_push(_pop())
            IP += 1
        elif inst == OP_L_POP:
            _push(_l_pop())
            IP += 1
        elif inst == OP_L_FETCH:
            _push(loopStack.back())
            IP += 1
        elif inst == OP_L_FETCH_1:
            _push(loopStack[len(loopStack)-2])
            IP += 1
        elif inst == OP_L_FETCH_2:
            _push(loopStack[len(loopStack)-3])
            IP += 1
        elif inst == OP_L_FETCH_3:
            _push(loopStack[len(loopStack)-4])
            IP += 1
        elif inst == OP_L_STORE:
            loopStack[len(loopStack)-1] = _pop()
            IP += 1
        elif inst == OP_L_STORE_1:
            loopStack[len(loopStack)-2] = _pop()
            IP += 1
        elif inst == OP_L_STORE_2:
            loopStack[len(loopStack)-3] = _pop()
            IP += 1
        elif inst == OP_L_STORE_3:
            loopStack[len(loopStack)-4] = _pop()
            IP += 1
        elif inst == OP_L_HERE_NEXT:
            _l_push(IP+1)
            IP += 1
        elif inst == OP_WAIT:
            # print("WAIT IP AT", IP)
            if in_evt:
                do_print("ERROR: suspended in evt_call!")
                halt_fail()
                return
            var obj = _pop()
            var sig = constant_pool[CODE[IP+1]]
            if not obj.is_connected(sig, self, "sig_resume"):
                if trace > 0: do_print("connecting")
                obj.connect(sig, self, "sig_resume", [], CONNECT_ONESHOT | CONNECT_DEFERRED)
            else:
                do_print(str("Already connected to ", obj))
            stop = true
            IP += 2
            # print("WAIT IP AT", IP)
        elif inst == OP_THROW:
            var maybe_err = _pop()
            if not (typeof(maybe_err) == typeof(OK) and maybe_err == OK):
                halt_fail()
                return
            else:
                IP += 1
        elif inst == OP_RECOVER:
            do_print("Recover is a no-op outside resuming a faulted VM")
            IP += 1
        elif inst == OP_RESET:
            stack = []; 
            utilStack = []; 
            returnStack = []; 
            loopStack = [];
            locals = {}
            IP += 1
        elif inst == OP_SHUFFLE:
            var shuf_locals = {}
            var input = constant_pool[CODE[IP+1]]
            var output = constant_pool[CODE[IP+2]]

            for i in len(input):
                var idx = len(input) - i - 1
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
            var lbl = _pop()
            IP = lbl
        elif inst == OP_GET_MEMBER:
            _push(_pop().get(constant_pool[CODE[IP+1]]))
            IP += 2
        elif inst == OP_DEF:
            var block = _pop()
            var name = _pop()
            dict[name] = block
            IP += 1
        elif inst == OP_SET_MEMBER:
            var to = _pop()
            var on = _pop()
            on.set(constant_pool[CODE[IP+1]], to)
            IP += 2
        elif inst == OP_PUT:
            var at = _pop()
            var on = _pop()
            var to = _pop()
            on[at] = to
            IP += 1
        elif inst == OP_SELF:
            _push(instance)
            IP += 1
        elif inst == OP_VM:
            _push(self)
            IP += 1
        elif inst == OP_CALL_METHOD_LIT:
            var mname = constant_pool[CODE[IP+1]]
            _dispatch(_pop(), mname, [], false)
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
        elif inst == OP_NEW_DICT:
            _push({})
            IP += 1
        elif inst == OP_PRINT:
            do_print(_pop())
            IP += 1
        elif inst == OP_SUSPEND:
            stop = true
            IP += 1
            emit_signal("suspended")
            break
        elif inst == OP_EVAL:
            _r_push(IP+1)
            _eval_(_pop())
        elif inst == OP_END_EVAL:
            stop = true
            IP = _r_pop()
            emit_signal("eval_complete")
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
            var JUMP = _pop()
            if _pop(): 
                IP = JUMP
            else:
                IP += 1
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
            _push(typeof(a) == typeof(b) and a == b)
            IP += 1
        elif inst == OP_AND:
            var b = _pop(); var a = _pop();
            _push(a and b)
            IP += 1
        elif inst == OP_OR:
            var b = _pop(); var a = _pop();
            _push(a or b)
            IP += 1
        elif inst == OP_PRINT:
            do_print(_pop())
            IP += 1
        elif inst == OP_LEN:
            _push(len(_pop()))
            IP += 1
        elif inst == OP_RANGE:
            _push(range(_pop()))
            IP += 1
        else:
            stop = true
            #print_code()
            print(returnStack, " ", IP)
            do_print(str("Unknown opcode: ", inst, " at ", IP))
    stop = true
    emit_signal("script_end")

            
        
