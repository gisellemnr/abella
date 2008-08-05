(****************************************************************************)
(* Copyright (C) 2007-2008 Gacek                                            *)
(*                                                                          *)
(* This file is part of Abella.                                             *)
(*                                                                          *)
(* Abella is free software: you can redistribute it and/or modify           *)
(* it under the terms of the GNU General Public License as published by     *)
(* the Free Software Foundation, either version 3 of the License, or        *)
(* (at your option) any later version.                                      *)
(*                                                                          *)
(* Abella is distributed in the hope that it will be useful,                *)
(* but WITHOUT ANY WARRANTY; without even the implied warranty of           *)
(* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            *)
(* GNU General Public License for more details.                             *)
(*                                                                          *)
(* You should have received a copy of the GNU General Public License        *)
(* along with Abella.  If not, see <http://www.gnu.org/licenses/>.          *)
(****************************************************************************)

open Term
open Extensions

(* Basic operations *)

type elt = term
type t = elt list

let empty : t = []

let size ctx = List.length ctx

let mem elt ctx = List.mem ~cmp:full_eq elt ctx
  
let remove elt ctx = List.remove ~cmp:full_eq elt ctx

let rec xor ctx1 ctx2 =
  match ctx1 with
    | [] -> ([], ctx2)
    | head::tail ->
        if not (has_logic_head head) &&
          (List.mem ~cmp:Unify.try_right_unify head ctx2)
        then xor tail (remove head ctx2)
        else let ctx1', ctx2' = xor tail ctx2 in
          (head::ctx1', ctx2')
        
let add elt ctx = ctx @ [elt]

let is_empty ctx = ctx = []

let element_to_string elt =
  term_to_string elt

let context_to_string ctx =
  let rec aux lst =
    match lst with
      | [] -> ""
      | [last] -> element_to_string last
      | head::tail -> (element_to_string head) ^ ", " ^ (aux tail)
  in
    aux ctx

let subcontext ctx1 ctx2 =
  List.for_all (fun elt -> mem elt ctx2) ctx1

let equiv ctx1 ctx2 = subcontext ctx1 ctx2 && subcontext ctx2 ctx1

let union ctx1 ctx2 =
  ctx1 @ ctx2

let union_list ctx_list =
  List.fold_left union empty ctx_list

let exists f ctx = List.exists f ctx

let map f ctx = List.map f ctx

let rec group pair_list =
  match pair_list with
    | [] -> []
    | (a, b)::_ ->
        let pairings = List.assoc_all ~cmp:eq a pair_list in
        let pair_list' = List.remove_all_assoc ~cmp:eq a pair_list in
          (a, pairings)::(group pair_list')

let context_to_list ctx = ctx
            
let cons = const "::"
            
let context_to_term ctx =
  let rec aux ctx =
    match ctx with
      | [] -> const "nil"
      | [last] when has_eigen_head last -> last
      | head::tail -> app cons [head; aux tail]
  in
    aux (List.rev ctx)

let is_nil t =
  match observe t with
    | Var {name=n} when n = "nil" -> true
    | _ -> false
      
let is_cons t =
  match observe t with
    | App(c, [_; _]) when c = cons -> true
    | _ -> false

let extract_cons t =
  match observe t with
    | App(_, [a; b]) -> (a, b)
    | _ -> assert false
      
let normalize ctx =
  let remove_dups ctx = List.unique ~cmp:eq ctx in
  let rec remove_cons ctx =
    match ctx with
      | [] -> []
      | head::tail when is_cons head ->
          let a, b = extract_cons head in
            remove_cons (b::a::tail)
      | head::tail when is_nil head ->
          remove_cons tail
      | head::tail -> head::(remove_cons tail)
  in
    remove_dups (remove_cons (List.map deep_norm ctx))

let extract_singleton ctx =
  match ctx with
    | [e] -> e
    | [] -> failwith "Context is empty"
    | _ -> failwith ("Non-singleton context encountered: " ^
                       (context_to_string ctx))

(* For each context pair (ctx1, ctx2), make ctx2 a subcontext of ctx1 *)
let reconcile pair_list =
  let pair_list = List.map (fun (x,y) -> xor x y) pair_list in
  let pair_list = List.remove_all (fun (x,y) -> is_empty y) pair_list in
  let var_ctx_list = List.map
    (fun (x,y) -> (extract_singleton x, y)) pair_list
  in
  let groups = group var_ctx_list in
  let groups = List.map (fun (x,y) -> (x, union_list y)) groups in
  let groups = List.map (fun (x,y) -> (x, normalize y)) groups in
    List.iter (fun (var, ctx) ->
                 Unify.right_unify var (context_to_term ctx)) groups
