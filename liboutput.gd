class_name GDF_LibOutput extends Reference

var stdout_bottom
func _init():
    stdout_bottom = GDF_StdoutOutput.new(null)

func load_lib(VM):
    VM._comp_map["(push-file-stdout)"] = funcref(self, "push_file_stdout")
    VM._comp_map["(pop-stdout)"] = funcref(self, "pop_stdout")
    VM.stdout = stdout_bottom
    VM.eval(": with-file ( path block -- ) swap (push-file-stdout) do-block VM .stdout &close() (pop-stdout) ;")
    
func push_file_stdout(VM):
    var filePath = VM._pop()
    var out = GDF_FileOutput.new(VM.stdout)
    out.open(filePath) # TODO: Check error code here?
    VM.stdout = out
    VM.IP += 1

func pop_stdout(VM):
    if VM.stdout != stdout_bottom:
        VM.stdout = VM.stdout.previous()
    else:
        VM.do_push_error("Tried to pop the bottom-most stdout proxy!")
    VM.IP += 1

class GDF_StdoutOutput extends Reference:
    var _prev
    func _init(previous_output):
        _prev = previous_output

    func previous():
        return _prev

    func printraw(s):
        printraw(s)

class GDF_FileOutput extends Reference:
    var file
    var _prev
    func _init(previous_output):
        _prev = previous_output
        
    func open(path):
        file = File.new()
        return file.open(path, File.WRITE)

    func previous():
        return _prev

    func close():
        file.close()

    func printraw(s):
        file.store_string(s)

class GDF_ProxyOutput extends Reference:
    var output
    func _init(output):
        self.output = output

    func close():
        if output.has_method("close"):
            output.close()

    func printraw(s):
        output.printraw(s)
