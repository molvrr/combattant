let transaction (t : Operation.transaction) =
  let transaction_type =
    match t.transaction_type with
    | `Credit -> "c"
    | `Debit -> "d"
  in
  let value = "valor", `Int t.value in
  let transaction_type = "tipo", `String transaction_type in
  let description = "descricao", `String t.description in
  let created_at =
    let formatted_date =
      Format.asprintf "%a" (Ptime.pp_rfc3339 ~tz_offset_s:(-10800) ()) t.created_at
    in
    "realizada_em", `String formatted_date
  in
  `Assoc [ value; transaction_type; description; created_at ]
;;

let bank_statement time client transactions =
  let date =
    `String (Format.asprintf "%a" (Ptime.pp_rfc3339 ~tz_offset_s:(-10800) ()) time)
  in
  let limit = `Int client.Operation.mov_limit in
  let total = `Int client.balance in
  let balance = `Assoc [ "total", total; "data_extrato", date; "limite", limit ] in
  let last_transactions = `List (List.map transaction transactions) in
  `Assoc [ "saldo", balance; "ultimas_transacoes", last_transactions ]
;;
