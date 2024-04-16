class_name GDForthUI extends SceneTree


var outputLbl
var edit
var forth = preload("./VM.gd").new()

var history = []
var printed = []


var listener_scripts = """
    : v2 ( a b -- v ) util &v2( nom nom ) ;
    : ^ ( name -- instance ) class-db &instance( nom ) ;
    : $ ( path -- node/null ) self &get_node( nom )? ;
    : bye ( -- ) self &get_tree() &quit() ;
    : null? ( -- ) null eq? ;
    : ls ( -- ) self &get_children() [ print ] each ;
    :: cd ( to -- ) =path 
        self &get_node( *path )? =to
        *to null? not 
            [ VM &bind_instance( *to ) ] 
            [ { :Error :tried :to :switch :invalid :path *path }: print ] 
        if-else
    ; 
    : to-canvas :/root/all/cols/canvas cd ;

"""

func _init():
    var cont = MarginContainer.new()
    var margin_value = 10
    cont.add_constant_override("margin_top", margin_value)
    cont.add_constant_override("margin_left", margin_value)
    cont.add_constant_override("margin_bottom", margin_value)
    cont.add_constant_override("margin_right", margin_value)
    cont.name = "all"
    get_root().add_child(cont)

    var canvas = Node2D.new()
    canvas.name = "canvas"

    var cols = HBoxContainer.new()
    cols.name = "cols"

    var stack = VBoxContainer.new()
    stack.name="stack"
    cols.add_child(stack)
    cols.add_child(canvas)
    cont.add_child(cols)
    cont.rect_min_size = Vector2(200, 630)
    stack.rect_min_size = Vector2(400, 600)
    outputLbl = RichTextLabel.new()
    outputLbl.name = "%output"
    outputLbl.rect_min_size = Vector2(400, 560)
    outputLbl.bbcode_enabled = true

    var newSb = StyleBoxFlat.new()
    newSb.bg_color = Color.black
    newSb.content_margin_bottom = 4
    newSb.content_margin_top = 4
    newSb.content_margin_right = 4
    newSb.content_margin_left = 4
    outputLbl.add_stylebox_override("normal", newSb)


    forth.bind_instance(get_root())
    forth.eval(listener_scripts)
    forth.connect("suspended", self, "on_suspend")
    forth.connect("eval_complete", self, "on_eval_complete")
    forth.connect("script_end", self, "on_script_end")
    forth.connect("do_print", self, "on_print")
    forth.connect("do_error", self, "on_error")

    edit = LineEdit.new()
    edit.name = "%edit"

    stack.add_child(outputLbl)
    stack.add_child(edit)

    edit.connect("text_entered", self, "on_eval_text")

    show_state("GDForth UI Ready!\n")

func on_script_end():
    show_state("script ended")
    
func show_state(prefix):
    var output = PoolStringArray()
    output.append(prefix)
    output.append(str("IP: ", forth.IP, "\n"))
    
    output.append(str("self: ", forth.instance, "\n"))
    if "path" in forth.instance:
        output.append(str("path:", forth.instance.path, "\n"))
    if forth.instance.has_method("get_children"):
        output.append(str("\nchildren: ", forth.instance.get_children(), "\n"))
    output.append("stacks:\n")
    output.append("data: ")
    for el in forth.stack:
        output.append(str(el))
        output.append(", ")
    output.remove(len(output)-1)
    output.append("\n")

    output.append("return: ")
    for el in forth.returnStack:
        output.append(str(el))
        output.append(", ")
    output.remove(len(output)-1)
    output.append("\n")

    output.append("util: ")
    for el in forth.utilStack:
        output.append(str(el))
        output.append(", ")
    output.remove(len(output)-1)
    output.append("\n")

    output.append("loop: ")
    for el in forth.loopStack:
        output.append(str(el))
        output.append(", ")
    output.remove(len(output)-1)
    output.append("\n")
    output.append("\t----\t\n")
    output.append("printed: \n")
    outputLbl.bbcode_text = output.join("")

    for p in printed:
        if typeof(p) == TYPE_STRING:
            outputLbl.add_text(p)
        elif typeof(p) == TYPE_ARRAY and p[0] == "ERROR":
            outputLbl.push_color(Color.red)
            outputLbl.add_text(p[1])
            outputLbl.pop()
        else:
            outputLbl.add_text(str(p))

    output.append_array(printed)

func on_print(obj):
    printed.append(str(obj))

func on_error(err):
    printed.append(["ERROR", err])

func on_eval_complete():
    show_state("")
    printed.clear()


func on_suspend():
    show_state("Suspended...\n")
    
func on_eval_text(text):
    if Input.is_key_pressed(KEY_CONTROL):
        edit.clear()
    else:
        outputLbl.bbcode_text = "Running..."
        forth.eval(text)
        edit.select_all()


    
