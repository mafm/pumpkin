let _ =
  let lexbuf = Lexing.from_channel stdin in
  let program = Parser.program Scanner.token lexbuf in
  let sast = Analyzer.annotate_program program in
  Interpret.run sast

