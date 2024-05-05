class_name VM_Tests extends SceneTree

const VM = preload("./VM.gd")

func _init():
    for i in 5:
        print()
    var focus = false
    for m in get_method_list():
        if m.name.begins_with("__test"):
            focus = true
            var comp = VM.new()
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
    print("tests complete")
    quit()
    # call_deferred('quit')

func stack_assert(vm, matches, msg, clear=false):
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

    vm.eval("1 2 2dup")
    stack_assert(vm, [1,2,1,2], "Can 2dup", true)

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
    vm.eval(": add ( a b -- c ) + ;")
    stack_assert(vm, [], "Defs do not leave garbage around", true)
    assert_("add" in vm.dict, "add not in dict")

    vm.eval("1 2 add")
    stack_assert(vm, [3], "Defs persist", true)
    
func test_locals(vm):
    vm.eval(":: test 1 =a 2 =b *a *b + ;")
    vm.eval("test")
    stack_assert(vm, [3], "locals work")

func test_cond(vm):
    vm.eval("true [ :true ] [ :false ] if-else")
    # vm.print_code()
    stack_assert(vm, ["true"], "Conditions work")

func derp():
    return true

func pair(a, b):
    return [a, b]

func test_methods(vm):
    vm.bind_instance(self)
    vm.eval("self .derp()")
    stack_assert(vm, [true], "No-arg method calls work", true)
    vm.eval("1 2 self .pair(**)")
    stack_assert(vm, [[1,2]], "Arg method calls work", true)

func test_constants(vm):
    vm.bind_instance(self)
    vm.eval("@File.READ")
    stack_assert(vm, [File.READ], "Global scope access works")

const GDForth = preload("./GDForthAlpha.gd")

func test_loop(vm): 
    vm.eval(" 0 [ 1+ dup 10 lt? ] while")
    stack_assert(vm, [10], "while works",  true)
    vm.eval("0 10 range(*) [ drop 1+ ] each")
    stack_assert(vm, [10],  "each works", true)
    vm.eval("0 10 [ 1+ ] times")
    stack_assert(vm, [10], "times works", true)


func __ignore_test_bench_loop(vm):
    vm.eval(": test-while 0 [ 1+ dup 10000 lt? ] while ;")
    vm.eval(": test-each 0 10000 range [ 1+ ] each ;")
    for i in 1:

        var start = Time.get_ticks_usec()
        var val = 0
        while val < 10000:
            val += 1
        var end = Time.get_ticks_usec()
        print("\nStraight line GDScript ", (end - start) / 1000.0, " msec")
        
        start = Time.get_ticks_usec()
        vm.__prep()
        vm.call("__push", 0)
        var cont = true
        while cont:
            vm.call("__inc")
            vm.call("__dup")
            vm.call("__push", 10000)
            vm.call("__lt")
            cont =  vm.call("___pop")
        end = Time.get_ticks_usec()
        print("GDScript .call Stack ops while took ", (end - start) / 1000.0, " msec")

        start = Time.get_ticks_usec()
        vm.__prep()
        var push = funcref(vm, "__push")
        var inc = funcref(vm, "__inc")
        var dup = funcref(vm, "__dup")
        var lt = funcref(vm, "__lt")
        var pop = funcref(vm, "___pop")
        push.call_func(0)
        cont = true
        while cont:
            inc.call_func()
            dup.call_func()
            push.call_func(10000)
            lt.call_func()
            cont =  pop.call_func()
        end = Time.get_ticks_usec()
        print("GDScript funcref Stack ops while took ", (end - start) / 1000.0, " msec")

        start = Time.get_ticks_usec()
        vm.__prep()
        vm.__push(0)
        cont = true
        while cont:
            vm.__inc()
            vm.__dup()
            vm.__push(10000)
            vm.__lt()
            cont =  vm.___pop()
        end = Time.get_ticks_usec()
        print("GDScript Stack ops while took ", (end - start) / 1000.0, " msec")


        start = Time.get_ticks_usec()
        vm.do("test-while")
        end = Time.get_ticks_usec()
        print("While Loop took ", (end - start) / 1000.0, " msec")
        # stack_assert(vm, [1000], "While looping", true)

        start = Time.get_ticks_usec()
        vm.do("test-each")
        end = Time.get_ticks_usec()
        print("Each Loop took ", (end - start) / 1000.0, " msec")

        var gdf = GDForth.new()
        gdf.load_script("""
            :bench [ 0 swap range [ drop 1 + ] each drop ] def-evt
            :bench-while [ 0 [ 1 + dup 10000 lt? ] while drop ] def-evt
        """)
        start = Time.get_ticks_usec()
        gdf.evt_call("bench-while", 10000)
        end = Time.get_ticks_usec()
        print("Alpha while took ", (end-start)/1000.0, " msec")
        start = Time.get_ticks_usec()
        gdf.evt_call("bench", 10000)
        end = Time.get_ticks_usec()
        print("Alpha Each took ", (end-start)/1000.0, " msec")
        print()
    
func test_strings(vm):
    vm.eval('"This is a string"')
    stack_assert(vm, ["This is a string"], "Basic quoted strings", true)

    vm.eval('"This is \\"a string"')
    stack_assert(vm, ["This is \"a string"], "Quote escapes work", true)

    vm.eval('"This is \\t\\r\\n string"')
    stack_assert(vm, ["This is \t\r\n string"], "tab, carriage retrun, and newline escapes work", true)
    vm.eval('" "')
    stack_assert(vm, [" "], "spaces work", true)

    vm.eval('{ :Foo " " :BAR "\t" :baz }:')
    stack_assert(vm, ["Foo BAR\tbaz"], "}: works", true)

func _ignore_test_classdb(vm):
    vm.eval("class-db &get_class_list() [ print ] each")

