type pool = ((module Rapper_helper.CONNECTION), Caqti_error.t) Caqti_eio.Pool.t

let transaction_query =
  [%rapper
    execute
      {sql|
        INSERT INTO transactions (client_id, value, type, description)
        VALUES (%int{client_id}, %int{value}, %Operation.TransactionType{transaction_type}, %string{description})
      |sql}]
;;

let client_query =
  let open Client in
  [%rapper
    get_opt
      {sql|
    SELECT @int{id}, @int{mov_limit} FROM clients WHERE id = %int{id}
  |sql}
      record_out]
;;

let execute_operation ~client_id ~(op : Operation.t) pool =
  match op with
  | Transaction data ->
    Caqti_eio.Pool.use
      (fun conn ->
        transaction_query
          ~client_id
          ~value:data.value
          ~transaction_type:data.transaction_type
          ~description:data.description
          conn)
      pool
  | _ -> failwith "TODO"
;;

let find_client id pool = Caqti_eio.Pool.use (fun conn -> client_query ~id conn) pool
