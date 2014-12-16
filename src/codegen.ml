open Ast
open Sast

let rec strip_semicolon l =
  match l with 
      [] -> ' '::[]
    | (hd::tl) -> if (hd = ';') then strip_semicolon tl else hd::(strip_semicolon tl)

let explode s =
  let rec exp i l =
    if i < 0 then l 
    else exp(i - 1)(s.[i] :: l) in
      exp(String.length s - 1)[]

let implode l =
  let res = String.create(List.length l) in
  let rec imp i = function
      [] -> res
    | c :: l -> res.[i] <-c; imp(i + 1) l in
      imp 0 l


let flip_last = fun l ->
  let r = List.rev l
  in (List.hd r) :: (List.rev (List.tl r))

let sanitize str =
  implode ( strip_semicolon ( explode ( str) ) )

let operation_to_string = function
    Plus -> "+"
  | Minus -> "-"
  | Times -> "*"
  | Divide -> "/"
  | Modulo -> "%"
  | Eq -> "==="
  | Neq -> "!=="
  | Gt -> ">"
  | Lt -> "<"
  | Gte -> ">="
  | Lte -> "<="
  | And -> "&&"
  | Or -> "||"
  | Not -> "!"

let param_to_js (id, t) = id

let param_to_type (id, t) = t

let rec returns_unit = function
    Unit -> true
  | Function(_, ret) -> returns_unit ret
  | _ -> false 


let is_partial = function
    Function(_, _) -> true
  | _ -> false

let is_IfElseBlock = function
    AIfElseBlock(_,_,_,_) -> true
  | _ -> false

let get_IfElseExprList(n, expr) = 
  match expr with
      AIfElseBlock(_,if_expr, else_expr, _) -> 
        if n = 0 then if_expr else else_expr
    | _ -> []

let get_IfElseE = function
      AIfElseBlock(e, _, _, _) -> e
    | _ -> AUnitLiteral

