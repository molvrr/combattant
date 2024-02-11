open Piaf

type pool = ((module Rapper_helper.CONNECTION), Caqti_error.t) Caqti_eio.Pool.t

let create_transaction client_id (db_pool : pool) (request : Request.t) =
  Caqti_eio.Pool.use
    (fun conn ->
      let module C = (val conn : Rapper_helper.CONNECTION) in
      C.with_transaction
      @@ fun () ->
      ignore @@ Query.lock client_id conn;
      let client_opt =
        Option.join @@ Result.to_option @@ Query.find_client client_id conn
      in
      match client_opt with
      | Some client ->
        let body = Result.to_option @@ Body.to_string request.body in
        let json =
          Option.map
            (fun str ->
              try Yojson.Safe.from_string str with
              | _ -> `Null)
            body
        in
        let decoded_op = Option.bind json (Utils.Decoder.decode Operation.decoder) in
        let insert_result =
          match decoded_op with
          | Some (`Credit { value = _value; description = _desc } as op) ->
            (match Query.execute_transaction ~client_id ~op conn with
             | Ok _ as ok -> ok
             | Error e -> Error (`DB e))
          | Some (`Debit { value; description = _desc } as op) ->
            let valid_debit =
              let balance_after_op = client.balance - value in
              not (balance_after_op < client.mov_limit * -1)
            in
            if valid_debit
            then (
              match Query.execute_transaction ~client_id ~op conn with
              | Ok _ as ok -> ok
              | Error e -> Error (`DB e))
            else Error `InvalidValue
          | None -> Error (`Decoder "Invalid operation")
        in
        (match insert_result with
         | Ok () ->
           let client =
             Option.get
             @@ Option.join
             @@ Result.to_option
             @@ Query.find_client client_id conn
           in
           let json : Yojson.Safe.t =
             `Assoc [ "limite", `Int client.mov_limit; "saldo", `Int client.balance ]
           in
           Ok (Response.of_string ~body:(Yojson.Safe.to_string json) `OK)
         | Error _ -> Ok (Response.create (`Code 422)))
      | None ->
        Logs.info (fun m -> m "Não encontrei o cliente %d" client_id);
        Ok (Response.create `Not_found))
    db_pool
;;

let get_balance client_id (db_pool : pool) (_request : Request.t) =
  Caqti_eio.Pool.use
    (fun conn ->
      let client_opt =
        Option.join @@ Result.to_option @@ Query.find_client client_id conn
      in
      match client_opt with
      | Some client ->
        let transaction_list =
          (* NOTE: Talvez isso aqui não seja uma boa ideia *)
          Result.fold ~ok:Fun.id ~error:(fun _ -> []) @@ Query.transactions client_id conn
        in
        let json =
          let time = Option.get @@ Ptime.of_float_s (Unix.time ()) in
          Serializer.bank_statement time client transaction_list
        in
        Ok (Response.of_string ~body:(Yojson.Safe.to_string json) `OK)
      | None ->
        Logs.info (fun m -> m "Não encontrei o cliente %d" client_id);
        Ok (Response.create `Not_found))
    db_pool
;;
