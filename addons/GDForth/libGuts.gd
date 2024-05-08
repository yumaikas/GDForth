class_name LibGuts extends Reference

var lit_counts = {}
var imm_counts = {}

func load_lib(into):
	into.compile(_stdlib)

const _stdlib = """
: stop suspend ;
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
: }: stack-size u> - narray "" .join(*) ;
: not ( t/f -- f/t ) [ false ] [ true ] if-else ;
: WRITE 2 ;
: OK 0 ;
: print-raw ( toprint -- ) VM .do_printraw(*)! ;
:: load ( path -- .. ) =path File.new() =f 
    *path @File.READ *f .open(**) dup OK eq? [ drop *f .get_as_text() eval OK ] if ;

: each ( arr block -- .. ) 0 u< u< u<
    u@ len pos? [ 
        u@ u@2 nth u@1 do-block ( execute )
        u@2 1+ u!2 ( increment )
        u@ len u@2 gt? ( condition )
    ]  IF/WHILE u> u> u> 3drop ;

: times ( num block -- ..  ) 
    ( setup )    l< l< l<here+ ( block num here )
    ( iterate )  l@1 pos? [ l@2 do-block l@1 1- l!1 ] if l@1 pos? l@ goto-if-true 
    ( teardown ) l> l> l> 3drop 
;

"""

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