let rec aexpression_to_js lines =
  let rec build_return = function
     [] -> "\n\t"
  |  [single] -> "\n\treturn " ^ (aexpression_to_js single)
  |  hd::tl -> "\n\t" ^ (aexpression_to_js hd) ^ (build_return tl)
  in
  match lines with
    AIntLiteral(i) -> string_of_int(i)
  | AFloatLiteral(f) -> string_of_float(f)
  | ABinop(e1, op, e2, t) ->
      if op = Cons then
        "cons(" ^ 
        sanitize(aexpression_to_js e1) ^ "," ^
        sanitize(aexpression_to_js e2) ^ ");"
      else
        sanitize(aexpression_to_js e1) ^ " " ^
        operation_to_string op ^ " " ^
        sanitize(aexpression_to_js e2) ^ ";"
  | AUnop(op, e1, t) ->
     "(" ^  operation_to_string(op) ^ " " ^
      aexpression_to_js(e1) ^ ")"
      (* Unops won't be bythemselves as a single expression
       * so no semicolon *)
  | ABoolLiteral(b) ->
      if b then "true"
      else "false"
  | AStringLiteral(s) -> s
  | ACharLiteral(c) -> "'" ^ Char.escaped c ^ "'"
  | AUnitLiteral -> "void"
  | AIdLiteral(id, t) -> id
  | AAssign(id, e, t) ->
      "var" ^ " " ^ id ^ " = " ^
      aexpression_to_js e ^ ";"
  | AReassign(id, e, t) ->
      id ^ " = " ^ aexpression_to_js e ^ ";"
  | AMapLiteral(map_list, t) ->
      let map_expression_tupal_to_string (e1, e2) =
        (aexpression_to_js e1) ^ ": " ^ (aexpression_to_js e2)
      in "{" ^ 
      sanitize(String.concat ", " (List.map map_expression_tupal_to_string
      map_list)) ^ "};"
  | AMapAccess(id, param, s_type) ->
      aexpression_to_js id ^ "[" ^ aexpression_to_js param ^ "];"
  | ATupleLiteral(e_list, t) -> 
      "[" ^ String.concat ", " (List.map aexpression_to_js (List.rev e_list)) ^ "];"
  | AListLiteral(e_list, t) ->
      "[" ^ String.concat ", " (List.map aexpression_to_js (List.rev e_list)) ^ "];"
  | ATupleAccess(id, indx, t) ->
      sanitize(aexpression_to_js id) ^ "[" ^ sanitize(aexpression_to_js indx) ^ "];"
  | AListAccess(id, indx, t) ->
      sanitize(aexpression_to_js id) ^ "[" ^ sanitize(aexpression_to_js indx) ^ "];"

  | AIfBlock(e, e_list, _) ->
      "\nif(" ^ sanitize(aexpression_to_js e) ^ ") {" ^
      "\n" ^ String.concat "\n\t" (List.map aexpression_to_js e_list) ^
      "\n}\n"
  | AIfElseBlock(e, e_list1, e_list2, _) -> 
      "\nif(" ^ sanitize(aexpression_to_js e) ^ ") {" ^
      "\n\t" ^ String.concat "\n\t" (List.map aexpression_to_js e_list1) ^
      "\n}\n" ^
      "else {" ^
      "\n\t" ^ String.concat "\n\t" (List.map aexpression_to_js e_list2) ^
      "\n}\n"
  | AFuncDecl(id, p_list, e_list, t) ->
      if returns_unit t then
        if param_to_type(List.hd p_list) <> Unit then
          "function " ^ id ^ "(" ^  
          String.concat ", " (List.map param_to_js (List.rev p_list)) ^ ")" ^
          " \n{\n" ^ String.concat "\n\t" (List.map aexpression_to_js e_list) ^
          "\n};\n"
        else 
         "function " ^ id ^ "() {" ^
         "\n" ^ String.concat "\n\t" (List.map aexpression_to_js e_list) ^
         "\n};\n"
      else 
        if param_to_type(List.hd p_list) <> Unit then
          let flipped_list = flip_last e_list in
            "function " ^ id ^ "(" ^  
            (String.concat ", " (List.map param_to_js (List.rev p_list))) ^ 
            ") {" ^
            (String.concat "\n\t" (List.map aexpression_to_js (List.tl flipped_list))) ^
            (if is_IfElseBlock(List.hd flipped_list) then 
              "\nif(" ^ 
              sanitize(aexpression_to_js(get_IfElseE (List.hd flipped_list))) ^
              ") {" ^
              (build_return (get_IfElseExprList(0, (List.hd flipped_list)))) ^
              "\n} else {" ^
              (build_return (get_IfElseExprList(1, (List.hd flipped_list)))) ^
              "}\n"
             else 
               "\n\treturn " ^ 
              (aexpression_to_js (List.hd flipped_list))) ^ 
            "\n};\n"
        else
          let flipped_list = flip_last e_list in
            "function () {" ^  
            (String.concat "\n\t" (List.map aexpression_to_js (List.tl flipped_list))) ^
            (if is_IfElseBlock(List.hd flipped_list) then 
              "\nif(" ^ 
              sanitize(aexpression_to_js(get_IfElseE (List.hd flipped_list))) ^
              ") {" ^
              (build_return (get_IfElseExprList(0, (List.hd flipped_list)))) ^
              "\n} else {" ^
              (build_return (get_IfElseExprList(1, (List.hd flipped_list)))) ^
              "}\n"
             else 
               "\n\treturn " ^ 
              (aexpression_to_js (List.hd flipped_list))) ^ 
            "\n};\n"

  | AFuncAnon(p_list, exp, t) ->
      if returns_unit t then 
        if param_to_type(List.hd p_list) <> Unit then
          "function(" ^  
          String.concat ", " (List.map param_to_js (List.rev p_list)) ^ ")" ^
          " \n{\n\t" ^ aexpression_to_js exp ^
          "\n};\n"
        else 
         "function() {" ^
         "\n\t" ^ aexpression_to_js exp ^
         "\n};\n"
      else
        if param_to_type(List.hd p_list) <> Unit then
          "function(" ^
          String.concat ", " (List.map param_to_js (List.rev p_list)) ^ ")" ^
          "\n{\n\treturn " ^ aexpression_to_js exp ^
          "\n};\n"
        else
          "function() {" ^
          "\n\treturn " ^ aexpression_to_js exp ^
          "\n};\n"
  | AFuncCall(id, params, s_type) ->
      if s_type = Print then 
        "console.log(" ^ sanitize(aexpression_to_js (List.hd params)) ^ ");"
      else
        if List.hd params <> AUnitLiteral then
          if is_partial s_type then
            aexpression_to_js id ^ ".bind(this, " ^ 
            sanitize(String.concat ", " (List.map aexpression_to_js params)) ^
            ");"
          else
            aexpression_to_js id ^ ".call(this, " ^
            sanitize(String.concat ", " (List.map aexpression_to_js params)) ^
            ");"
        else
          aexpression_to_js id ^ "();"

let pumpkin_to_js (a_expressions, algebraic_types) =
  String.concat "\n" (List.map aexpression_to_js a_expressions)

(*let rec expression_to_string = function*)
    (*AIntLiteral(i, _) -> string_of_int(i)*)
  (*| AFloatLiteral(f, _) -> string_of_float(f)*)
  (*| ABoolLiteral(b, _) -> if b then "true" else "false"*)
  (*| AStringLiteral(s, _) -> s*)
  (*| ACharLiteral(c, _) -> Char.escaped c*)
  (*| AIdLiteral(id, _) -> id*)
  (*| ABinop(e1, op, e2, _) ->*)
      (*expression_to_string e1 ^ " " ^*)
      (*operation_to_string op ^ " " ^*)
      (*expression_to_string e2 ^ ";"*)
  (*| ATypeAssign(id, e, t) ->*)
      (*"var " ^ id ^*)
      (*" = " ^*)
      (*expression_to_string e ^ ";"*)
  (*| AParameter(id, t) -> id*)
  (*| ATypeFuncDecl(id, p_list, e_list, t) ->*)

  (*| AFuncCall(id, p_list, _) ->*)
      (*if (List.length p_list) <> 0 then*)
        (*id ^ "(" ^ *)
        (*implode(strip_semicolon (explode(String.concat ", " (List.map expression_to_string (List.rev p_list))))) ^ *)
        (*");"*)
      (*else*)
        (*id ^ "();"*)



(*let gen_program (root : Sast.aExpression list) = *)
  (*String.concat "\n" (List.map expression_to_string root)*)
