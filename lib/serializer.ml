let transaction (t : Operation.transaction) =
  let transaction_type =
    match t.transaction_type with
    | `Credit -> "c"
    | `Debit -> "d"
  in
  `Assoc
    [ "valor", `Int t.value
    ; "tipo", `String transaction_type
    ; "descricao", `String t.description
    ; ( "realizada_em"
      , `String
          (Format.asprintf "%a" (Ptime.pp_rfc3339 ~tz_offset_s:(-10800) ()) t.created_at)
      )
    ]
;;
