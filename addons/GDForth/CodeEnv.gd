class_name CodeEnvironment extends Reference

var dict = {}

const LEX = preload("./lex.gd")
var CODE = []
var _comp_map = {}

var guts

onready var lex = LEX.new()

signal do_print(item)
signal do_error(err)

func _init():
	guts = preload("./LibGuts.gd").new()
	for k in guts._comp_map.keys():
		_comp_map[k] = guts._comp_map[k]

    for p in guts.get_property_list():
        if p.name.begins_with("OP_"):
            decode_table[get(p.name)] = p.name

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
            do_print(str("\t", o))
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

func try_compile_bind(code, tok):
    var old_code = Binds.source_code

    Binds.source_code += code
    if Binds.reload(true) != OK:
        Binds.source_code = old_code
        Binds.reload(true)
        return {"err": str("Failed to compile bind code for ", tok)}
    return {}

func dump_binds(vm):
    print(vm.Binds.source_code)
    vm.IP += 1

func _comp_method_setup(to):
    CODE.append_array([
            guts.OP_U_PUSH,
            guts.OP_LIT, to, guts.OP_U_PUSH,
            guts.OP_STACK_SIZE, guts.OP_U_PUSH
    ])

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

func compile(code):
	var tokens = lex.tokenize(code)
	
    var t_idx = 0
    while t_idx < len(tokens):
        var tok = tokens[t_idx]
        if tok.begins_with(">"):
            CODE.append(guts.OP_SET_MEMBER)
            CODE.append(tok.substr(1))
            t_idx+=1
        elif tok.begins_with(">>"):
            CODE.append_array([
                guts.OP_U_PUSH, guts.OP_DUP, guts.OP_U_POP, # ab -- aab
                guts.OP_SET_MEMBER, CODE.append(tok.substr(1))
            ])
            t_idx+=1
        elif tok.ends_with(")") or tok.ends_with(")!"):
            var is_method = tok.begins_with(".")
            var call_name = tok
            if is_method:
                call_name = call_name.substr(1)

            var call_info = parse_call_token(call_name, is_method)
            if call_info.valid and not bind_refs.has(call_info.bindName):
                var status = try_compile_bind(code_gen_call(call_info, is_method), tok)
                if "err" in status:
                    return {"err": status.err }
                var ref = funcref(self, call_info.bindName)
                bind_refs[call_info.bindName] = ref
                CODE.append(ref)
                t_idx += 1
            elif bind_refs.has(call_info.bindName):
                var ref = bind_refs[call_info.bindName]
                CODE.append(ref)
                t_idx += 1
            else:
                do_push_error(call_info.error)
                return { "err": call_info.error }

        elif tok.begins_with("@"):
            var globalName = tok.substr(1)
            var bindName = str("global_", globalName).replace(".", "_dot_")

            if not bind_refs.has(bindName):
                try_compile_bind("".join([
                    "func ", bindName, "(vm):\n",
                    "    vm._push(", globalName, ")\n",
                    "    vm.IP += 1\n\n",
                ]), tok)
                bind_refs[bindName] = funcref(self, bindName)
            CODE.append(bind_refs[bindName])
            t_idx += 1
        elif tok.begins_with("."):
            CODE.append(guts.OP_GET_MEMBER)
            CODE.append(tok.substr(1))
            t_idx+=1
        elif tok.begins_with('"'):
            CODE.append_array([guts.OP_LIT, tok.substr(1, len(tok)-2)])
            t_idx += 1
        elif tok.begins_with(":") and tok != ":" and tok != "::":
            CODE.append_array([guts.OP_LIT, tok.substr(1)])
            t_idx+=1
        elif tok.begins_with("~"):
            CODE.append_array([guts.OP_WAIT, tok.substr(1)])
            t_idx+=1
        elif tok.begins_with("*") and tok != '*':
            CODE.append_array([guts.OP_GETLOCAL, tok.substr(1)])
            t_idx += 1
        elif tok.begins_with("%") and tok != '%':
            CODE.append_array([
                guts.OP_GETLOCAL, tok.substr(1),
                guts.OP_SWAP, guts.OP_DO_BLOCK,
                guts.OP_SETLOCAL, tok.substr(1)
            ])
            t_idx += 1
        elif tok.begins_with("="):
            CODE.append_array([guts.OP_SETLOCAL, tok.substr(1)])
            t_idx += 1
        elif tok == "shuf:":
            CODE.append_array([
                guts.OP_SHUFFLE, 
                tokens[t_idx+1], 
                tokens[t_idx+2],
            ])
            t_idx += 3
            
        elif tok in [":", "::", "evt:", "evtl:"]:
            var name = tokens[t_idx + 1]
            # print("NAME: ", name)
            var SEEK = t_idx + 2

            while tokens[SEEK] != ";":
                # print("\t", tokens[SEEK])
                if tokens[SEEK] in [":", "::", "evt:", "evtl:"]:
                    var err = str("Cannot nest `", tok, "`, while defining '", name, "'")
                    do_push_error(err)
                    return { "err": err }
                SEEK += 1
                if SEEK >= len(tokens):
                    var err = str("Missing closing semicolon ", tokens[t_idx + 1])
                    do_push_error(err)
                    return { "err": err }

            CODE.append_array([guts.OP_GOTO, 0])
            dict[name] = len(CODE)
            if tok in ["evt:", "evtl:"]:
                evts[name] = len(CODE)
            if tok in ["::", "evtl:"]:
                CODE.append(guts.OP_PUSH_SCOPE)

            var to_comp = tokens.slice(t_idx + 2, SEEK - 1)

            var status = compile(to_comp)
            if status.has("err"):
                return status

            if tok in ["::", "evtl:"]:
                CODE.append(guts.OP_DRguts.OP_SCOPE)
            CODE.append(guts.OP_RETURN)
            CODE[dict[name]-1] = len(CODE)

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

            CODE.append_array([guts.OP_BLOCK_LIT, 0, 0])
            var slot_1 = len(CODE) - 2
            var slot_2 = len(CODE) - 1
            compile(tokens.slice(t_idx + 1, SEEK - 2))
            CODE[slot_2] = slot_2 + 1
            CODE.append(guts.OP_RETURN)
            CODE[slot_1] = len(CODE)
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
            CODE.append_array([guts.OP_LIT, int(tok)])
            t_idx += 1
        elif tok.is_valid_float():
            CODE.append_array([guts.OP_LIT, float(tok)])
            t_idx += 1
        elif tok in dict:
            if typeof(dict[tok]) == TYPE_ARRAY: 
                CODE.append_array(dict[tok])
            else:
                CODE.append_array([guts.OP_CALL, dict[tok]])
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
    # print(Binds.source_code)
    Binds.reload(true)
    bindlib = Binds.new()
    
    for k in bind_refs.keys():
        bind_refs[k].set_instance(bindlib)
    return {}
