module TransactionType = struct
  type t =
    | Credit
    | Debit

  let t =
    let encode = function
      | Credit -> "credit"
      | Debit -> "debit"
    in
    let decode = function
      | "credit" -> Ok Credit
      | "debit" -> Ok Debit
      | _ -> Error "Invalid transaction type"
    in
    Caqti_type.(enum ~encode ~decode "transaction_type")
  ;;
end

type t =
  | Transaction of
      { transaction_type : TransactionType.t
      ; value : int
      ; description : string
      }
  | Balance of { client_id : int }

type transaction =
  { id : int
  ; client_id : int
  ; value : int
  ; transaction_type : TransactionType.t
  ; description : string
  ; created_at : Ptime.t
  }

let decoder =
  let open Utils.Decoder in
  let open Syntax in
  let transaction_type_decoder =
    literal "c" *> return TransactionType.Credit
    <|> literal "d" *> return TransactionType.Debit
  in
  (fun value transaction_type description ->
    Transaction { value; description; transaction_type })
  <$> ("valor" <: int)
  <*> ("tipo" <: transaction_type_decoder)
  <*> ("descricao" <: string)
;;
