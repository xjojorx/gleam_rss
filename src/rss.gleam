import gleam/io
import gleam/list
import rss/parser



pub fn main() {
  io.println("Reading rss file")

  let articles = parser.read_articles_file("eurogamer.rss")

  case articles {
    Error(_) -> {
      io.println_error("errorrrrr")
    }
    Ok(articles) -> {
      use article <- list.each(articles)
      io.println("Erurogamer: "<>article.title<>" - "<>article.link)
      io.println("")
    }
  }



  io.println("end")
}
