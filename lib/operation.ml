module TransactionType = struct
  type t =
    [ `Credit
    | `Debit
    ]

  let t =
    let encode = function
      | `Credit -> "credit"
      | `Debit -> "debit"
    in
    let decode = function
      | "credit" -> Ok `Credit
      | "debit" -> Ok `Debit
      | _ -> Error "Invalid transaction type"
    in
    Caqti_type.(enum ~encode ~decode "transaction_type")
  ;;
end

type transaction_payload =
  { value : int
  ; description : string
  }

type transaction_op =
  [ `Credit of transaction_payload
  | `Debit of transaction_payload
  ]

type t = Balance of { client_id : int }

type transaction =
  { id : int
  ; client_id : int
  ; value : int
  ; transaction_type : TransactionType.t
  ; description : string
  ; created_at : Ptime.t
  }

let decoder : transaction_op Utils.Decoder.decoder =
  let open Utils.Decoder in
  let open Syntax in
  let transaction_type_decoder =
    literal "c" *> return (fun p -> `Credit p)
    <|> literal "d" *> return (fun p -> `Debit p)
  in
  (fun value transaction_type description -> transaction_type { value; description })
  <$> ("valor" <: int)
  <*> ("tipo" <: transaction_type_decoder)
  <*> ("descricao"
       <: (string
           >>= fun s ->
           let len = String.length s in
           if len <= 10 && len >= 1 then return s else fail))
;;
