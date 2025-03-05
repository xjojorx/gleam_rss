import article.{type Article}
import birl
import gleam/erlang/process
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import gleam/string_tree
import mist
import rss/parser.{ FileError, ParseError}
import simplifile
import wisp.{type Request, type Response}
import wisp/wisp_mist

pub fn run_server() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let assert Ok(_) =
    wisp_mist.handler(handle_request, secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}

/// The middleware stack that the request handler uses. The stack is itself a
/// middleware function!
///
/// Middleware wrap each other, so the request travels through the stack from
/// top to bottom until it reaches the request handler, at which point the
/// response travels back up through the stack.
/// 
/// The middleware used here are the ones that are suitable for use in your
/// typical web application.
/// 
pub fn middleware(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  // Permit browsers to simulate methods other than GET and POST using the
  // `_method` query parameter.
  let req = wisp.method_override(req)

  // Log information about the request and response.
  use <- wisp.log_request(req)

  // Return a default 500 response if the request handler crashes.
  use <- wisp.rescue_crashes

  // Rewrite HEAD requests to GET requests and return an empty body.
  use req <- wisp.handle_head(req)

  // Handle the request!
  handle_request(req)
}

fn handle_request(req: Request) -> Response {
  use req <- middleware(req)

  // Wisp doesn't have a special router abstraction, instead we recommend using
  // regular old pattern matching. This is faster than a router, is type safe,
  // and means you don't have to learn or be limited by a special DSL.
  //
  case wisp.path_segments(req) {
    // This matches `/`.
    [] ->
      wisp.html_response(
        string_tree.from_string("feed available in /feed"),
        200,
      )

    // This matches `/comments`.
    ["feed", feed] -> handle_feed(req, feed)

    // This matches `/comments/:id`.
    // The `id` segment is bound to a variable and passed to the handler.
    // ["comments", id] -> show_comment(req, id)
    // This matches all other paths.
    _ -> wisp.not_found()
  }
}

fn handle_feed(_req, feed: String) {
  let feed = case string.ends_with(feed, ".rss") {
    True -> feed
    False -> feed <> ".rss"
  }

  let articles = parser.read_articles_file(feed)
  case articles {
    Error(FileError(simplifile.Enoent)) -> wisp.response(404)
    Error(ParseError(err)) ->
      wisp.json_response(
        string_tree.from_string("{error: '" <> err <> "'}"),
        500,
      )
    Error(_) -> wisp.response(500)
    Ok(articles) -> {
      json.object([
        #("count", json.int(list.length(articles))),
        #("articles", json.array(articles, article_to_json)),
      ])
      |> json.to_string_tree
      |> wisp.json_response(200)
    }
  }
}

fn article_to_json(a: Article) {
  json.object([
    #("title", json.string(a.title)),
    #(
      "date",
      json.string(a.date |> option.map(birl.to_http) |> option.unwrap("")),
    ),
    #("description", json.string(a.description)),
    #("link", json.string(a.title)),
    #("categories", json.array(a.categories, fn(c) { json.string(c) })),
  ])
}
