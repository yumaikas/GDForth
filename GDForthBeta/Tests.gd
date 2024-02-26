extends SceneTree

const GDForth = preload("./GDForth.gd")

func _init():
	for i in 5:
		print()
	var focus = false
	for m in get_method_list():
		if m.name.begins_with("__test"):
			focus = true
			var comp = GDForth.new()
			printraw(m.name, ": ")
			callv(m.name, [comp])
			print()

	if focus:
		call_deferred('quit')
		return

	for m in get_method_list():
		if m.name.begins_with("test_"):
			var comp = GDForth.new()
			printraw(m.name, ": ")
			callv(m.name, [comp])
			print()
			if !comp.done:
				break
	call_deferred('quit')

func stack_assert(comp, matches, msg):
	if not array_eq(comp.stack, matches):
		print(
		msg, " Failed! ",
		" Expected: ", matches, 
		" got ", comp.stack.slice(-len(comp.stack), -1))
	else:
		comp.stack.clear()
		printraw(".")

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

func test_pushing(comp):
	comp.interpret(":asdf")
	assert_(comp.stack.back() == "asdf", "String Symbol Literal failed!")

	comp.interpret(" [[this is a test]] ")
	assert_(comp.stack.back() == "this is a test", "Long string failed!")

	comp.interpret("clear-stack")
	comp.interpret("1 2 3")
	assert_(comp.stack == [1, 2, 3], "Can push integers")

	comp.interpret("clear-stack 11 23 354")
	assert_(comp.stack == [11, 23, 354], "Can push bigger integers")

	comp.interpret("1 u< 2 u<")
	assert_(array_eq(comp.constants['util-stack'], [1, 2]), "Can push to util-stack")

func test_compilation(comp):
	comp.interpret(":one def[ 1 ];")
	assert_(
		array_eq(comp.MEM.slice(-4, -1), [ "DOCOL", "LIT", 1, "EXIT" ]),
		"Compile number")
	comp.interpret(":add def[ + ];") 
	assert_( array_eq(comp.MEM.slice(-3,-1), [ "DOCOL", "+", "EXIT" ]), "Compile primitive") 
	comp.interpret("one one add") 
	assert_( array_eq(comp.stack, [ 2 ]), "Execute compiled nonprimitives")

func test_numbers(comp):
	comp.interpret("-1 -2 -3")
	assert_(array_eq(comp.stack, [-1, -2, -3]), "Negative Numbers Work")

func test_ops(comp):
	comp.interpret("1 2 lt? 2 1 gt? 0 0 eq?")
	assert_(array_eq(comp.stack, [true, true, true]), "Ops")


func test_blocks(comp):
	comp.interpret("{ 1 2 3 }")
	assert_(array_eq(comp.stack.back(), [1,2,3]), "Basic arrays")
	comp.interpret("clear-stack")

	comp.interpret("[ 1 2.0 + ] exec")
	stack_assert(comp, [3.0], "Can exec")


	comp.interpret(":2max def[ 2dup lt? spin ? ];")
	comp.interpret("1 2 2max")
	stack_assert(comp, [2], "2max worked")

func test_looping(comp):

	comp.interpret("1 2 3 [ 1 + false ] while")
	stack_assert(comp, [1,2,4], "While terminates")

	comp.interpret("0 [ 1+ dup 4 lt? ] while")
	stack_assert(comp, [4], "Counted While")

var call_count = 0
func test_methods(comp):
	comp.interpret("1 2 VM :op_add ()")
	stack_assert(comp, [3], "can call VM methods")

	comp.interpret(":TEST :to_lower ()")
	stack_assert(comp, ["test"], "can call VM methods")

	comp.interpret("bind", self)
	comp.interpret("self :mocked_call () self :get ( :call_count )")
	stack_assert(comp, [1], "Calling into test class")

func mocked_call():
	call_count += 1


