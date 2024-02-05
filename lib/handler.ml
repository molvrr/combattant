open Piaf

let create_transaction client_id (db_pool : Query.pool) (request : Request.t) =
  Caqti_eio.Pool.use
    (fun conn ->
      let client_opt =
        Option.join @@ Result.to_option @@ Query.find_client client_id conn
      in
      match client_opt with
      | Some _client ->
        let insert_result =
          let body = Result.to_option @@ Body.to_string request.body in
          let json = Option.map Yojson.Safe.from_string body in
          let decoded_op = Option.bind json (Utils.Decoder.decode Operation.decoder) in
          match decoded_op with
          | Some op ->
            (match Query.execute_operation ~client_id ~op conn with
             | Ok _ as ok -> ok
             | Error e -> Error (`DB e))
          | None -> Error (`Decoder "Invalid operation")
        in
        (match insert_result with
         | Ok () ->
           let json : Yojson.Safe.t =
             `Assoc [ "limite", `Int 100000; "saldo", `Int (-9098) ]
           in
           Ok (Response.of_string ~body:(Yojson.Safe.to_string json) `OK)
         | Error _ -> Ok (Response.create (`Code 422)))
      | None ->
        Logs.info (fun m -> m "Não encontrei o cliente %d" client_id);
        Ok (Response.create `Not_found))
    db_pool
;;

let get_balance client_id (db_pool : Query.pool) (_request : Request.t) =
  Caqti_eio.Pool.use
    (fun conn ->
      let client_opt =
        Option.join @@ Result.to_option @@ Query.find_client client_id conn
      in
      match client_opt with
      | Some _client ->
        let client_balance_opt =
          Option.join @@ Result.to_option @@ Query.balance client_id conn
        in
        (match client_balance_opt with
         | Some (balance_value, time) ->
           let json : Yojson.Safe.t =
             let balance =
               let total = `Int balance_value in
               let date =
                 `String
                   (Format.asprintf "%a" (Ptime.pp_rfc3339 ~tz_offset_s:(-10800) ()) time)
               in
               let limit = `Int 100000 in
               `Assoc [ "total", total; "data_extrato", date; "limite", limit ]
             in
             let last_transactions = `List [] in
             `Assoc [ "saldo", balance; "ultimas_transacoes", last_transactions ]
           in
           Ok (Response.of_string ~body:(Yojson.Safe.to_string json) `OK)
         | None ->
           Logs.info (fun m -> m "Não encontrei o extrato do cliente %d" client_id);
           Ok (Response.create `Not_found))
      | None ->
        Logs.info (fun m -> m "Não encontrei o cliente %d" client_id);
        Ok (Response.create `Not_found))
    db_pool
;;
