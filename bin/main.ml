[@@@warning "-26-27-32"]

open! StdLabels
open Eio
open Piaf

let request_handler Server.{ request; _ } =
  match Rinha.Router.match_route request.meth request.target with
  | Some handler -> handler request
  | None -> Response.create `Not_found
;;

let () =
  Eio_main.run
  @@ fun env ->
  Switch.run
  @@ fun sw ->
  let config =
    let interface = Net.Ipaddr.V4.any in
    let port = 3000 in
    `Tcp (interface, port)
  in
  let config = Server.Config.create config in
  let server = Server.create ~config request_handler in
  ignore @@ Server.Command.start ~sw env server
;;
