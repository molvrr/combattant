[@@@warning "-26-27-32"]

open! StdLabels
open Eio
open Piaf

let request_handler ~db_pool Server.{ request; _ } =
  match Rinha.Router.match_route request.meth request.target with
  | Some handler -> handler db_pool request
  | None -> Response.create `Not_found
;;

let () =
  Eio_main.run
  @@ fun env ->
  Switch.run
  @@ fun sw ->
  let config =
    let interface = Net.Ipaddr.V4.any in
    let port = 8080 in
    `Tcp (interface, port)
  in
  let config = Server.Config.create config in
  let db_uri =
    Uri.make ~scheme:"postgres" ~userinfo:"admin:123" ~host:"db" ~path:"rinha" ()
  in
  let db_pool =
    Result.get_ok @@ Caqti_eio.connect_pool ~sw ~stdenv:(env :> Caqti_eio.stdenv) db_uri
  in
  let server = Server.create ~config (request_handler ~db_pool) in
  ignore @@ Server.Command.start ~sw env server
;;