var _comp_map = {
    "+": OP_ADD, "-": OP_SUB, "*": OP_MUL, "div": OP_DIV,
    "lt?": OP_LT, "le?": OP_LE, "gt?": OP_GT, "ge?": OP_GE,
    "eq?": OP_EQ,
    "and": OP_AND,
    "or": OP_OR,
    "debug-binds": funcref(self, "dump_binds"),
    "true": [OP_LIT, true],
    "false": [OP_LIT, false],
    "null": [OP_LIT, null],
    "1+": [OP_LIT, 1, OP_ADD],
    "1-": [OP_LIT, 1, OP_SUB],
    "eval": OP_EVAL,
    "if-else": OP_IF_ELSE,
    "while": [OP_L_PUSH, OP_LIT, true, OP_WHILE],
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

func OP_LIT(vm):
    vm._push(vm.CODE[vm.IP+1])
    vm.IP += 2
func OP_CALL(vm):
    vm._r_push(vm.IP+2)
    vm.IP = vm.CODE[vm.IP+1]
func OP_U_PUSH(vm):
    vm._u_push(vm._pop())
    vm.IP += 1
func OP_U_POP(vm):
    vm._push(vm._u_pop())
    vm.IP += 1
func OP_U_FETCH(vm):
    vm._push(vm.utilStack[len(vm.utilStack)-1])
    vm.IP += 1
func OP_U_FETCH_1(vm):
    vm._push(vm.utilStack[len(vm.utilStack)-2])
    vm.IP += 1
func OP_U_FETCH_2(vm):
    vm._push(vm.utilStack[len(vm.utilStack)-3])
    vm.IP += 1
func OP_U_STORE(vm):
    vm.utilStack[len(vm.utilStack)-1] = _pop()
    IP += 1
func OP_U_STORE_1(vm):
    vm.utilStack[len(vm.utilStack)-2] = vm._pop()
    vm.IP += 1
func OP_U_STORE_2(vm):
    vm.utilStack[len(vm.utilStack)-3] = vm._pop()
    vm.IP += 1
func OP_L_PUSH(vm):
    vm._l_push(vm._pop())
    vm.IP += 1
func OP_L_POP(vm):
    vm._push(vm._l_pop())
    vm.IP += 1
func OP_L_FETCH(vm):
    vm._push(vm.loopStack.back())
    vm.IP += 1
func OP_L_FETCH_1(vm):
    vm._push(vm.loopStack[len(vm.loopStack)-2])
    IP += 1
func OP_L_FETCH_2(vm):
    vm._push(loopStack[len(vm.loopStack)-3])
    vm.IP += 1
func OP_L_FETCH_3(vm):
    vm._push(vm.loopStack[len(vm.loopStack)-4])
    vm.IP += 1
func OP_L_STORE(vm):
    vm.loopStack[len(vm.loopStack)-1] = vm._pop()
    vm.IP += 1
func OP_L_STORE_1(vm):
    vm.loopStack[len(vm.loopStack)-2] = vm._pop()
    vm.IP += 1
func OP_L_STORE_2(vm):
    vm.loopStack[len(vm.loopStack)-3] = vm._pop()
    vm.IP += 1
func OP_L_STORE_3(vm):
    vm.loopStack[len(vm.loopStack)-4] = vm._pop()
    vm.IP += 1
func OP_L_HERE_NEXT(vm):
    vm._l_push(vm.IP+1)
    vm.IP += 1
func OP_WAIT(vm):
    # print("WAIT IP AT", IP)
    if vm.in_evt:
        vm.do_print("ERROR: suspended in evt_call!")
        vm.halt_fail()
        return
    var obj = vm._pop()
    var sig = vm.CODE[vm.IP+1]
    if not obj.is_connected(sig, vm, "sig_resume"):
        if vm.trace > 0: vm.do_print("connecting")
        obj.connect(sig, vm, "sig_resume", [], CONNECT_ONESHOT | CONNECT_DEFERRED)
    else:
        vm.do_print(str("Already connected to ", obj))
    vm.stop = true
    vm.IP += 2
    # print("WAIT IP AT", IP)
func OP_THROW(vm):
    var maybe_err = vm._pop()
    if not (typeof(maybe_err) == typeof(OK) and maybe_err == OK):
        vm.halt_fail()
        return
    else:
        vm.IP += 1
func OP_RECOVER(vm):
    vm.do_print("Recover is a no-op outside resuming a faulted VM")
    vm.IP += 1

func OP_RESET(vm):
    vm.stack = []; 
    vm.utilStack = []; 
    vm.returnStack = []; 
	vm.callStack = [];
    vm.loopStack = [];
    vm.locals = {}
    vm.IP += 1

func OP_BECOME(vm):
	var newStack = vm._pop()
	var starting_fn = vm._pop()
	OP_RESET(vm)
	vm.stack.append_array(newStack)
	vm.IP = vm.dict[starting_fn]

func OP_SHUFFLE(vm):
    var shuf_locals = {}
    var input = vm.CODE[vm.IP+1]
    var output = vm.CODE[vm.IP+2]

    for i in len(input):
        var idx = len(input) - i - 1
        var c = input[idx]
        shuf_locals[c] = vm._pop()
    for c in output:
         vm._push(shuf_locals[c])
    vm.IP += 3
func OP_BLOCK_LIT(vm):
    vm._push(vm.vm.CODE[vm.IP+2])
    vm.IP = vm.CODE[vm.IP+1]
func OP_RETURN(vm):
    vm.IP = vm._r_pop()
func OP_DO_BLOCK(vm):
    vm._r_push(IP+1)
    var lbl = vm._pop()
    vm.IP = lbl

func OP_WHILE(vm):
    var cont = vm._pop()
    if cont:
        vm._r_push(vm.IP)
        vm.IP = vm.loopStack.back()
    else:
        vm._l_pop()
        vm.IP += 1

func OP_GET_MEMBER(vm):
    vm._push(vm._pop().get(vm.CODE[vm.IP+1]))
    vm.IP += 2
func OP_DEF(vm):
    var block = vm._pop()
    var name = vm._pop()
    vm.dict[name] = block
    vm.IP += 1
func OP_SET_MEMBER(vm):
    var to = vm._pop()
    var on = vm._pop()
    on.set(vm.CODE[vm.IP+1], to)
    vm.IP += 2
func OP_PUT(vm):
    var at = vm._pop()
    var on = vm._pop()
    var to = vm._pop()
    on[at] = to
    vm.IP += 1
func OP_SELF(vm):
    vm._push(vm.instance)
    vm.IP += 1
func OP_VM(vm):
    vm._push(vm)
    vm.IP += 1

func OP_STACK_CLEAR(vm):
    vm.stack.clear()
    vm.IP += 1

func OP_STACK_SIZE(vm):
    vm._push(len(vm.stack))
    vm.IP += 1


func OP_NARRAY(vm):
    var n = _pop(); 
    if n == 0:
        vm._push([])
    else:
        # TODO: Optimize to slice + resize
        var top = []
        for i in n: top.append(vm._pop())
        top.invert(); vm._push(top)
    vm.IP += 1
func OP_NEW_DICT(vm):
    vm._push({})
    vm.IP += 1

func OP_SUSPEND(vm):
    vm.stop = true
    vm.IP += 1
    vm.emit_signal("suspended")
    return true

func OP_EVAL(vm):
    vm._r_push(vm.IP+1)
    vm._eval_(vm._pop())

func OP_END_EVAL(vm):
    vm.stop = true
    vm.IP = vm._r_pop()
    vm.emit_signal("eval_complete")
    return true

func OP_NTH(vm):
    var at = vm._pop(); var arr = vm._pop();
    vm._push(arr[at])
    vm.IP += 1

func OP_IF_ELSE(vm):
    var false_lbl = vm._pop() 
    var true_lbl = vm._pop()
    var cond = vm._pop()
    if cond:
        vm._r_push(vm.IP+1); vm.IP = true_lbl
    else:
        vm._r_push(vm.IP+1); vm.IP = false_lbl


func OP_GOTO(vm):
    vm.IP = vm.CODE[vm.IP+1]
func OP_GOTO_WHEN_TRUE(vm):
    var JUMP = vm._pop()
    if vm._pop(): 
        vm.IP = JUMP
    else:
        vm.IP += 1
func OP_DUP(vm):
    vm.stack.push_back(vm.stack.back())
    vm.IP += 1
func OP_DROP(vm):
    vm.stack.pop_back()
    vm.IP += 1
func OP_SWAP(vm):
    var a = vm.stack[len(vm.stack)-1]
    vm.stack[len(vm.stack)-1] = vm.stack[len(vm.stack)-2]
    vm.stack[len(vm.stack)-2] = a
    vm.IP += 1
func OP_PUSH_SCOPE(vm):
    var old_locals = vm.locals
    vm.locals = { vm.prevSymb: old_locals }
    vm.IP += 1
func OP_DROP_SCOPE(vm):
    var old_locals = vm.locals[vm.prevSymb]
    vm.locals = old_locals
    vm.IP += 1
func OP_GET_SCOPE(vm):
    vm._push(vm.locals)
    vm.IP += 1
func OP_SET_SCOPE(vm):
    vm.locals = vm._pop()
    vm.IP += 1
func OP_SETLOCAL(vm):
    var local_key = vm.CODE[vm.IP+1]
    vm.locals[local_key] = vm._pop()
    vm.IP += 2
func OP_GETLOCAL(vm):
    var local_key = vm.CODE[vm.IP+1]
    vm._push(vm.locals[local_key])
    vm.IP += 2
func OP_ADD(vm):
    var b = vm._pop(); var a = vm._pop();
    vm._push(a + b)
    vm.IP += 1
func OP_SUB(vm):
    var b = vm._pop(); var a = vm._pop();
    vm._push(a - b)
    vm.IP += 1
func OP_MUL(vm):
    var b = vm._pop(); var a = vm._pop();
    vm._push(a * b)
    vm.IP += 1
func OP_DIV(vm):
    var b = vm._pop(); var a = _pop();
    _push(a / b)
    vm.IP += 1
func OP_GT(vm):
    var b = vm._pop(); var a = vm._pop();
    vm._push(a > b)
    vm.IP += 1
func OP_LT(vm):
    var b = vm._pop(); var a = vm._pop();
    vm._push(a < b)
    vm.IP += 1
func OP_GE(vm):
    var b = vm._pop(); var a = vm._pop();
    vm._push(a >= b)
    vm.IP += 1
func OP_LE(vm):
    var b = vm._pop(); var a = vm._pop();
    vm._push(a <= b)
    vm.IP += 1
func OP_EQ(vm):
    var b = vm._pop(); var a = vm._pop();
    vm._push(typeof(a) == typeof(b) and a == b)
    vm.IP += 1
func OP_AND(vm):
    var b = vm._pop(); var a = vm._pop();
    vm._push(a and b)
    vm.IP += 1
func OP_OR(vm):
    var b = vm._pop(); var a = vm._pop();
    vm._push(a or b)
    vm.IP += 1
func OP_PRINT(vm):
    vm.do_print(vm._pop())
    vm.IP += 1
func OP_PRINT_STACK(vm):
    vm.do_print(str(vm.stack))
    vm.IP += 1
func OP_LEN(vm):
    var toLen = vm._pop()
    vm._push(len(toLen))
    vm.IP += 1
