open Piaf

let valid_debit value limit balance =
  let balance_after_op = balance - value in
  not (balance_after_op < limit * -1)
;;

let create_transaction client_id (db_pool : Query.pool) (request : Request.t) =
  Caqti_eio.Pool.use
    (fun conn ->
      let client_opt =
        Option.join @@ Result.to_option @@ Query.find_client client_id conn
      in
      match client_opt with
      | Some client ->
        let insert_result =
          let body = Result.to_option @@ Body.to_string request.body in
          let json =
            Option.map
              (fun str ->
                try Yojson.Safe.from_string str with
                | _ -> `Null)
              body
          in
          let decoded_op = Option.bind json (Utils.Decoder.decode Operation.decoder) in
          match decoded_op with
          | Some (`Credit { value = _value; description = _desc } as op) ->
            (match Query.execute_transaction ~client_id ~op conn with
             | Ok _ as ok -> ok
             | Error e -> Error (`DB e))
          | Some (`Debit { value; description = _desc } as op) ->
            if valid_debit value client.mov_limit client.balance
            then (
              match Query.execute_transaction ~client_id ~op conn with
              | Ok _ as ok -> ok
              | Error e -> Error (`DB e))
            else Error `InvalidValue
          | None -> Error (`Decoder "Invalid operation")
        in
        (match insert_result with
         | Ok () ->
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

let get_balance client_id (db_pool : Query.pool) (_request : Request.t) =
  Caqti_eio.Pool.use
    (fun conn ->
      let client_opt =
        Option.join @@ Result.to_option @@ Query.find_client client_id conn
      in
      match client_opt with
      | Some client ->
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
               let limit = `Int client.mov_limit in
               `Assoc [ "total", total; "data_extrato", date; "limite", limit ]
             in
             let t =
               Result.fold ~ok:Fun.id ~error:(fun _ -> [])
               @@ Query.transactions client_id conn
             in
             let last_transactions = `List (List.map Serializer.transaction t) in
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
