extends SceneTree

const VM = preload("./VM.gd")

func _init():
    for i in 5:
        print()
    var focus = false
    for m in get_method_list():
        if m.name.begins_with("__test"):
            focus = true
            var comp = VM.make()
            printraw(m.name, ": ")
            callv(m.name, [comp])
            print()

    if focus:
        call_deferred('quit')
        return

    for m in get_method_list():
        if m.name.begins_with("test_"):
            var comp = VM.new()
            printraw(m.name, ": ")
            callv(m.name, [comp])
            print()
            # if !comp.done:
            #   break
    call_deferred('quit')

func stack_assert(vm, matches, msg, clear= false):
    if not array_eq(vm.stack, matches):
        print(
        msg, " Failed! ",
        " Expected: ", matches, 
        " got ", vm.stack.slice(-len(vm.stack), -1))
    else:
        if clear: vm.stack.clear()
        printraw(".")

func pget(val, path):
    var ret = val
    for p in path:
        if ret[p]:
            ret = ret[p]
        else:
            break
    return ret

#func const_assert(comp, path, val, msg):
#   var toCompare = pget(comp.constants, path)   
#   if comp._eq(toCompare, val):
#       comp.stack.clear()
#       printraw(".")
#   else:
#       print(
#           msg, " failed! ",
#           "Expected to get ", val, " but got ", toCompare, " instead")


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

func test_stack_basics(vm):
    vm.eval("1 2")
    stack_assert(vm, [1, 2], "Can push numbers")

    vm.eval("3 4")
    stack_assert(vm, [1, 2, 3, 4], "Can push -more- numbers", true)

    vm.eval("3 4 swap dup")
    stack_assert(vm, [4, 3, 3], "Can swap, dup", true)

    vm.eval(":test :bar")
    stack_assert(vm, ["test", "bar"], "Can push strings", true)

func test_arithmetic(vm):
    vm.eval("1 2 + 4 5 * 12 4 div 10 5 -")
    stack_assert(vm, [3, 20, 3, 5], "Basic arithmetic works")

func test_comparison(vm):
    vm.eval(":a :b lt? :a :a lt? :b :a lt?")
    stack_assert(vm, [true, false, false], "lt? works as expected", true)
    vm.eval(":a :b le? :a :a le? :b :a le?")
    stack_assert(vm, [true, true, false], "le? works as expected", true)

    vm.eval(":a :b gt? :a :a gt? :b :a gt?")
    stack_assert(vm, [false, false, true], "gt? works as expected", true)

    vm.eval(":a :b ge? :a :a ge? :b :a ge?")
    stack_assert(vm, [false, true, true], "ge? works as expected", true)

    vm.eval(":a :b eq? :a :a eq?")
    stack_assert(vm, [false, true], "eq? works as expected", true)

func test_def(vm):
    vm.eval("def: add + ;")
    stack_assert(vm, [], "Defs do not leave garbage around", true)
    assert_("add" in vm.dict, "add not in dict")

    vm.eval("1 2 add")
    stack_assert(vm, [3], "Defs persist", true)
    
func test_locals(vm):
    vm.eval("defl: test 1 =a 2 =b *a *b + ;")
    vm.eval("test")
    stack_assert(vm, [3], "locals work")

func test_cond(vm):
    vm.eval("0 0 eq? [ :true ] [ :false ] if-else")
    # vm.print_code()
    stack_assert(vm, ["true"], "Conditions work")

    

