class_name GDForthCLI extends SceneTree

const VM = preload("VM.gd")

var forth = VM.new()

var http_request

func _request_complete(result, code, headers, body):
    pass
    # print("COMPLETE", result, code, headers, body)

func _init():
    forth.bind_instance(self)
    # get_root().add_child(

    var http = HTTPRequest.new()
    http_request = http
    http.connect("request_completed", self, "_request_complete")
    get_root().add_child(http)

    var os_args = OS.get_cmdline_args()
    for i in len(os_args):
        var a = os_args[i]
        if a == "--gdf-script":
            forth.do("load", os_args[i+1])


