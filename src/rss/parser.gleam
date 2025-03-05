import birl
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import simplifile
import xmlm.{type Input, type Tag, Data, ElementEnd, ElementStart, Name, Tag}
import article.{type Feed, type Article, Article}

pub type ParseError {
  FileError(simplifile.FileError)
  ParseError(String)
}

fn read_xml(path) {
  // let path = "eurogamer.rss"
  use bits <- result.map(simplifile.read_bits(path))

  bits
  |> xmlm.from_bit_array
  |> xmlm.with_stripping(True)
  |> xmlm.with_encoding(xmlm.Utf8)
}

fn accept_dtd(input: Input) -> Result(Input, String) {
  case xmlm.signal(input) {
    Error(e) -> Error(xmlm.input_error_to_string(e))
    Ok(#(xmlm.Dtd(_), input)) -> Ok(input)
    Ok(#(signal, _)) ->
      Error(
        "parse error -- expected Dtd signal, found " <> string.inspect(signal),
      )
  }
}

fn parse_site(input: xmlm.Input) -> Result(Feed, ParseError) {
  let assert Ok(input) = accept_dtd(input)
  let assert Ok(input) = skip_to_items(input)
  parse_items(input, [])
  |> result.map(fn(r) { r.0 })
  |> result.map_error(ParseError(_))
}

fn skip_to_items(input) {
  case xmlm.peek(input) {
    Error(err) -> Error(xmlm.input_error_to_string(err))
    Ok(#(ElementStart(Tag(Name("", "item"), _)), input)) -> Ok(input)
    Ok(#(_, input)) -> {
      let assert Ok(#(_, input)) = xmlm.signal(input)
      skip_to_items(input)
    }
  }
}

//reading all items until </channel>
fn parse_items(input: Input, articles: List(Article)) {
  case xmlm.signal(input) {
    Error(e) -> Error(xmlm.input_error_to_string(e))
    Ok(#(ElementEnd, input)) -> Ok(#(articles |> list.reverse, input))

    //item contents
    Ok(#(ElementStart(Tag(Name("", "item"), _)), input)) -> {
      let item_res = parse_article(input)
      case item_res {
        Ok(#(article, input)) -> parse_items(input, [article, ..articles])
        Error(err) -> Error(err)
      }
    }

    //ignore all other tags
    Ok(#(_signal, input)) -> parse_items(input, articles)
  }
}

//read started <item> until </item>
fn parse_article(input: Input) {
  do_parse_article(input, Article("", "", option.None, [], ""))
}

fn do_parse_article(
  input: Input,
  article: Article,
) -> Result(#(Article, Input), String) {
  case xmlm.signal(input) {
    Error(err) -> Error(xmlm.input_error_to_string(err))
    Ok(#(ElementStart(Tag(Name(_, tag_name), _)), new_input)) ->
      case input_element(new_input, tag_name) {
        Error(err) -> Error(err)
        Ok(#(SimpleElement("title", content), input)) ->
          do_parse_article(input, Article(..article, title: content))
        Ok(#(SimpleElement("link", content), input)) ->
          do_parse_article(input, Article(..article, link: content))
        Ok(#(SimpleElement("pubDate", content), input)) -> {
          let date =
            content
            |> birl.parse
            |> result.lazy_or(fn() { birl.from_http(content) })
            |> option.from_result
          do_parse_article(input, Article(..article, date: date))
        }
        Ok(#(SimpleElement("description", content), input)) ->
          do_parse_article(input, Article(..article, description: content))
        //TODO: handle cdata description?
        Ok(#(SimpleElement("category", content), input)) ->
          do_parse_article(
            input,
            Article(..article, categories: [content, ..article.categories]),
          )

        // 			<dc:creator xmlns:dc="http://purl.org/dc/elements/1.1/">Jaime San Simón</dc:creator>
        // 			<media:content medium="image" url="https://assetsio.gnwcdn.com/Tony-Hawk_URPbqGm.webp?width=1920&amp;height=1920&amp;fit=bounds&amp;quality=80&amp;format=jpg&amp;auto=webp"/>
        //ignore other elements
        Ok(#(_, input)) -> do_parse_article(input, article)
      }

    Ok(#(ElementEnd, input)) -> Ok(#(article, input))
    Ok(#(s, input)) -> {
      io.debug(s)
      do_parse_article(input, article)
    }
  }
}

type SimpleElement {
  SimpleElement(tag: String, content: String)
}

fn input_element(
  input: Input,
  tag: String,
) -> Result(#(SimpleElement, Input), String) {
  do_input_element(input, SimpleElement(tag, ""))
}

fn do_input_element(input: Input, element: SimpleElement) {
  case xmlm.signal(input) {
    Error(e) -> Error(xmlm.input_error_to_string(e))
    Ok(#(ElementStart(Tag(Name(_, tag_name), _attrs)), input)) ->
      do_input_element(input, SimpleElement(..element, tag: tag_name))
    Ok(#(Data(data), input)) ->
      do_input_element(input, SimpleElement(..element, content: data))
    Ok(#(ElementEnd, input)) -> Ok(#(element, input))
    //ignore extra signals
    Ok(#(_s, input)) -> do_input_element(input, element)
  }
}

/// reads and parses an rss feed from a local file
pub fn read_articles_file(path) {
  let parse_result = read_xml(path)
  case parse_result {
    Error(file_err) -> {
      Error(FileError(file_err))
    }
    Ok(input) -> parse_site(input)
  }
}
