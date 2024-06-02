# This an abortive attempt at a thing
class_name GDForthExecutionContext extends Reference

signal script_end
signal eval_complete
signal suspended

signal do_print(item)
signal do_error(item)

var trace = 0; var trace_indent = false
var IP = -1 
var stack = []; 
var utilStack = []; 
var returnStack = []; 
var callStack = [];
var loopStack = [];
var locals = {}
var stop = true; var is_error = false
var instance


