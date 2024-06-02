class_name LEX extends Reference

var INPUT = ""
var pos = 0

func scan_until(charset: String, contains=true):
	var newPos = pos
	var subj = INPUT
	while newPos < len(subj) and contains != (subj[newPos] in charset):
		newPos += 1
	if newPos >= len(subj):
		var ret = INPUT.substr(pos)
		pos = newPos
		return ret
	else:
		var ret = INPUT.substr(pos, newPos - pos)
		pos = newPos
		return ret

func scan_for_seq(seq: String):
	var newPos = pos
	var subj = INPUT
	newPos = subj.find(seq)
	if newPos != -1:
		var ret = subj.substr(pos, newPos - pos)
		pos = newPos + len(seq)
		return ret
	return null

func eat_space(): 
	scan_until(" \t\r\n", false)

func handle_escapes(s):
	return s.replace("\\n", "\n").replace("\\t", "\t").replace("\\r", "\r")

func tokenize(input):
	INPUT = input
	pos = 0

	var ret_toks = []
	while pos < len(INPUT):
		eat_space()
		var tok = scan_until(" \t\r\n", true)
		# print("LEX: ", tok)
		if tok.begins_with('"') and (not tok.ends_with('"') or tok == '"'):
			var scanning_string = true
			while scanning_string:
				var ntok = scan_until('"', true)
				scanning_string = ntok.ends_with('\\')
				if scanning_string:
					tok += ntok.substr(0, len(ntok)-1) + '"'
					pos += 1
				else:
					tok += ntok + '"'
					pos += 1
			if tok != "":
				# print("[",tok,"]")
				ret_toks.append(handle_escapes(tok))
		else:
			if tok != "":
				# print("[",tok,"]")
				ret_toks.append(handle_escapes(tok))

	return ret_toks
