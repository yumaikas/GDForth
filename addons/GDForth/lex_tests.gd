class_name lex_tests extends SceneTree

const LEX = preload("./lex.gd")

func _init():
    for i in 5:
        print()
    var focus = false
    for m in get_method_list():
        if m.name.begins_with("__test"):
            focus = true
            printraw(m.name, ": ")
            callv(m.name, [])
            print()

    if focus:
        call_deferred('quit')
        return

    for m in get_method_list():
        if m.name.begins_with("test_"):
            printraw(m.name, ": ")
            callv(m.name, [])
            print()
            # if !comp.done:
            #   break
    print("tests complete")
    quit()
    # call_deferred('quit')

func array_assert(given, matches, msg, clear = false):
    if not array_eq(given, matches):
        print(
        msg, " Failed! ",
        " Expected: ", matches, 
        " got ", given.slice(-len(given), -1))
    else:
        printraw(".")

func pget(val, path):
    var ret = val
    for p in path:
        if ret[p]:
            ret = ret[p]
        else:
            break
    return ret


func array_eq(arr1, arr2):
    if len(arr1) != len(arr2):
        return false
    var idx = 0
    for i in arr1:
        if arr2[idx] != i:
            return false
        idx+=1
    return true

func assert_(cond, message):
    if not cond:
        print("Failed: ", message)
        quit()
    else:
        printraw(".")

func test_basic_strings():
    var lex = LEX.new()

    var toks = lex.tokenize('a b d "foo bar"')
    array_assert(toks, ["a", "b", "d", '"foo bar"'], "Can tokenize a basic string")

func test_quote_escaping():
    var lex = LEX.new()

    var toks = lex.tokenize('"foo \\" bar"')
    array_assert(toks, ['"foo " bar"'], "Can tokenize a basic string")

func test_literal_escaping():
    var lex = LEX.new()

    var toks = lex.tokenize('"foo \\"\\t bar"')
    array_assert(toks, ['"foo "\t bar"'], "Can tokenize a basic string")

    toks = lex.tokenize('"foo \\"\\t\\r\\n bar"')
    array_assert(toks, ['"foo "\t\r\n bar"'], "Can tokenize a basic string")

func test_a_bug():
    var lex = LEX.new()

    var toks = lex.tokenize('"foo" "elif"')
    array_assert(toks, ['"foo"', '"elif"'], "Addressing a bug")
    

func test_asdf():
    var lex = LEX.new()

    var toks = lex.tokenize('":\n"    ')
    array_assert(toks, ['":\n"'], "Can tokenize a basic string")

