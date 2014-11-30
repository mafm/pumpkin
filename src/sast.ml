open Ast

type sTypes = Int | Unit | Bool | String | Char | Tuple | List

type aExpression =
    AnIntLiteral of int * sTypes
  | ABinop of aExpression * operator * aExpression * sTypes
  | AUniop of operator * aExpression * sTypes
  | ABoolLiteral of bool * sTypes
  | AStringLiteral of string * sTypes
  | ACharLiteral of char * sTypes
  | AUnit of sTypes
  | ATypeAssign of string * aExpression * sTypes
  | ATupleLiteral of aExpression list * sTypes
  | AListLiteral of aExpression list * sTypes
  | AIfBlock of aExpression * aExpression list * sTypes
  | AIfElseBlock of aExpression * aExpression list * aExpression list * sTypes

type aRoot = aExpression list
