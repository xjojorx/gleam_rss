import argv
import gleam/io
import gleam/list
import gleam/string
import rss/parser
import simplifile

pub fn main() {
  case argv.load().arguments {
    ["-f", path, ..] -> run_local_file(path)

    _ -> {
      io.println("usage:")
      io.println("\tshow feed from local file: rss -f file.rss")
      // io.println("\trss -f file.rss") 
    }
  }
}

fn run_local_file(path) {
  io.println("Reading rss file")

  let articles = parser.read_articles_file(path)

  case articles {
    Error(parser.ParseError(err)) -> {
      io.println_error(err)
    }
    Error(parser.FileError(file_err)) -> {
      io.print_error("File error: ")
      case file_err {
        simplifile.Eacces -> io.println_error("permission denied")
        simplifile.Efbig -> io.println_error("File too large")
        simplifile.Eio -> io.println_error("I/O error")
        simplifile.Eisdir -> io.println_error("Path is a directory")
        simplifile.Enametoolong -> io.println_error("Name too long")
        simplifile.Enodev -> io.println_error("No such device")
        simplifile.Enoent -> io.println_error("No such file or directory")
        simplifile.Enomem -> io.println_error("Not enough memory")
        simplifile.Epipe -> io.println_error("Broken pipe")
        _ -> io.println_error(string.inspect(file_err))
      }
    }
    Ok(articles) -> {
      use article <- list.each(articles)
      io.println("Article: " <> article.title <> " - " <> article.link)
      io.println("")
    }
  }
}
